# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Community activity card** split into focused part files (`avatars`, `bodies`, `metrics`, `stats`) sharing one library scope.
- **Global transport bar** extracts `_LineNavButton` as the shared prev/next/replay control.

## [0.7.2] - 2026-07-22

### Added

- **Auto-renew subscription** with credits packages and membership tiers.
- **Logging test infrastructure** with `TestLoggingScope` helper for asserting log output.

### Changed

- **Transcript repository** split into focused part files (auto-translate, subtitle import, YouTube fetch, worker cache).
- **NavItemPill** extracted as shared widget between sidebar and settings rail.
- **Bearer auth** acquisition centralized into `_ensureAuthenticated`.

### Fixed

- **YouTube login** no longer crashes by parking the surface host.
- **Tablet orientation** no longer mis-locked to portrait at bootstrap.
- **Android TLS** and **macOS SwiftPM** build failures resolved.

## [0.7.1] - 2026-07-21

### Changed

- **Phone orientation and player layout** lock phones to portrait and switch video/transcript between stacked and side-by-side from window aspect instead of a fixed width breakpoint.
- **Library** bumps recency on every open, sorts by recent activity, and defaults to the Video tab.

### Fixed

- **YouTube player overlays** pass host chrome hits through so embedded controls remain clickable.
- **Expired Pro subscriptions** correctly use the free daily credits limit.
- **Android release builds** clear stale plugin caches that could break AGP 9 packaging.

## [0.7.0] - 2026-07-19

### Added

- **Long-form AI transcripts** now use resumable Deepgram jobs for media at least 15 minutes long, with upload progress, persisted in-flight attempts, and clearer processing feedback.

### Changed

- **Vocabulary review and echo practice** have more focused study controls and polished practice layouts.
- **Vocabulary on mobile** now prioritizes the word list, moves statistics into Review details, and collapses filters behind the toolbar.
- **Transcript empty states** use clearer AI transcript wording and actions tailored to local and remote media.

### Fixed

- **Local media reopening and sync** no longer hang after a video is deleted and imported again.
- **Player overlays**, including dictionary lookup, remain correctly positioned above video.
- **Android release builds** support current `share_plus` versions under Android Gradle Plugin 9.

## [0.6.2] - 2026-07-18

### Added

- **Update availability badge** on Settings when a newer app version is ready.

### Changed

- **Android update prompts** now show download progress.

### Fixed

- **Transcript subtitle selection** once again offers the Auto translate option.

## [0.6.1] - 2026-07-18

### Added

- **Vocabulary learning workflow** with transcript lookup actions, AI-enriched review cards, persisted review sessions, cloud sync, media actions, and Pro Anki CSV export.
- **Profile editing** with avatar upload and Enjoy ID support.

### Changed

- **Adaptive layouts and UI polish** across vocabulary, profile, and hotkey screens, using shared page families and gutters.
- **Vocabulary context selection** now prefers complete sentences with a bounded fallback for unpunctuated transcripts.
- **API timezone handling** now uses the device timezone reported by `flutter_timezone`.

### Fixed

- **Sync recovery** now handles duplicate catalog rows during video upload and refetches vocabulary when create responses omit `updatedAt`.
- **Keyboard navigation** dismisses shell sheets before popping routes and returns cleanly from vocabulary review on Escape.
- **Windows Azure assessment** now supports media paths containing non-ASCII characters.

## [0.6.0] - 2026-07-16

### Changed

- **Path-linked local media** — link durable source paths when lasting access exists, fall back to app-managed copies otherwise, and delete shared media only when unreferenced across per-user databases.

### Fixed

- **Practice poster export crash in release mode** — `RenderObject.debugNeedsPaint` throws `LateInitializationError` in release when implemented with `late`+`assert`; export waits for a settled frame, retries rasterization when needed, and resets exporting state in `finally`. See [docs/features/share-poster.md](docs/features/share-poster.md).

## [0.5.2] - 2026-07-16

### Added

