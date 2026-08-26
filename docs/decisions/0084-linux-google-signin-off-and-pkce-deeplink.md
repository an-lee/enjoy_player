# ADR-0084 — Disable native Google Sign-In on Linux; GTK single-instance PKCE callback plumbing

**Status**: Accepted  
**Date**: 2026-08-26

## Context

First real-world Linux smoke (release AppImage and dev builds) showed both Enjoy account sign-in paths broken:

1. **"Continue with Google" fails on Linux.** ADR-0048 enabled `google_sign_in` on Linux via its browser-based OAuth flow with the explicit R10 kill switch: *"Flip to `false` if first smoke shows a crash or auth loop."* That smoke has now failed.
2. **The web PKCE fallback ("Other sign-in options") cannot return to the app.** After completing sign-in in the browser, the browser invokes `enjoyplayer://auth/callback?...` and the desktop reports it cannot find the application — the flow stalls until the 5-minute timeout. Two independent Linux gaps vs. Windows/macOS:
   - **No OS-level scheme registration.** The only Linux packaging is the AppImage ([`linux/packaging/make_appimage.sh`](../../linux/packaging/make_appimage.sh)), whose desktop entry declared neither `MimeType=x-scheme-handler/enjoyplayer;` nor a `%u` field code, so `xdg-open` had no handler for `enjoyplayer://`.
   - **No single-instance URI forwarding.** The Linux runner created the GTK application with `G_APPLICATION_NON_UNIQUE`, did not set `G_APPLICATION_HANDLES_COMMAND_LINE` / `G_APPLICATION_HANDLES_OPEN`, and overrode `local_command_line` to return `TRUE`. Every launch was an independent process; even with a registered handler, a fresh process would receive the callback but hold no in-memory PKCE state (`code_verifier` / OAuth `state`), while the original instance's `AuthDeepLinkListener` never heard anything — exactly the failure mode the Windows runner already solves with `SendAppLinkToInstance()`.

## Decision

1. **Google Sign-In is hidden on Linux.** `googleSignInAvailableOnLinux` flips to `false` in [`lib/core/platform/linux_platform_availability.dart`](../../lib/core/platform/platform_availability.dart) (the ADR-0048 kill switch). The gate chain (`nativeGoogleSignInSupported` → `SignInScreen`) hides the button automatically. Linux users sign in with **email OTP** or the **web PKCE fallback**.
2. **Linux runner forwards URIs to the running instance** ([`linux/runner/my_application.cc`](../../linux/runner/my_application.cc)), mirroring the app_links upstream example:
   - Flags: `G_APPLICATION_HANDLES_COMMAND_LINE | G_APPLICATION_HANDLES_OPEN` replace `G_APPLICATION_NON_UNIQUE`. The primary instance is now unique per session bus under `ai.enjoy.player.enjoy_player`; secondary launches forward their command line over D-Bus to the primary and exit immediately.
   - `local_command_line` returns `FALSE` so GApplication routes command lines; `activate()` presents the existing window instead of building a second one when invoked on a running instance.
   - A class `command-line` handler skips `argv[0]` and invokes method `command-line` on the `gtk/application` `FlMethodChannel` — the channel `app_links_linux`'s `GtkApplicationNotifier` already listens on — so `AppLinks().uriLinkStream` fires on the primary instance and `AuthCtrl.handleAuthCallbackUri` completes the token exchange. An `open` handler maps D-Bus `Open` requests (portals) onto the same channel.
   - Known limitation (same as Windows): if the app is *restarted* while the browser is open, the callback lands in a process without PKCE state and is ignored with a log line; the user retries sign-in.
3. **The app registers its own callback scheme** ([`lib/core/platform/linux_url_scheme_handler.dart`](../../lib/core/platform/linux_url_scheme_handler.dart)). At Linux startup — and again right before a web PKCE sign-in opens the browser — the app writes a `enjoy-player-scheme.desktop` entry (`MimeType=x-scheme-handler/enjoyplayer;`, `Exec "<target>" %u`) into `$XDG_DATA_HOME/applications/` (default `~/.local/share/applications/`), refreshes the desktop database, and sets it as the default handler via `xdg-mime`. Inside an AppImage the `$APPIMAGE` path (the real `.AppImage` file) is used instead of `Platform.resolvedExecutable`, which only points at a temporary squashfs mount. Registration is idempotent, best-effort, and never blocks sign-in. Plain AppImage runs and dev builds therefore work with no AppImageLauncher integration and no manual `xdg-mime` step; the bundled AppImage desktop entry keeps its own `MimeType=` line as an install-time fallback.
4. **Diagnostics**: `AuthDeepLinkListener` logs every received callback URI (scheme/host/path only — never the query string carrying the OAuth `code`), and `handleAuthCallbackUri` logs when a callback arrives outside an active PKCE flow, so "stuck login" reports are triageable from the diagnostic log.

## Alternatives considered

- *Fix the Google provider flow on Linux* (debug `google_sign_in`'s browser loop) — rejected for now: the kill-switch path was pre-agreed in ADR-0048, email OTP + PKCE fully unblock Linux sign-in today, and the provider can be re-enabled by a follow-up ADR flipping one constant after a verified fix.
- *Loopback HTTP redirect* (`http://127.0.0.1:<port>/callback`) instead of the custom scheme — rejected: the backend client registry whitelists only `enjoyplayer://auth/callback` (+ dev loopback), and [ADR-0034](0034-custom-scheme-only-pkce-callback.md) deliberately standardized on the custom scheme.
- *DBus activation / `.deb` packaging* for scheme handling — deferred per ADR-0048's non-goals; revisit when package-manager installs land.

## Consequences

- **Positive**: The web PKCE flow now completes end-to-end on Linux (browser → scheme launch → D-Bus forwarding → token exchange), matching Windows/macOS behavior — with zero manual scheme registration. Secondary/duplicate launches also collapse into the running window instead of spawning extra processes.
- **Positive**: Linux sign-in options become honest: no button that cannot succeed.
- **Negative**: Re-enabling native Google Sign-In on Linux requires debugging `google_sign_in`'s Linux backend and a new ADR flipping the constant back.
- **Risk**: Dev builds share the application ID with installed release instances; launching a dev build while the AppImage runs forwards the URI to whichever instance registered the bus name first. Same class of caveat as Windows' `FindWindow` approach.
- **Follow-up**: When `.deb`/Flatpak/snap packaging lands (ADR-0048 follow-up), ship the desktop file with the same `MimeType=` line so the handler registers at install time.

## References

- [ADR-0034 — custom-scheme-only PKCE callback](0034-custom-scheme-only-pkce-callback.md)
- [ADR-0048 — Linux as a first-class supported desktop platform](0048-linux-platform-support.md)
- [docs/features/auth.md — Deep links (PKCE callback)](../features/auth.md#deep-links-pkce-callback)
- [docs/features/linux-platform.md — Troubleshooting](../features/linux-platform.md#troubleshooting)
