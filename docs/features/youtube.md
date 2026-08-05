# YouTube playback

## Summary

Users **Import → From YouTube URL** and paste a watch URL, short URL, embed URL, or raw video id. The app stores a `videos` row with `provider: youtube` and `vid` set to the canonical id. A **content language** is collected at import time (YouTube does not expose original language via oEmbed) and can be edited later from Library. Playback uses **`flutter_inappwebview`** loading `https://m.youtube.com/watch?v=<vid>` and controlling the page HTML5 `<video>` (not the iframe embed API — see [ADR-0015](../decisions/0015-youtube-playback.md)).

## Metadata

- **Title / thumbnail**: best-effort [YouTube oEmbed](https://oembed.com/) on import; if it fails, title falls back to `YouTube video <id>`. **Discover → Add to library** passes RSS title/thumbnail when available. When a row still has placeholder title or missing thumbnail, opening the player triggers a **lazy oEmbed retry** after the WebView reports playback-ready (buffering cleared or duration known).
- **Duration**: filled lazily when the WebView reports `loadedmetadata` / duration stream and the row still has `durationSeconds == 0`.

## Login

Optional **YouTube / Google** sign-in opens a **dedicated** WebView (`/youtube/login`) starting at Google ServiceLogin with `continue=https://m.youtube.com/`. Session cookies (`LOGIN_INFO` / `SID`) on `m.youtube.com` determine logged-in state. Logout clears **all** WebView cookies (see ADR-0015). While that route is open, [`RootShell`](../../lib/features/player/presentation/root_shell.dart) **parks** the permanent player surface ([ADR-0057](../decisions/0057-permanent-player-surface-host.md)) so the player WebView cannot cover the login WebView.

**Session persistence**: cookies live in the app WebView profile (`%LOCALAPPDATA%\…\WebView2` on Windows — see [`windows_webview_environment.dart`](../../lib/core/webview/windows_webview_environment.dart)) and normally survive app restarts until logout or Google expires the session. Enjoy account sign-in is separate.

The **player** WebView does **not** complete Google login inline — see [Player navigation](#player-navigation) below.

## Player navigation

While a video is open, the player WebView [`shouldOverrideUrlLoading`](../../lib/features/player/application/engines/youtube/youtube_webview_host.dart) applies [`youtube_watch_navigation_policy.dart`](../../lib/features/player/application/engines/youtube/youtube_watch_navigation_policy.dart) ([ADR-0025](../decisions/0025-youtube-player-block-google-signin-nav.md)):

| Navigation | Policy |
|------------|--------|
| `m.youtube.com` / `youtube.com` / `youtu.be` watch and redirect hops | Allow (main frame only) |
| `googlevideo.com`, `ytimg.com`, and other CDN/static asset hosts | Allow |
| Subresource / iframe loads (`isForMainFrame: false`) | Always allow (all platforms) |
| `consent.youtube.com`, `gstatic.com`, `googleapis.com`, other allowed Google static/consent URLs | Allow |
| **`accounts.google.com` (passive or active sign-in)** | **Cancel** (main frame); player reloads watch URL |
| Unrelated main-frame origins | Cancel |

**Why**: YouTube’s mobile watch page often redirects through **passive Google sign-in** when no session cookies exist. In embedded WebViews (especially **release** builds on any platform), that chain can finish without a playable `<video>` — infinite loading. Blocking account navigations in the player keeps anonymous playback on the watch page; the engine reloads the watch URL when sign-in is cancelled. Use **YouTube login** when a signed-in session is needed.

## Transcripts

Captions are fetched **directly from YouTube** (InnerTube `/player` + `fmt=json3`
timed text) and cached on the worker. The chain has three tiers:

1. **Worker GET cache** (`GET /youtube/transcripts?videoId&language`) — fast
   when another client has already fetched this video. Skipped when the video
   row's content language is missing / `und` / `mul` / `mis` / `zxx` (there is
   no useful single `language` to query with).
2. **Client-side InnerTube fetch** — runs through `YoutubeCaptionFetcher`, which
   rotates through worker-published (or built-in) client profiles and downloads
   **every** available caption track in parallel. This is the runtime form of
   spec 013's FR-001 / FR-002 / FR-004.
3. **Worker upload** — every track downloaded in Tier 2 is fire-and-forget POSTed
   back to the worker so the next client (or this client on another device)
   hits Tier 1 instead. Failed uploads are durably enqueued via `sync_queue`
   (entity `video`, payload `kind: youtube_upload`) and drained on the next
   [SyncCtrl] periodic drain — see
   [`transcript_repository.dart`](../../lib/features/transcript/data/transcript_repository.dart).

**Tier 2 always runs for YouTube rows**, even when `videos.language` is empty
or `und`. An unknown language only narrows the Tier 1 lookup and the
`preferredLang` hint passed to the fetcher; the fetcher itself still discovers
all available languages (spec 013 FR-004) and stores them as separate
`TranscriptRow`s keyed by `(target, source, language)`.

### Primary selection

When multiple language tracks are present the post-fetch primary picker ranks
them as:

1. The video's content language (broad subtag match via
   [`matchesLanguageBroad`](../../lib/core/application/app_language_catalog.dart)).