- **Shared `LoadingIcon` widget** for inline busy affordances ([#338](https://github.com/baizhiheizi/enjoy_player/issues/338), [#341](https://github.com/baizhiheizi/enjoy_player/pull/341)). A compact 18×18 `CircularProgressIndicator` (`size`, `strokeWidth`, `color`) replaces 30+ duplicated `SizedBox` + `CircularProgressIndicator` patterns across 20 files (auth sidebar chip, profile preferences, settings hub, sync status, transcript busy action, subtitle track picker, lookup refresh/error rows, cloud library body, craft translate/synthesize tools, BYOK forms, discover subscribe sheet / screen / channel filter, share poster preview, locate media, shadow-reading assessment button). Documented in [docs/features/app-ui.md § Widgets reference](docs/features/app-ui.md#widgets-reference).
- **Shared `SectionLabel` widget** for in-card section headers ([#337](https://github.com/baizhiheizi/enjoy_player/issues/337), [#341](https://github.com/baizhiheizi/enjoy_player/pull/341)). Replaces the duplicate `_FormSectionLabel` / `_SpeechSectionLabel` private classes in the BYOK forms with a single public widget (`Icon` + `EnjoyThemeTokens.space8` + bold `labelLarge` text using the active `ColorScheme`). Documented in [docs/features/app-ui.md § Widgets reference](docs/features/app-ui.md#widgets-reference).

### Changed

- **Discover channel refresh uses InnerTube `browse` as primary data source** ([ADR-0047](docs/decisions/0047-youtube-discover-innertube.md)). The per-channel refresh path now tries InnerTube's anonymous `browse` endpoint first (`POST youtubei.googleapis.com/youtubei/v1/browse`) and falls back to the Atom RSS endpoint on failure. InnerTube returns richer metadata (`lengthText`, `viewCountText`, `publishedTimeText`) and is materially less likely to be blocked by YouTube's bot detection. The legacy watch-page HTML duration enrichment is skipped for InnerTube-sourced rows. Client profile rotation (`WEB` → `MWEB`) and continuation pagination (cap 5 pages ≈ 150 entries) match the caption fetcher's posture. See [docs/features/discover.md](docs/features/discover.md). *(Later superseded for feed fetch by [ADR-0051](docs/decisions/0051-youtube-worker-discovery.md) — server-side RSSHub proxy; ADR-0047 remains accurate for that slice of history.)*
- **Discover avatar URL cache rides the shared `L1Store<K, V>` primitive** ([#335](https://github.com/baizhiheizi/enjoy_player/pull/335)). `DiscoverRepository` no longer carries a hand-rolled `LinkedHashMap` LRU for channel avatars; the cache is now a 256-entry, 6-hour-TTL instance of the same [`L1Store`](lib/core/cache/lru_store.dart) that backs the AI result cache hierarchy ([ADR-0045](docs/decisions/0045-ai-result-cache-hierarchy.md)) and `LookupSheetResultCache`. The 6 h TTL is a strict relaxation of the previous infinite lifetime — avatar URLs change only a few times per year, so the window is far longer than realistic re-fetch cadence while bounding memory of long-running sessions that touch thousands of distinct channels. New cache call sites should use `L1Store` instead of re-implementing LRU bookkeeping; see [docs/conventions.md § Caching](docs/conventions.md#caching) for the behavior contract and current call sites.
- **`SyncDownloadService` uses a generic `_downloadEntityInternal<E>` helper** ([#336](https://github.com/baizhiheizi/enjoy_player/issues/336), [#341](https://github.com/baizhiheizi/enjoy_player/pull/341)). The three per-entity download paths (audio, video, recording) now share one ~75-line pagination + merge loop instead of duplicating ~200 lines of triplicated cursor-paging logic. Public `downloadAudios` / `downloadVideos` / `downloadRecordings` / `downloadAllEntitiesFresh` entry points and `SyncResult` shape are unchanged — see [docs/features/sync.md](docs/features/sync.md).
- **Discover feed entry upserts run in a single Drift batch transaction per source** for lower write amplification on large channel refreshes — one `watchTimeline` emission for non-empty upserts; empty responses are a no-op. See [docs/features/discover.md § Cache semantics](docs/features/discover.md#cache-semantics-append-only).

### Fixed

- **Intermittent Windows YouTube play-then-pause startup**: WebView2 ignores `mediaPlaybackRequiresUserGesture`, while the player previously force-unmuted on HTML5's optimistic `play` event. Playback now stays muted until the authoritative `playing` event settles, transport state no longer treats `play` as proof that frames are advancing, and rejected `play()` promises plus command/event/poll transitions are captured by the `YouTube*` diagnostic loggers. The WebView logger names were also corrected from `Youtube*` to the allowlisted, case-sensitive `YouTube*` prefix, fixing pre-existing silent loss of FINE records. See [docs/features/youtube.md](docs/features/youtube.md#limitations).
- **YouTube InnerTube caption profile ladder hardening** so client-profile rotation and worker cache-only transcript fetches fail closed instead of returning empty or mismatched tracks.
- **Shadow-reading assessment restored for unknown media language** — unknown / denylisted media tags (`und`, empty) fall back to the learner's `effectiveLearningLanguage` via `resolveAzureAssessmentLocaleForPractice` / `isAzurePronunciationAssessmentSupportedForPractice` instead of disabling Assess while play / take-menu still worked. Genuinely unsupported primaries still disable the control with a tooltip (no silent `en-US` coercion). See [docs/features/shadow-reading.md](docs/features/shadow-reading.md#pronunciation-assessment-azure) and [docs/features/echo-mode.md](docs/features/echo-mode.md).
- **Discover migration v13 `feed_url` backfill** uses the SQL column name `channel_id` (not the Drift accessor `channelId`), so pre-existing subscriptions get a worker feed URL instead of failing the migration step.
- **Worker YouTube `client-profiles` wire shape parsing** aligned with the actual response body.

## [0.5.0] - 2026-07-13

### Added

- **Linux platform support (AppImage)**. Linux is now a first-class supported desktop platform. ([ADR-0048](docs/decisions/0048-linux-platform-support.md))
  - `linux/` Flutter desktop scaffold, `.github/workflows/build_linux.yml` CI, `release_linux.sh`, AppImage packager
  - Centralized `lib/core/platform/linux_platform_availability.dart` predicates
  - Landing page `#card-linux` with localized strings (en + zh)
  - YouTube engine gracefully opts out on Linux (WebViewGTK not ready for v1)
  - Constitution amendment 1.1.0 → 1.2.0 (Linux added to supported targets)
  - New `docs/features/linux-platform.md`, `docs/decisions/0048-linux-platform-support.md`
  - `AGENTS.md` and `README.md` updated for Linux first-class support

- **Echo enforcement coordinator (`EchoEnforcer`)**: the reactive per-tick
  echo correction and the proactive seek clamp are now serialized through one
  single-flight coordinator, so concurrent seeks can't interleave into an
  audible stutter at segment edges. Enforcement runs on every position event,
  so pause-and-rewind fires within ~50 ms of the segment end (previously up to
  ~360 ms late, sampled on a 400 ms grid). The in-memory session + DB write
  stay on the 400 ms grid so the recorded clip window still lines up. Covered
  by boundary-timing and single-flight serialization tests. See
  [docs/features/echo-mode.md](docs/features/echo-mode.md) and issue #280.

### Changed

- **Position is now durably written mid-playback**: `PlaybackSessionPersister`
  coalesces updates on a 450 ms debounce but forces a flush once pending data
  is older than ~2 s. The 400 ms emit cadence previously re-armed the 450 ms
  debounce forever, so a crash/kill lost all progress since the last pause; the
  max-age bound makes loss rate-independent (works at 1× and 2×). Background
  flush errors are now caught + logged instead of surfacing as uncaught async
  exceptions.
- **Echo window source of truth**: enforcement re-derives start/end seconds
  from the line indices + current transcript at enforcement time (falling back
  to the cached value), so a re-segmented transcript yields fresh boundaries
  instead of stale ones. Echo-path magic numbers and s/ms conversions were
  extracted to named constants/helpers.
- **Guarded mpv teardown**: `PlayerController` disposal is now reentrancy-guarded
  and its teardown future is captured/observable, reducing the latent double-mpv
  race on a future `ref.invalidate` (Riverpod still does not await `onDispose`).

### Added

- **ASR transcript generation**: local audio and video can generate,
  re-generate, and auto-select a time-aligned `source: ai` transcript through
  the existing Enjoy, Azure BYOK, or OpenAI-compatible Whisper capability
  paths. Generated tracks upsert deterministically, propagate a detected
  language, and use localized failure feedback.
- **YouTube bilingual transcripts**: when the learner's native language differs
  from the source, the worker fetch sends a single multi-language
  `pollTranscripts({ languages: [source, native], waitMs })` request instead of
  two sequential calls. The original caption is stored as the primary track and
  the native translation as the secondary; a `partial` response logs the missing
  languages without inventing a primary from a non-existent row. See
  [ADR-0036](docs/decisions/0036-youtube-bilingual-transcripts.md) and
  [docs/features/transcript.md](docs/features/transcript.md#youtube-worker).
- Local CI gate scripts under `.github/scripts/` so contributors and agents
  can mirror the cheapest CI failures before pushing:
  - `validate_ci_gates.sh` — runs `check_dart_format` + `check_codegen_drift`
    (and optionally `flutter analyze` / `flutter test` via `--analyze`,
    `--test`, or `--all`); `--fix` auto-formats and regenerates codegen.
  - `check_dart_format.sh` — fails when `dart format` would change a file in
    `lib`, `test`, or any path package's `lib`/`test`. `--fix` writes the
    formatting.
  - `check_codegen_drift.sh` — runs `build_runner` in the root and any path
    package that declares it, then fails if generated `*.g.dart` /
    `*.freezed.dart` files drift from `HEAD`. `--fix` regenerates and leaves
    the diff to commit.
- `.githooks/pre-push` — blocks pushes that would fail CI `Dart format` and
  (when Dart/lib/package sources are in the push range) `Codegen drift`.
  Install once per clone with `git config core.hooksPath .githooks`; bypass
  with `git push --no-verify`.

### Fixed

- **YouTube transcript upload payload now passes worker validation (#318)**.
  `YoutubeTranscriptsApi.uploadTranscript()` now sends the full
  worker-required body: `format: "enjoy"`, the worker-side
  `caption_fetch` derived from `source` (`official` → `official`, anything
  else → `auto`), and a `generatedAt` ISO 8601 UTC timestamp. Without these
  fields the worker's `parseTranscriptUpload()` rejects every upload, so
  client-side fetch results never populated the R2 cache. See
  [docs/features/transcript.md](docs/features/transcript.md) and
  [specs/013-client-yt-transcripts/contracts/worker-cache-api.md](specs/013-client-yt-transcripts/contracts/worker-cache-api.md).
- **`fetchClientProfiles()` now reads the worker's `profiles` envelope (#319)**.
  The client previously called `getJsonList()`, which threw on any
  non-array body; the worker actually returns `{"version", "profiles"}`.
  The client now calls `getJson()` and extracts the `profiles` list
  defensively, so `YoutubeCaptionFetcher` reaches the published client
  profiles instead of always falling back to built-in defaults.
- **Removed the dead poll-based YouTube transcript client API and the
  outdated spec 008 worker contract (#320)**. The worker has retired
  `POST /youtube/transcripts` as a poll/generate endpoint in favor of a
  cache-only contract; the legacy `pollTranscript` / `pollTranscripts`
  methods on `YoutubeTranscriptsClient` were never called by any
  production code (`TranscriptRepository` only uses `getCachedTranscript`
  and `uploadTranscript`) and are now deleted along with their unit
  tests. The 008 contract doc
  (`specs/008-youtube-bilingual-captions/contracts/youtube-transcripts-api.md`)
  is removed; in-tree references are updated to
  [`specs/013-client-yt-transcripts/contracts/worker-cache-api.md`](specs/013-client-yt-transcripts/contracts/worker-cache-api.md)
  and the same contract is now documented as the source of truth in
  [ADR-0036](docs/decisions/0036-youtube-bilingual-transcripts.md).
  `docs/features/transcript.md` is updated to describe the supported
  cache + profile endpoints rather than the retired poll path.

- **Lookup source precedence is now chrome-first**: transcript dictionary
  lookup resolves the source language from the video (chrome) language first,
  falling back to the active track language, and only then to the learning
  language — replacing the old "first sibling transcript track" heuristic. The
  pure helper `resolveLookupSourceLanguage({chromeLanguage, activeTrackLanguage})`
  is covered by 6 unit tests. See
  [ADR-0019](docs/decisions/0019-transcript-dictionary-lookup.md),
  [ADR-0042](docs/decisions/0042-multi-language-lookup-catalog.md), and
  [docs/features/dictionary-lookup.md](docs/features/dictionary-lookup.md#default-source).
- **Auto-translate keyed by primary text, not time match**: AI auto-translate
  tracks are now aligned via an index overlay plus a `sourceKey` content
  fingerprint (`normalize(plain(primary.text)) | workerLang(src) | workerLang(tgt)`),
  so a neighbor cue is no longer attached when timings are tight, and an edited
  cue no longer keeps a stale translation. See
  [ADR-0039](docs/decisions/0039-auto-translate-primary-text-keyed-overlay.md)
  and [docs/features/transcript.md](docs/features/transcript.md#auto-translate).
- **i18n: localize remaining hardcoded user-facing strings**: removed
  hidden-English hotkey fallbacks, localized shadow-reading captions and the
  file-not-found reason, replaced raw `Text('$error')` dumps with
  `errorGenericLoadFailed`, added the `authOtpInputSemantics` OTP a11y label,
  filled the missing `subtitlesRegenerate` zh translation. See
  [docs/features/auth.md](docs/features/auth.md),
  [docs/features/transcript.md](docs/features/transcript.md),
  [docs/features/shadow-reading.md](docs/features/shadow-reading.md),
  [docs/features/hotkeys.md](docs/features/hotkeys.md), and
  [docs/conventions.md](docs/conventions.md).

## [0.4.0] - 2026-07-09

### Added

- Wiki documentation template at `.github/agentic-wiki/PAGES.md` consumed by the
  `agentic-wiki-writer` workflow. Includes page outlines for Home, Getting
  Started, Architecture, Player, Transcripts, Library, Sync, Auth, Settings,
  Release & CI, Local Packages, and an index page for AI coding agents.
- Google Sign-In configuration files (`google-services.json` /
  `GoogleService-Info.plist`) flipped from `REPLACE_WITH_*` placeholders to
  shipped defaults; the Web application client ID is referenced from
  `kGoogleWebClientId` in `lib/features/auth/domain/google_auth_config.dart`.
- `macos/Runner/ReleaseDirect.entitlements` — separate entitlements file for
  Developer ID direct-download builds (sandbox + network + app keychain
  group, **without** `com.apple.developer.applesignin`, which is unsupported
  on Developer ID distribution).
- Dicebear SVG avatar URLs are rewritten to PNG before being handed to
  Flutter image decoders, fixing black/missing avatars in the community
  activity card, account hero, and profile sidebar.

### Changed

- Database is now strictly sign-in gated — guest rekey imports and the
  signed-out library fallback were removed in `35a2a57`. `guestAppDatabaseProvider`
  was renamed to `deviceGlobalAppDatabaseProvider` so `enjoy_player.sqlite` is
  clearly device-global settings (not a guest library). See
  [ADR-0012](docs/decisions/0012-per-user-sqlite-isolation.md) and
  [ADR-0031](docs/decisions/0031-login-only-access.md).
- macOS local/Xcode builds no longer reference `com.apple.developer.applesignin`
  (the capability is unsupported on Developer ID distribution and breaks
  provisioning on macOS). iOS still ships with the entitlement on all
  Runner configurations; macOS Direct builds use `ReleaseDirect.entitlements`
  via `notarize_release.sh`.
- `release.ps1` `--notarize` is now auto-enabled when `--publish` builds a
  macOS zip, so direct-download publish flows no longer need to pass it
  explicitly.
- `--norsrc` was added to the macOS zip `ditto` invocation in the Apple
  release CI to omit AppleDouble entries that broke framework seals when
  unzipping downstream.

### Fixed

- **Landing page store buttons**: iOS TestFlight and Android Play beta cards now stay visible when their URLs are unset in `landing/config.js`, rendering a disabled "Coming soon" button (`btn--disabled`, `aria-disabled="true"`) instead of dropping the cards or shipping a broken link. See [docs/packaging.md](docs/packaging.md#updating-store-links) and [ADR-0024](docs/decisions/0024-download-landing-page.md).
- **macOS keychain cold-start (`-34018`)**: `keychain-access-groups` was
  empty, which broke `flutter_secure_storage` in local debug builds and
  trapped the app in an auth retry loop. The app's own keychain group
  (`$(AppIdentifierPrefix)$(CFBundleIdentifier)`) is now set on Debug,
  Profile, Release, and ReleaseDirect entitlements. See
  [docs/features/auth.md](docs/features/auth.md).
- **macOS Developer ID direct-download launch (`error 163`)**: Sign in with
  Apple entitlements are unsupported on Developer ID builds; switching to
  `ReleaseDirect.entitlements` and repacking from a stapled app before
  publish unblocks notarized direct downloads on macOS 26.
- **Apple Sign-In entitlements** on iOS and macOS: `ios/Runner/Runner.entitlements`
  now ships `com.apple.developer.applesignin` referenced from all Runner
  build configurations (`CODE_SIGN_ENTITLEMENTS`) so physical devices no
  longer surface `AuthorizationError error 1000` before the API call.
- **Auth cold-start resilience**: keychain and transient network failures
  during startup are now treated as signed-out (`AuthSignedOut`) instead
  of fatal errors. `AuthCtrl.handleAuthCallbackUri` also catches any
  non-`AuthFailure` error from the token exchange and resets state, so
  the sign-in hub is no longer trapped on the "waiting for browser" pane.
- **Apple release test gate**: macOS Info.plist and Runner entitlements are
  now consistent across local Xcode and notarized release flows, so the
  release Apple workflow no longer gets blocked on missing plist keys.
- **Apple CI on self-hosted mac runners**: `.github/actions/setup-flutter`
  now installs CocoaPods and the iOS toolchain on the self-hosted mac
  runner so `build_apple.yml` and `release_apple.yml` can run end-to-end
  without manual `pod install`.
- **Skipped-frame skeleton crash**: skeleton list placeholders no longer
  crash inside nested scroll views when the parent scroll view computes
  a negative scroll offset during initial layout.
- **Drift `ADD COLUMN` migrations are now idempotent**: `_addColumnIfMissing`
  short-circuits when the column already exists, so downgrading and
  re-upgrading the schema no longer hangs the database open.
- **Blank-window hang after a failed migration**: combined with the
  idempotent ADD COLUMN fix above, the database opens even when the on-disk
  schema includes columns added by a newer build.
- **Local DB recovery paths**: `RecoverySurface` and `performRecoveryReset`
  now point at the correct per-user / device-global database files and
  the in-place reset flow is wired into the recovery UI for the user that
  needs it (with a downgrade-safe migration test). See
  [docs/features/local-database-recovery.md](docs/features/local-database-recovery.md).
- **`TranscriptRepository.watchTracks` re-emissions**: identical watch
  emissions are now deduped with `Stream.distinctBy(_listEqualsTranscriptTrack)`
  so the always-mounted transport bar stops rebuilding on no-op Drift
  ticks (#208). Mirrors the same fix already applied to `watchLines`.
- **Apple Info.plist placeholder URL scheme** is now a valid reversed host
  format (`com.googleusercontent.apps.REPLACE_WITH_CLIENT_ID`) so iOS
  bundle validation stops rejecting the binary before Google Sign-In
  configuration can be completed.

### Security

- Sign in with Apple entitlement is no longer included in the macOS
  ReleaseDirect entitlements (unsupported on Developer ID distribution);
  this narrows the entitlement set for direct-download macOS builds.

## [0.3.1] - 2026-07-03

### Added

- `findSliverIndexByPrefixedId<T>` in `lib/core/utils/sliver_key_index.dart` — shared `findChildIndexCallback` lookup for sliver grids/lists keyed by a `"$prefix${id}"` `ValueKey<String>`.
- `ArtworkPalette` now has value-equality on its four `Color` fields so `Map<ArtworkPalette, ...>` use sites and `==` checks behave like data classes. `@visibleForTesting` cache seams on `lib/core/theme/dynamic_color/artwork_palette.dart`: `debugResetArtworkPaletteCache`, `debugArtworkPaletteCacheSize`, `debugArtworkPaletteCacheContainsPath`, `debugLookupArtworkPalette`, `debugPutArtworkPalette`. 12 tests in `test/core/theme/artwork_palette_test.dart` cover the new invalidation contract.

### Changed

- Home recents grid, discover merged feed grid, and channel feed grid use stable per-row `ValueKey`s + `findChildIndexCallback` so a Drift re-emit or RSS refresh no longer rebuilds every visible tile.
- **Artwork palette LRU cache key**: switched from thumbnail path alone to `(path, size, mtime)`. The in-process LRU in `extractArtworkPalette` re-`stat`s the file on every lookup and evicts any prior entry for the same path whose `(size, mtime)` no longer matches the live stat. LRU cap stays at 32 entries. ADR-0007 updated to describe the new key shape and invalidation contract.

### Fixed

- Documented the `POST /youtube/transcripts` polling contract (request body, attempt/delay budget, `forceRefresh` semantics, and outcome handling) — no behavior change, closes a docs gap between `YoutubeTranscriptsApi` and `docs/features/transcript.md`.
- **Artwork palette stale-cache leak**: re-thumbnailing or rewriting the local artwork file in place used to return the cached palette for the previous bytes because the LRU key was the path string only. Keyed by `(path, size, mtime)` so a regenerate-then-reopen cycle extracts a fresh palette.
- **Windows deep links**: PKCE sign-in callbacks no longer spawn a stray second window. The installer-registered `enjoyplayer://` protocol previously launched a fresh `enjoy_player.exe` per click; that process had no in-memory PKCE state, so the original window was stuck waiting and a second window was left open. `windows/runner/main.cpp` now detects an already-running instance via `FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Enjoy Player")`, forwards the URI to it through `app_links`'s `SendAppLink` (`WM_COPYDATA`), restores/foregrounds that window, and exits. See [docs/features/auth.md](docs/features/auth.md#deep-links-pkce-callback).

## [0.3.0] - 2026-07-01

### Added

- NotFoundScreen fallback route for unknown go_router locations (en/zh/zh-CN localized).
- GitHub issue templates (`bug`, `feature`, `chore`) and a PR template at `.github/`.
- `PlayerEngine.supportsSubtitleDisabling` to skip the no-op `disableRenderedSubtitles` await on YouTube opens.
- `kPositionBucketSessionEmitMs`, `kPositionBucketDisplayMs`, `kPositionBucketScrubberMs` constants in `lib/features/player/application/position_buckets.dart` consolidating three previously inline quantization values.
- `SyncMissingUpdatedAtError` thrown by `SyncUploadService` when the server omits `updatedAt`, preserving local `serverUpdatedAt` instead of silently bumping it to `DateTime.now()`.
- Redesigned **Settings** hub with search, a two-pane layout, and default-collapsed sections; inline Account profile card in the two-pane layout.
- Developer contact bottom sheet from the About section.

### Changed

- `lib/main.dart` wraps the entire bootstrap in `runZonedGuarded` and installs `FlutterError.onError` + `PlatformDispatcher.instance.onError` so framework errors are routed through the diagnostic log pipeline instead of crashing silently.
- `PlayerController.openMedia` catches exceptions from `engine.open` and downstream awaits so a failed open no longer leaves `state` pointing at a phantom session.
- `PlayerController.clear()` flushes the pending `PlaybackSessionPersister` write before cancelling, so swipe-to-dismiss no longer loses the last 450 ms of position updates.
- `YoutubePlayerEngine._emitBuffering(false)` only bumps `mountTick` on the first buffering→false transition per open, reducing ad-reload flicker.
- `_userSessionDatabases` in `app_database_provider.dart` is a bounded `LinkedHashMap` (cap = 2) — oldest entry is closed before inserting a new one.
- `SecureTokenStore` now pins `AndroidOptions()` (v10 RSA-OAEP / AES-GCM with auto-migration from legacy ciphers) and `IOSOptions(accessibility: KeychainAccessibility.first_unlock)`.
- `EmailEntryScreen` BackButton always calls `cancelSignIn()` (it was previously gated on `AuthAwaitingOtp`).
- `_EnjoyAppState.build` uses `ref.listen` to mirror `appPreferencesCtrlProvider` into `_lastResolvedPrefs` via `setState` instead of writing the field as a build-time side effect.

### Fixed

- `VideoPosterCaptureService` seek-zero restore failures now log at warning level (was a nested empty `catch` that swallowed real errors).
- Drift `transcript_fetch_states` missing index — see follow-up.
- Auth deep-link stream subscription now stored + cancelled in `dispose()`; `getInitialLink()` has an `onError` handler.
- `YoutubePlayerEngine.idleAfterClear()` removed a dead branch where `_videoId.isNotEmpty` was checked after `_videoId = ''`.
- Two `kIsWeb` branches removed from `log_file_sink.dart` and `practice_poster_export.dart` per AGENTS.md hard rule.
- Library empty state now shows insight cards alongside the empty-state illustration on the home screen.

### Security

- ADR-0028 accepted: agentic workflows route inference through the MiniMax proxy with CI egress allow-list checks; zero-retention posture pending annual re-verification (medium risk).

## [0.2.3] - 2026-06-24

### Fixed

- YouTube player WebView: unblock Windows release playback (CDN subresource navigation policy).
- YouTube player WebView: harden cross-platform playback recovery after renderer crashes and stalls.

## [0.2.2] - 2026-06-23

### Added

- Local production diagnostics logging and zip export.

### Changed

- YouTube player: poster overlay and warm WebView on init.

### Fixed

- Echo-mode transcript autoscroll crashes without losing scroll accuracy.
- YouTube player WebView: block Google sign-in navigations that interrupt playback.
- Windows debug: silence `accessibility_bridge` AXTree console spam.

## [0.2.1] - 2026-06-16

### Added

- Public download landing page at [get.enjoy.bot](https://get.enjoy.bot) with platform detection, i18n, and feature showcase.
- Cloudflare Pages deploy workflow for the landing site.
- Discover UI tests (horizontal drag scroll, subscription actions).

### Changed

- Discover subscribe sheet: keyboard handling, state management, and layout improvements.
- Discover: horizontal drag scroll behavior; clearer subscription error handling.
- Android: flavor handling docs and build config; JNI merge cache workaround.

### Fixed

- Release publish pipeline: pubspec-versioned artifacts, per-platform `latest.json` overwrites, and macOS release fixes.

## [0.2.0] - 2026-06-10

### Added

- **Discover** tab: browse recommended YouTube channels, subscribe locally, and import videos from a merged upload feed.
- **Unified Library** navigation: Local and Cloud media in one shell tab (`/library?source=cloud`).
- **OTA updates**: in-app update prompts with platform feeds on `dl.enjoy.bot` (Android, iOS, macOS Sparkle, Windows WinSparkle).
- Transcript **recording counts** per line; hotkey **settings** screen and global focus policy.
- **Mobile transport** line navigation for narrow player layouts.
- Signed-in **Home**: today's practice goal and community activity cards.

### Changed

- Library search with `/` hotkey; improved media card thumbnails and YouTube artwork handling.
- Release tooling: shared local/CI scripts, R2 publish pipeline, and local-first packaging docs.

## [0.1.0] - 2026-05-22

First public beta.

### Added

- Initial MVP scaffold: feature-first layout, Drift schema, media_kit player, Riverpod providers, go_router shell with mini player, transcript import (SRT/VTT), echo mode parity with web `echo-utils`.
- Documentation system: AGENTS.md, ADRs, feature specs, Cursor rules.
