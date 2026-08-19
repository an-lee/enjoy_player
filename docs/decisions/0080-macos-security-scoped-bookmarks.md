# ADR-0060: macOS security-scoped bookmarks for path-linked local media

> Originally filed as draft `0060`. Renumbered to `0080` to avoid colliding
> with `0060-craft-voice-express-dual-mode.md`.

## Status

Accepted

## Context

ADR-0050 made imported local media durable by storing the source
filesystem path (`localUri`) instead of copying every video into app
storage. That works on every desktop platform **except** the sandboxed
macOS build.

`FilePicker.pickFiles` on macOS uses `NSOpenPanel`, which gives the app
a **temporary** security-scoped URL: the grant covers the picked file
for the **current process** only. As soon as the app terminates, the
URL is no longer accessible — every `open(2)` call against it returns
`EACCES`.

Observed user impact (macOS dev run):

* Pick a file via `importMediaFromPicker` and open it in the same
  session → plays fine (scope is alive).
* Quit, relaunch, open the same library item → loading spinner hangs
  forever. `localUriTrusted()` still returns `true` because `stat()`
  sees metadata even when the sandbox denies the actual read, so the
  `LocateMediaScreen` rescue path never fires.
* `discoverSidecarSubtitleFiles` lists the parent directory of the
  picked file (a separate scope the app never received) and warns
  `Operation not permitted, errno = 1`. This is the same root cause
  in a side path.

This is the textbook case for **security-scoped bookmarks**
(`URL.bookmarkData(options: .withSecurityScope, …)`) on macOS:
captured while the implicit `NSOpenPanel` scope is still alive, the
blob can be re-resolved on subsequent launches to obtain a fresh
`URL` plus a `startAccessingSecurityScopedResource()` grant that
survives across processes. Apple requires the
`com.apple.security.files.bookmarks.app-scope` entitlement to create
such bookmarks — without it the system silently strips the scope on
rebind and the bug returns.

## Decision

### 1. Capture the bookmark at import / relocate time

`FileStorage.importOrLinkPickedFile` already runs while the implicit
`NSOpenPanel` scope is alive (it has to, in order to hash / copy the
bytes). Before launching the hashing isolate, it calls
`SecurityScopedBookmarkChannel.createBookmark(path)` and persists the
resulting bytes on the `FileImportResult`. Bookmarks are only captured
for externally linked files (those that will live outside the app
sandbox container); files copied into app-managed `media/` get no
bookmark because the sandbox already grants permanent access to its
own container.

`MediaLibraryRepository.importMedia` and `.relocateLocalFile` write
the bytes to the new `videos.bookmark_data` / `audios.bookmark_data`
`BLOB` columns.

### 2. Drift migration v16 → v17

* `Videos.bookmarkData` and `Audios.bookmarkData` — nullable `BLOB`.
* Migration step 17 uses the existing `_addColumnIfMissing` helper so
  the upgrade tolerates an interrupted previous migration.
* `schemaVersion` bumped to 17.

### 3. Resolve at open, start the scope, hand a token to the engine

`media_target_resolver.dart::resolvePlayableSource` now prefers the
bookmark over the persisted `localUri` when present:

1. Call `SecurityScopedBookmarkChannel.resolveBookmark(bookmark)`.
2. The native side runs `URL(resolvingBookmarkData:options:.withSecurityScope…)`
   and `startAccessingSecurityScopedResource()`. It returns
   `{path, token, stale}`.
3. Re-check `localUriTrusted` against the resolved path — if the
   bookmark silently re-pointed to a different file, release the scope
   and fall back to the legacy `localUri` path.
4. Wrap the result in
   `LocalFilePlayableSource(resolved.path, scopeToken: token)`.

Fallback chain on any failure (missing shim, resolution failure,
trust mismatch): `bookmark` → `localUri` → `mediaUrl` →
`MediaNeedsRelocateException` (when a fingerprint exists).

`resolvePlayableSourceUri` (used by subtitle / ASR side channels)
resolves the bookmark too, but releases the token immediately: those
consumers do not own the engine.

### 4. Pair the token with release