2. The user's **learning** language (broad match). Passed down from
   `AppPreferencesCtrl.effectiveLearningLanguage` through
   `TranscriptFetchCtrl` → `TranscriptRepository.resolveOnOpen` →
   `_fetchYoutubeTranscriptsWithFallback`.
3. Existing source priority (`official` → `auto` → `ai` → `user`, then
   `createdAt`).

A user-picked primary already on the session is **always preserved** —
`_pickYoutubePrimary` short-circuits when `echoSessionDao.transcriptId`
points at a row that still exists. This is the language-aware counterpart
to the source-only `ensurePrimaryTranscript` used for non-YouTube media.

### Client profiles

The InnerTube rotation uses a `youtubeProfilesProvider` that lazily fetches
the worker's `GET /youtube/client-profiles` on first YouTube open, caches the
result in a 24 h `L1Store`, and **merges** remote entries with the compile-time
`kBuiltInClientProfiles` via `resolveCaptionClientProfiles`. Remote versions
win on the same InnerTube `clientName`; missing clients (today often
`ANDROID_VR` / `MWEB` when the worker only ships `IOS` + `WEB`) are gap-filled
from built-ins. The resolved ladder is always ordered
`ios → android_vr → (android) → mweb → web` (see
[`kPreferredCaptionClientOrder`](../../lib/features/transcript/data/client_profile.dart))
— **not** by Flutter host OS. Within a process, the last profile that
returned fetchable tracks is tried first on subsequent videos (session
sticky via `YoutubeCaptionFetcher._lastSuccessfulCaptionProfileKey`; tests
reset it through `resetLastSuccessfulCaptionProfile()`).

**Cold-start fallback.** When the worker is unreachable, the cached 24 h
profile list is stale-but-cached, or the response envelope is malformed,
the client falls back to `kBuiltInClientProfiles` alone (resolved through
the same `resolveCaptionClientProfiles`). These compile-time defaults ship
with **current 2026 YouTube client versions** (iOS `20.12.1`, Android VR
`1.62.20`, MWEB `2.20251209.01.00`, WEB `2.20250709.00.00`) so the ladder
keeps working even on a fully offline cold start — refresh them in
[`client_profile.dart`](../../lib/features/transcript/data/client_profile.dart)
when YouTube ships a new client version, before bumping the spec
contract.

The timedtext GET for each track uses the **same** profile's user agent and
adds `Referer: https://m.youtube.com/` plus `Accept-Language` so the
`youtubei.googleapis.com` endpoint sees a consistent client identity with the
`/player` call that succeeded.

## Limitations

- **Init speed**: Thumbnail artwork shows during player open and while the WebView buffers. The shared WebView may mount during `openMedia()` (overlapping cold-start with DB work) and is **kept warm** after dismiss until the user opens non-YouTube media or the app exits. Optional pre-warm runs when tapping a YouTube row in Library or Discover. After the watch page loads, the engine nudges `<video>.play()` at ~6s if autoplay has not started; **one** full reload may run at ~12s if playback is still stalled (no reload loop once `first_playing`). Playback still uses the mobile watch page — not embed (Error 153 in native WebViews).
- **Play startup (all platforms, Windows especially)**: `flutter_inappwebview`'s `mediaPlaybackRequiresUserGesture` setting is not implemented by its WebView2 backend. Programmatic play therefore starts muted and waits for the authoritative HTML5 `playing` event. First-play volume restore is **progress-gated** (unmute only after `<video>.currentTime` advances, with a ~1.5 s fallback); later pause/resume cycles restore volume immediately. A `play` event alone never marks the app transport as playing; rejected `play()` promises clear buffering and surface the localized tap-to-play hint. Transport toggle uses an atomic DOM-aware `playOrPause` script so a stale Dart `playing=true` cannot issue another `pause()` while the element is already paused. Explicit user/app play cancels the 6 s nudge and defers stall reloads. Clicking the video pane must reach the WebView — host chrome overlays use `MouseRegion(opaque: false)` / `IgnorePointer` so empty regions do not swallow that gesture.
- **iOS inline playback**: the WebView sets `allowsInlineMediaPlayback`, injects `playsinline` on the `<video>`, and hooks iOS native fullscreen to stay inline so the 16:9 frame stays visible for echo / shadow reading. Player and login WebViews share the same Chrome mobile `userAgent` so Google sign-in is not blocked as an insecure browser.
- Position updates while playing are polled (~250 ms); echo clamp may overshoot slightly vs `media_kit`.
- Embedded MKV/MP4 subtitle track extraction is unavailable for YouTube (no `media_kit` decode of the stream).
- Ad behavior depends on YouTube, cookies, and account; “no ads” is best-effort when signed in with Premium where applicable.
- **Captions**: YouTube's own captions/CC (`.ytp-caption-window-container` and any native `<track>` cues) are force-hidden by [`kYoutubeMobileWatchInjectScript`](../../lib/features/player/application/engines/youtube/youtube_page_inject.dart) — injected CSS, disabling `video.textTracks`, and unloading the player `captions`/`cc` modules on every hook/enforce cycle. Some videos default captions on (auto-captions, saved viewer prefs), and since the native control bar is also hidden there would otherwise be no way to turn them off; the app's own transcript panel (see [Transcripts](#transcripts) above) is the only caption source shown to users.

## Buffering transitions

`YoutubeSession.emitBuffering(false)` only bumps the internal `mountTick` on the **first** buffering → not-buffering transition per open. Mid-roll ad breaks and re-bufferings after the first play do not retrigger the tick, so the player UI does not flash the loading indicator on every ad pause. Tests for the buffering state should cover the "buffering → playing → buffering → playing" sequence and assert the mountTick only changes once.

## Playback stall detection

[`YoutubePlaybackStallWatchdog`](../../lib/features/player/application/engines/youtube/youtube_playback_stall_watchdog.dart) detects YouTube videos that load but never reach their first frame. After the WebView fires `onLoadStop`, a **12-second** timer starts; if no `playing` event arrives within that window, `onStall(videoId)` fires, logs `youtube playback stalled after load_stop`, and triggers **at most one** full watch-page reload (`recoverStalledPlayback`). Further stalls nudge `play()` only. Explicit user/app play cancels the watchdog and skips the reload path so an in-flight play is not aborted. The timer resets on each new `onLoadStop` (navigating to a new video).

## Platform notes

| Platform | WebView | Profile / cookies | Navigation policy (ADR-0025) | Process crash recovery |
|----------|---------|-------------------|------------------------------|-------------------------|
| **Windows** | WebView2 via [`platform_webview_environment.dart`](../../lib/core/webview/platform_webview_environment.dart) — user data under `%APPDATA%…\WebView2` (required for Program Files installs) | Shared environment for player + login + Enjoy sign-in | `shouldOverrideUrlLoading` + CDN subframe allowlist | N/A (reload via stall watchdog) |
| **Android** | System WebView | App data directory | `useShouldOverrideUrlLoading: true` | `onRenderProcessGone` → reload watch URL |
| **iOS** | WKWebView | App sandbox | Same policy; `isForMainFrame: null` treated as subframe | `onWebContentProcessDidTerminate` → reload |
| **macOS** | WKWebView | App sandbox | Same as iOS | `onWebContentProcessDidTerminate` → reload |

Login WebViews use the same Windows [`appWebViewEnvironment`](../../lib/core/webview/platform_webview_environment.dart) so YouTube cookies from **YouTube login** apply to the player WebView.

## Troubleshooting (release / cold profile)

If YouTube stalls on loading in a **release** or installed build but works in `flutter run`:

1. Confirm you are on a build that includes the navigation-policy fix (ADR-0025 + subframe/CDN allowlist).
2. Try **YouTube login** once, then reopen the video (establishes session cookies).
3. Check diagnostic logs for `youtube play command` / `youtube playOrPause command`, `youtube video play requested`, `youtube video playing`, `youtube play rejected`, `youtube volume restored`, `youtube pause confirmed`, `youtube immediate pause`, `youtube init load_stop`, `youtube playback stalled`, or `WebView process terminated`. Enable **Settings → About → Diagnostic logging** before reproduction to include the FINE-level command, event, and poll-transition records. Smoking-gun pattern for the intermittent play→pause bug: `playing` → (optional `volume restored`) → `immediate pause` / `pause confirmed` within ~2 s.
4. **Windows only**: compare portable `build\windows\x64\runner\Release\enjoy_player.exe` vs Program Files install. Installed builds require a writable WebView2 user-data folder (not next to the exe); diagnostic logs include `webViewUserData=…` and `exe=…` on each session. Shortcuts from the installer set `WorkingDir` to the install folder.

Policy rules are unit-tested in [`youtube_watch_navigation_policy_test.dart`](../../test/features/player/youtube_watch_navigation_policy_test.dart).