The engine must hold the security-scoped grant alive across the
entire `mk.Player.open(...)` await — libmpv reads the file
asynchronously, and revoking the grant before reads finish resurrects
the original bug. `MediaKitPlayerEngine` therefore:

* On `open(newSource)`: release any previously held token, then store
  `newSource.scopeToken` if present.
* On `dispose()`: release any held token.
* On a fresh process: never persists tokens across launches; the next
  `open()` resolves the bookmark again.

The secondary `RecordingPreviewPlayer` (`mk.Player` instance for
shadow-reading take previews, ADR-0003) mirrors the same lifecycle
for its own opened path.

### 5. Native plugin: `enjoy.player/security_scoped_bookmark`

A new Swift class
[`SecurityScopedBookmarkChannel`](macos/Runner/SecurityScopedBookmarkChannel.swift)
is registered with `flutterViewController.engine.binaryMessenger` from
`MainFlutterWindow.swift`. Three methods:

| Method | Args | Returns |
|---|---|---|
| `createBookmark` | `{path: String}` | `Uint8List` (opaque) |
| `resolveBookmark` | `{data: Uint8List}` | `{path: String, token: Int, stale: Bool}` |
| `releaseBookmark` | `{token: Int}` | `null` |

The Swift side keeps a `[Int: URL]` registry of started grants keyed
by the `token` it handed back; `releaseBookmark` looks the URL up and
calls `stopAccessingSecurityScopedResource()`. MethodChannel
callbacks run on the platform thread by default — no locking needed.

### 6. Entitlements

All three macOS entitlements files (`DebugProfile`,
`Release`, `ReleaseDirect`) get
`com.apple.security.files.bookmarks.app-scope = true`. Without this
entitlement, the OS strips the security scope from resolved bookmarks
and the bug returns — the codebase already has
`com.apple.security.app-sandbox` set everywhere.

### 7. Cross-platform behavior

The Dart wrapper
[`SecurityScopedBookmarkChannel`](lib/data/files/security_scoped_bookmark.dart)
catches `MissingPluginException` from every call and returns
`null` / no-ops. iOS / Android / Windows / Linux / Web tests see the
existing legacy `localUri` path unchanged. iOS can adopt the same
pattern later by registering an iOS Runner Swift implementation
behind the same channel name without touching the Dart API.

## Consequences

* **Sandboxed macOS open-after-restart works.** Library items picked
  in any previous session open without a hang or relocate-screen
  detour, even after the source file has moved to a different
  `Downloads/` subfolder (the resolved path follows the bookmark).
* **Disk cost is unchanged.** Bookmarks are typically a few hundred
  bytes — one BLOB per row.
* **Schema is forward-compatible.** Pre-v17 rows have `bookmark_data =
  NULL` and keep working via the legacy `localUri` path; once a row is
  re-imported or relocated, it gets a bookmark and the new path takes
  over.
* **Trust gate survives.** `localUriTrusted` (size + mtime) still
  fires on the resolved path, so a silently-rebound bookmark pointing
  at a different file is caught and surfaces the `LocateMediaScreen`.
* **Scope leaks are bounded.** The native registry only grows by one
  entry per `resolveBookmark` and is freed on the matching
  `releaseBookmark`. The Dart side guarantees pairing with the
  engine lifecycle.
* **App Store implications.** None for the macOS App Store — the
  `bookmarks.app-scope` entitlement has no review justification
  requirement for the explicit "remember user-picked files" use case.

## References

* Apple: *Enabling Security-Scoped Bookmarks and URLs* (App Sandbox
  capability).
* ADR-0003 — single `media_kit` `Player` lifecycle (the engine layer
  this ADR sits on top of).
* ADR-0050 — path-linked local media (the import strategy that
  surfaced this macOS-only failure mode).
* ADR-0057 — permanent player surface host (interacts with engine
  swap timing, not changed by this ADR).
* Spec / feature docs: [`docs/features/local-library.md`](features/local-library.md),
  [`docs/features/media-player.md`](features/media-player.md) — both
  pick up a "macOS sandbox / security-scoped bookmark" note.