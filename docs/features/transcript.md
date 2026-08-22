# Feature: Transcript

## MVP behavior

- Primary transcript = `echo_sessions.transcript_id` for the latest session on `(targetType, targetId)` (same id as library media row).
- **Track list stream** ([`TranscriptRepository.watchTracks`](../../lib/features/transcript/data/transcript_repository.dart)) exposes `List<TranscriptTrack>` per media id and is consumed through `allTranscriptsForMediaProvider`. Each `TranscriptTrack` defines **value equality** across its 7 fields (`id`, `targetType`, `targetId`, `language`, `source`, `label`, `trackIndex`), and the stream applies [`StreamDistinctExt.distinctBy`](../conventions.md#stream-dedupe-long-live-streams) with an element-wise list comparator so identical Drift re-emissions (e.g. an `echo_sessions` bump that doesn't change the resolved track list) never reach Riverpod listeners. Always-mounted consumers like `TransportCcButton` (the transport-bar CC indicator) only rebuild on real track changes — see `test/features/transcript/transcript_tracks_dedupe_test.dart` (9 pinning tests for skip-on-no-op and re-emit-on-real-change).
- Import `.srt` / `.vtt` via `SubtitleParserFacade` storing JSON in `transcripts.timeline_json`. Imports use `source: user` and a user-chosen BCP-47 **language** (one row per `(target, source, language)` via deterministic id).
- **Nested word/phone spans** ([ADR-0070](../decisions/0070-nested-transcript-timeline.md), [ADR-0073](../decisions/0073-craft-timeline-enrichment.md), [ADR-0074](../decisions/0074-karaoke-word-highlight.md), [ADR-0075](../decisions/0075-word-level-practice.md), [ADR-0076](../decisions/0076-stacked-ipa-player-controls.md), [ADR-0078](../decisions/0078-on-demand-transcript-enrichment.md)): a cue MAY include optional `timeline` (word spans) and each word MAY include `phones` (IPA + optional seconds), matching enjoy web `TranscriptLine` / `TranscriptWord`. Import, YouTube captions, and ASR still write line-only `{text, start, duration}` until the learner taps **Generate** in the CC sheet. **Craft save always attempts** on-device enrichment and persists nested JSON when alignment succeeds; failure keeps today’s synthesis line timings (or a blank transcript) without blocking save. **Highlight current word** (`transcript.karaokeHighlight`, default off) and **Show pronunciation (IPA)** (`transcript.ipaOverlay`, default off) are toggled from the **CC subtitle sheet** (display section), not Settings. Switches are **gated**: karaoke only when the primary track has timed words on **owned** media (a trusted local file **or** the learner’s cloud `mediaUrl`; not YouTube); IPA only when phone labels exist. Preference values are not wiped when a track cannot paint. When the primary track has lines but enrichment is incomplete (no nested words, or owned media missing timed words/phones), the same card shows an enrich tile (owned: timed words + IPA from this item’s audio, including cloud-library URLs via FFmpeg; YouTube: IPA labels only, no video download). When IPA is on and phones exist, each word is a stacked column (orthography + familiar-form IPA under Noto Sans in the echo orange accent); tap IPA to seek-and-play that word **only if** the word has a usable media window. Karaoke with IPA on uses a bottom border on the active word; overlay off keeps in-place highlight. Lookup text stays orthography. Line identity, echo membership, auto-translate, and blur stay line-level. IPA MUST NOT auto-reveal a blurred cue or leak through blur. There is no first-play / backfill alignment.
- Tap line → seek + optional echo region update (via `PlayerInteractions`) **except** on the **active** cue and cues inside the **echo window**, where the row is **selectable** for dictionary lookup (no tap-to-seek on those rows). See [dictionary-lookup](dictionary-lookup.md).
- **Track / import entry**: Use the player **CC** control (opens subtitle sheet). While cloud fetch runs and no tracks exist yet, the CC icon shows a **spinner**; when tracks exist, a **badge** appears. The transcript panel shows **Fetching subtitles…** during load, **friendly error + Retry** on failure, and the confirmed empty state only after resolution completes. Manual **Extract** / **Add subtitle** / **Refresh from cloud** actions show inline spinners (picker and empty state).
- Subtitle track picker: **narrow** viewports use a draggable **Enjoy** bottom sheet; at **≥ `breakpointRail` (900px)** the same UI opens as a **centered dialog** (max width 560) for mouse-first layouts. The sheet body no longer nests an extra **SafeArea** (the modal already applies safe-area padding). **Loading** differs by presentation: the narrow sheet uses the shared scrollable `SkeletonTranscript`, while the wide dialog uses a bounded column of four `Skeleton.*` rows so it remains valid inside the dialog's `SingleChildScrollView`. **Error** / **empty** states: errors show **friendly** title + hint strings plus **Retry** (raw exception text is not surfaced in the primary message). Each track row is a **compact single-line tile**: leading radio, title, compact provider + language `MetaChip` pills on the same baseline, and a trailing delete `IconButton`; unselected rows are borderless with a 1px bottom divider, selected rows show a tinted card so many captions fit the picker viewport. Each track shows **provider** (`official` / `auto` / `ai` / `user`) and language. **Deleting** any transcript clears `echo_sessions` primary/secondary references when that track was selected, reassigns primary using **source priority** (`official` → `auto` → `ai` → `user`, then `createdAt`), and clears secondary if it would duplicate the new primary.
- **Dictionary / translation lookup** ([ADR-0019](../decisions/0019-transcript-dictionary-lookup.md)): opened from transcript text selection. **Narrow**: `showEnjoySheet` + `DictionaryLookupSheet` (draggable). **Wide (≥ rail breakpoint)**: `showEnjoyDialog` with the same content in a bounded **dialog** (no double safe-area wrapper on the sheet body).
- **Import subtitle language** dialog: the language field uses a visible **label** (`subtitlesImportLanguageFieldLabel`) in addition to the hint copy.
- **Generate / re-generate transcript (ASR)**: local files with no transcript
  expose **AI transcript** in the empty state; remote media (including YouTube)
  show a tailored hint explaining that ASR is unavailable for remote sources, with
  UI actions scoped to what is available for that source type. The subtitle picker
  always exposes AI transcript or Re-generate depending on whether an `ai` track
  exists. See `TranscriptEmptyState` (`transcript_empty_state.dart`) for the
  local vs remote branching (`noTranscriptHint` / `noTranscriptHintRemote`).
  Generated lines are stored as a first-class `source: ai` track and made
  primary. Re-generation uses the same deterministic row id, preserving the
  active echo-session reference while replacing the timeline in place. Remote
  and YouTube sources are rejected before ASR starts. See [ASR generation](asr.md).
- **Accessibility**: `TranscriptScrollableList` exposes a **list** semantics label. Each `TranscriptLineTile` exposes a **combined** semantics label (timestamp + snippet, with optional state prefix for current line / echo region). When `AppLocalizations` is absent (e.g. bare widget tests), semantics fall back to non-localized cue text only.
- **Cloud transcripts**: In the **background when you open** a library item, the app runs **`resolveOnOpen`**: auto-select primary when tracks exist, import adjacent **sidecar** `.srt`/`.vtt` for local files, then call `/api/v1/transcripts` when signed in. Fetch lifecycle is observable in the UI (**CC spinner**, transcript panel **Fetching subtitles…**, picker banner). Outcomes persist in `transcript_fetch_states` (`lastStatus`, `lastError`). Cloud fetch runs once per target until **Refresh transcripts from cloud** in the picker. The same scheduling runs alongside opening the media engine (not gated on the play button). **Signed-out** users still get sidecar import and primary auto-select; cloud fetch is skipped.
- **YouTube (Worker)**: For rows that resolve to YouTube playback (`provider` / URL / `vid` inference), the app currently speaks to the Enjoy Worker **cache-only** API (see [`specs/013-client-yt-transcripts/contracts/worker-cache-api.md`](../../specs/013-client-yt-transcripts/contracts/worker-cache-api.md)). Caption language follows **`videos.language`** (primary subtag sent to the worker). When language is missing or `und`, the worker fetch is **skipped** — the user must set content language first; correcting language clears fetch state so **Retry** can run with the new locale. Transcripts are stored locally with `targetId` = library media id. The worker origin defaults to `https://worker.enjoy.bot` (`kDefaultAiApiBaseUrl` in `lib/data/db/settings_keys.dart`); users can override it via the **AI API base URL** setting in Developer settings, or tap **Use API URL** to make the AI URL follow the main API URL (in-memory until the next override).
  - **Lookup** (`YoutubeTranscriptsApi.getCachedTranscript`, `TranscriptRepository._fetchWorkerCachedTranscript`): the app calls `GET /youtube/transcripts?videoId&language` first; on 404 it falls back to a direct InnerTube caption fetch on the client (and uploads the result back to the worker — see **upload** below).
  - **Upload** (`YoutubeTranscriptsApi.uploadTranscript`, `TranscriptRepository._uploadToWorkerAfterDirectFetch`): a client-side InnerTube fetch result is sent to `POST /youtube/transcripts` as `fire-and-forget`. The body carries `format: "enjoy"`, `videoId`, `language`, `captionFetch` (derived from `source`: `official` → `official`, anything else → `auto`), `source`, `timeline`, optional `metadata`, and `generatedAt` (ISO 8601 UTC). `ApiClient` converts camelCase keys to snake_case on the wire (`format`/`video_id`/`language`/`caption_fetch`/`source`/`timeline`/`generated_at`). `videoId` is `VideoRow.vid` when it matches the Worker's 11-character YouTube id pattern (`^[a-zA-Z0-9_-]{11}$`); otherwise the client falls back to `youtubePlaybackVideoId(...)` derived from provider / `mediaUrl` / source. `language` is the base subtag from `workerLanguageBase`.
  - **Validation** (worker, `apps/worker/src/routes/youtube/_validation.ts`): the worker rejects uploads missing `format`, `caption_fetch`, or `generated_at`, or with `caption_fetch` outside `auto`|`official`. The Dart client therefore **always** includes these three fields; transport/validation failures are swallowed and treated as a no-op (`uploadTranscript` returns `false`, callers ignore it).
  - **Profiles** (`YoutubeTranscriptsApi.fetchClientProfiles`): the worker exposes the current YouTube InnerTube client profiles at `GET /youtube/client-profiles`, returning a `{"version", "profiles"}` envelope. Each profile on the wire is `{name, version, client_name_header, user_agent, context}` (`name` = InnerTube client name like `IOS`; `version` = client version). `ApiClient` snake→camel converts keys; `ClientProfile.fromJson` maps that shape (and the local camelCase cache shape) into `ClientProfile`, using `castJsonObjectOrNull` for nested `context`. The client then runs `resolveCaptionClientProfiles`: remote versions overwrite matching built-ins, missing preferred clients (`ANDROID_VR`, `MWEB`, …) are gap-filled from `kBuiltInClientProfiles`, and the list is reordered into the caption ladder (`IOS` → `ANDROID_VR` → `ANDROID` → `MWEB` → `WEB`). On envelope loss / transport error / empty usable list the call uses built-ins alone. Profiles are spoofed YouTube clients — they are **not** selected from the Flutter host OS.
  - **Worker transit logging** (`YoutubeTranscriptsApi`, logger `YouTubeTranscripts`): every cache GET, upload, and profile fetch downgrades the API result on exception (so callers keep their fire-and-forget contract) but logs at **WARNING** with the offending video id / language / source / line count. A swallowed upload is otherwise invisible — operators need a production signal whenever a Windows fetch → Android cache miss silently regresses, so the failure is intentionally not silenced at the log layer. Look for entries like `worker upload failed for <videoId>/<language>` in `debugPrint`, logcat, and the rotating log file when triaging "captions work on Windows but never appear on Android" reports.
  - **Historical note** ([ADR-0036](../decisions/0036-youtube-bilingual-transcripts.md), issue #320): the worker previously exposed a poll-based `POST /youtube/transcripts` that the client drove with `pollTranscript` / `pollTranscripts`. That endpoint was retired upstream; the corresponding client methods were removed (dead code, no production callers) and the legacy 008 contract doc is gone — the cache-only API above is the supported contract.
  - **Label / metadata**: the stored transcript's `label` prefers `response.metadata.title` (trimmed, if non-empty); otherwise it falls back to the hardcoded (non-localized) string `"YouTube captions (<language>)"` where `<language>` is the same base subtag sent in the request.
- **Embedded subtitles (video)**: No automatic demux. The picker and the transcript **empty state** offer **Extract** (video only); streams are saved as `source: user` (same uniqueness as imports). If `media_kit` has not listed subtitle tracks yet, the app falls back to **`ffmpeg -i`** stderr to find `Subtitle:` streams and demuxes with `-map 0:s:N` (same as before when tracks were known). **Windows**: Demux uses `ffmpeg.exe` next to `enjoy_player.exe` (installed from `windows/ffmpeg/ffmpeg.exe` when present at build time) or **`ffmpeg` on PATH**. If neither is available, extraction no-ops; users can still import `.srt` / `.vtt`. Details: [`windows/ffmpeg/README.md`](../../windows/ffmpeg/README.md).
- **On-video subtitles**: Disabled by default (`SubtitleTrack.no()` after open + `SubtitleViewConfiguration.visible: false` on [`Video`](../../lib/features/player/presentation/layouts/video_player_layout.dart)); cues are shown in the transcript panel instead.
- **Markup**: SSA/HTML-like cues (`<font color="…">`, `<b>`, `<i>`, `<br>`, etc.) are parsed in the transcript panel via `parseSubtitleMarkup` (`lib/data/subtitle/subtitle_markup_parser.dart`); colors and styles render as rich text instead of raw tags.
- **Line UI**: Each cue has a compact **meta row** (timestamp first; **recording count** badge with mic icon when shadow-reading takes overlap that cue by time range), then body text after a **2px** gap. Horizontal line padding is **16** from `EnjoyThemeTokens.transcriptLinePadding` (do **not** pass `EdgeInsets.horizontal` into `EdgeInsets.symmetric` — that getter sums left+right). Vertical padding comes from [`TranscriptDensity.lineVerticalPadding`](../../lib/core/transcript/transcript_density.dart). Row backgrounds are **transparent** by default; **hover**, **active playback**, **echo-range**, and **active inside echo** use distinct tints (playback within the echo region blends echo orange with primary vs plain active vs echo-only lines).
- **Active-line rail**: the **active** playback line carries a **3px left rail** (rounded ends) colored **primary** for a plain active cue and **echo orange** for a cue inside the echo region — also when both apply. Cues outside the active/echo set have no rail.
- **Secondary (translation) track hierarchy**: when a translation track is rendered alongside the primary line, it sits below the primary with a **2px left border** tinted `onSurfaceVariant @ 22%` to keep reads ordered without italic. Rendered through `Noto Sans SC` with the same CJK fallback chain as the primary track — see [app-ui § Typography](app-ui.md#typography).
- **Auto translate** ([ADR-0038](../decisions/0038-viewport-per-line-auto-translate.md), persistence from [ADR-0037](../decisions/0037-transcript-auto-translate.md), identity from [ADR-0039](../decisions/0039-auto-translate-primary-text-keyed-overlay.md)): the translation picker offers **Auto translate** after **None** (AI `source: ai` tracks are hidden from the generic list to avoid duplicate rows). Selecting it ensures a durable AI secondary track keyed by native language; the transcript list then calls `requestTranslateLine` for each built row with empty AI text (viewport / cache-extent driven, ≤2 concurrent). Finished lines are **cached in Drift** — scrolling away and back shows cached text without re-requesting. Display uses the **primary line index** (not time matching); each cue stores a `sourceKey` fingerprint of normalized primary text + language pair so edited primary text soft-invalidates that line. Identical primary lines can reuse a cached translation. Each translated line has an inline **refresh** control to re-translate that line only. In-flight lines show a compact “Translating…” placeholder. Coexists with YouTube bilingual secondary tracks and imported captions (those still use time-based matching).
- **Recording counts** read from local Drift (`recordings` table); when signed in, cloud metadata sync runs on media open ([`schedulePlayerOpenSideEffects`](../../lib/features/player/application/player_open_side_effects.dart)) and counts update live when new takes are saved in echo mode.
- **Auto-follow**: While the engine is **playing**, the list auto-scrolls when the target would be off-screen (`Scrollable.ensureVisible`). **Non-echo**: the **active cue** is brought into view with a mid-viewport bias (`alignment ~0.42`). **Echo mode**: the merged **echo block** (controls + cue card + shadow-reading stack) is the scroll target and is aligned to the **top** of the transcript viewport to leave more vertical room for the shadow panel. When paused, the list does not auto-scroll.
- **Echo region** (echo mode on): **Expand / shrink** controls sit **between** the transcript list and the shadow panel as separate rows (not inside the cue card). **Cue lines** use one merged rounded **transcript card**; **shadow reading** is a **compact stack** below with an **idle toolbar** (optional **share** slot on the left, pitch **icon** toggle, **centered** 44pt record FAB inside a 56pt hit/ring target, play + **more** menu **grouped at center**; **delete** is in the menu as a **list-style row** (leading delete icon, same column as take checkmarks), with a **confirm dialog** before removal), **pitch chart** when expanded (headerless body only), and **recording focus** (centered FAB + elapsed vs segment target; over-target warning only). Long hint is in the record control **tooltip** (shortcut + `shadowReadingHint`) — see [`ShadowReadingPanel`](../../lib/features/shadow_reading/presentation/shadow_reading_panel.dart). Take duration is derived from the **WAV header** (see [`wav_duration_ms`](../../lib/core/audio/wav_duration_ms.dart)). Take playback uses a dedicated **`media_kit`** preview player ([`recording_preview_player`](../../lib/core/audio/recording_preview_player.dart)), separate from lesson playback so the loaded lesson is not replaced. The share slot hosts [`SharePracticePosterButton`](../../lib/features/share_poster/presentation/share_practice_poster_button.dart); it is visible only when echo mode is active **and** recordings exist for the active target — see [ADR-0068](../decisions/0068-shadow-toolbar-share-button.md).

## Mobile density

Transcript list and echo-region chrome use [`TranscriptDensity.of(context)`](../../lib/core/transcript/transcript_density.dart) to switch between full and compact values. Compact is selected when `isMobilePlatform` ([`lib/core/platform/mobile_platform.dart`](../../lib/core/platform/mobile_platform.dart)) is true (iOS / Android). Values are summarized below:

| Property | Desktop | Mobile |
|----------|--------:|-------:|
| ListView horizontal padding | 12 | 8 |
| ListView vertical padding | 8 | 4 |
| Transcript line vertical padding | 6 | 4 |
| Inter-line gap | 4 | 2 |
| Header-to-body gap | 2 | 2 |
| Primary-to-secondary gap | 4 | 2 |
| Secondary text left padding | 12 | 8 |
| Body line height | 1.45 | 1.35 |
| Secondary line height | 1.4 | 1.3 |
| Echo controls vertical padding | 4 | 2 |
| Echo card gap | 8 | 4 |
| Echo bottom-panel gap | 8 | 4 |
| Echo divider thickness | 1.0 | 0.5 |
| Echo control icon size | 20 | 16 |

The horizontal transcript line padding stays at 16 across both platforms so the active-line rail and 44dp tap targets remain readable (`transcriptLinePadding` is horizontal-only; vertical comes from density). The density is resolved from each affected widget's `BuildContext` so the choice follows the live `defaultTargetPlatform` (no static-initialized token).

## Code layout

The subtitle track picker is split into focused modules under
[`lib/features/transcript/presentation/`](../../lib/features/transcript/presentation/),
organized by dependency layer (helpers → primitives → tiles → sections →
actions → sheet). The public API is unchanged; `showSubtitleTrackPicker`,
`SubtitleTrackPickerSheet`, and `SubtitleTrackPickerPresentation` continue to
be exported from [`subtitle_track_picker_sheet.dart`](../../lib/features/transcript/presentation/subtitle_track_picker_sheet.dart).

| File | Responsibility |
|------|----------------|
| [`subtitle_track_picker_helpers.dart`](../../lib/features/transcript/presentation/subtitle_track_picker_helpers.dart) | Pure helpers (`sheetHorizontalPadding`, `trackOptionPadding`, `trackPickerRadioTheme`, `subtitlePickerCardDecoration`, `subtitlePickerSectionTitleStyle`, `trackLabel`, `findTrack`, `providerLabel`, `providerBadgeColors`), the `kExpandedTrackListMaxHeight` const, and the `PickerSection` enum. No widgets. |
| [`subtitle_track_picker_primitives.dart`](../../lib/features/transcript/presentation/subtitle_track_picker_primitives.dart) | `MetaChip`, `SubtitlePickerCard` (shared rounded card chrome), and `SubtitleToggleTile` (compact switch rows for karaoke / IPA). |
| [`subtitle_track_picker_tiles.dart`](../../lib/features/transcript/presentation/subtitle_track_picker_tiles.dart) | `TrackOptionTile<T>` (per-track radio row with provider + language chips and delete action) and `NoneOptionTile` (the explicit "none" row in the translation list). |
| [`subtitle_track_picker_sections.dart`](../../lib/features/transcript/presentation/subtitle_track_picker_sections.dart) | `CollapsibleTrackSection` (the expandable card used for both primary and translation lists) and `SelectionSummary` (collapsed-state label + chip summary). |
| [`subtitle_track_picker_actions.dart`](../../lib/features/transcript/presentation/subtitle_track_picker_actions.dart) | `SubtitleActionsSection` — Extract / Refresh / Import (and Generate) list inside `SubtitlePickerCard`. |
| [`transcript_display_settings_sheet.dart`](../../lib/features/transcript/presentation/transcript_display_settings_sheet.dart) | `TranscriptDisplaySettingsSection` — gated karaoke + IPA toggles and the on-demand enrich tile. |
| [`subtitle_track_picker_sheet.dart`](../../lib/features/transcript/presentation/subtitle_track_picker_sheet.dart) | Slimmed sheet: `SubtitleTrackPickerPresentation` enum, `showSubtitleTrackPicker` launcher, and `SubtitleTrackPickerSheet` + its state class. Owns the `PickerSection` expand/collapse state and provider interactions (import file, extract embedded, refresh cloud, delete track). |

Smoke coverage lives in
[`subtitle_track_picker_sheet_test.dart`](../../test/features/transcript/subtitle_track_picker_sheet_test.dart)
(pumps the sheet in dialog presentation with faked providers and asserts the
empty-tracks hint plus primary + translation section headers for a single
track). The split is also recorded as
[`2026-07-07-subtitle-track-picker-split-design.md`](../superpowers/specs/2026-07-07-subtitle-track-picker-split-design.md).

### Transcript repository shape

[`TranscriptRepository`](../../lib/features/transcript/data/transcript_repository.dart)
owns the transcript surface for a media target. Every public member is a
class method (virtual, overridable by test fakes); the YouTube internals are
the only part-file extensions, both private:

| Part file | Responsibility |
|-----------|----------------|
| [`transcript_repository_youtube_fetch.dart`](../../lib/features/transcript/data/transcript_repository_youtube_fetch.dart) | YouTube transcript fetch orchestration: worker cache lookup, InnerTube direct fallback, worker upload, post-fetch primary picker |
| [`transcript_repository_youtube_worker_cache.dart`](../../lib/features/transcript/data/transcript_repository_youtube_worker_cache.dart) | Worker cache-only API interaction (`GET /youtube/transcripts`, `POST /youtube/transcripts`) |

Interface notes:

- `resolveOnOpen` is the single public entry for the open path. Its steps —
  primary auto-select and sidecar import — are private
  (`_ensurePrimaryTranscript`, `_importSidecarSubtitles`); callers never
  orchestrate them.
- Subtitle import (`importSubtitle`, `extractEmbeddedTracks`) and
  auto-translate track management (`ensureAutoTranslateTrack`,
  `updateAutoTranslateLineText`, `isAutoTranslateTrackStale`) are class
  methods alongside the rest of the surface.
- Reactive lines are repo-owned: `watchPrimaryLines(mediaId)` /
  `watchSecondaryLines(mediaId)` hide target-type resolution, the
  active-row-only fetch, the 16 KB isolate-preload threshold, and the
  merge/distinct of echo-session + transcript watches. The Riverpod
  providers in `transcript_lines_provider.dart` are thin wrappers.

## Blur practice (listening-focus) mode

A "Blur practice" toggle in the bottom transport bar (next to the Echo
button) renders every transcript cue body text with a CSS-style
`ImageFilter.blur` filter so the user can practice listening first and
then peek at the text to check themselves. Like echo, blur is a
**per-media player practice mode** (not a Settings preference). The
mode is deliberately hearing-focused:

- The **active playback cue is never auto-revealed**. Even when
  playback runs through the transcript, every cue — including the
  currently playing one — stays blurred. See
  [`specs/006-transcript-blur-practice/spec.md`](../../specs/006-transcript-blur-practice/spec.md)
  § Clarifications (Session 2026-07-08) for the user-facing rationale
  and the rule.
- The only ways to see a cue's text in blur practice mode are
  pointer hover (macOS, Windows) or a tap that starts a hold
  (every platform).

### Toggle, hover, and tap-reveal

- The **toggle** lives in the bottom transport bar's secondary tool
  cluster, immediately after the Echo button
  ([`global_transport_bar.dart`](../../lib/features/player/presentation/widgets/global_transport_bar.dart)).
  It mirrors the Echo button styling (active state tinted with the
  `blurActive` token) and carries a hotkey hint in its tooltip. The
  `H` key toggles it via `PlayerInteractions.toggleBlur()`.
- On macOS and Windows, **hovering a cue unblurs it**; pointer-out
  re-blurs it within one frame. The hover state is owned by the tile
  widget itself so per-frame hover changes do not invalidate unrelated
  cues. This now applies to active and echo cues too — selectable tiles
  carry the same `MouseRegion` as plain cues.
- On every platform (including desktop as a fallback), **tapping a
  blurred cue starts a fixed 3-second hold** (`kTapRevealHoldSeconds`)
  that reveals it. For plain cues the tap also seeks playback to that
  cue; for selectable (active / echo) cues the tap reveals without
  seeking. During the hold the cue is unblurred; when the hold expires
  it re-blurs. Tapping a different cue replaces the hold (the prior cue
  re-blurs immediately, the new cue reveals). Hold duration is **not**
  user-configurable.

### Persistence

Blur on/off is stored per target on `echo_sessions.blur_active`
(device-local, same row as echo practice fields — **not** synced to the
server profile):

- In-memory state: `transcriptBlurModeProvider`
  ([`transcript_blur_mode_provider.dart`](../../lib/features/transcript/application/transcript_blur_mode_provider.dart)).
- Written by [`PlaybackSessionPersister`](../../lib/features/player/application/playback_session_persister.dart)
  (debounced position ticks + immediate `writeNow` on toggle).
- Restored in [`player_open_coordinator.dart`](../../lib/features/player/application/player_open_coordinator.dart)
  when opening media; cleared with `deactivate()` in
  [`PlayerController.clear`](../../lib/features/player/application/player_controller.dart).

### Rendering

The blur is applied via `TranscriptBlurText`
([`lib/features/transcript/presentation/transcript_blur_text.dart`](../../lib/features/transcript/presentation/transcript_blur_text.dart))
inside `TranscriptLineTile`. Only the body text widgets are wrapped —
timestamps, recording badges, hover tints, the active-line rail, and
the merged echo card chrome (rails / dividers / controls) are never
blurred; the cue text inside the echo card is. When the toggle is off
the cue renders exactly as before (zero overhead).

### Active-line and active-cue rule (the 2026-07-08 clarification)

The original draft proposed an "always reveal the active line" rule
as the bridge between desktop hover and mobile interactions. The user
corrected this: the purpose of the mode is hearing-focused practice,
so revealing the active line defeats the goal. The active cue has no
privileged state — `transcriptCueRevealProvider`
([`lib/features/transcript/application/transcript_cue_reveal_provider.dart`](../../lib/features/transcript/application/transcript_cue_reveal_provider.dart))
explicitly does NOT read
`transcriptPlaybackHighlightProvider`, and the widget-level OR
(`!blurEnabled || _hover || providerRevealed`) treats the active cue
exactly like every other cue.

### Echo mode

Blur practice mode continues to apply to cues rendered inside the
echo region, including the active echo cue. Hover and tap-reveal work
the same way as plain cues: the echo tiles carry a `MouseRegion`
(hover reveal) and tapping the cue text starts the reveal hold. Only
the cue body text is blurred — the echo card chrome and the
shadow-reading panel are not.

### Tests

Coverage lives under
[`test/features/transcript/`](../../test/features/transcript/) and
[`test/features/player/`](../../test/features/player/):

- `transcript_blur_mode_provider_test.dart` — activate / deactivate /
  toggle / restoreFromSession.
- `transcript_blur_session_persist_test.dart` — `blur_active` written
  via `PlaybackSessionPersister.writeNow` and restored.
- `global_transport_bar_test.dart` — the blur toggle's off/on icon
  states, disabled state when there are no transcript lines, and that
  a tap flips `transcriptBlurModeProvider`.
- `transcript_blur_hover_test.dart` — pointer-enter reveals;
  pointer-out re-blurs; toggle-off bypass.
- `transcript_blur_selectable_reveal_test.dart` — the active / echo
  (selectable) cue reveals on hover and tap-reveal, matching plain cues.
- `transcript_blur_hold_test.dart` — tap seeks + reveals; expiry
  re-blurs; second tap replaces the hold; toggle-off bypass.
- `transcript_blur_active_line_stays_blurred_test.dart` — drives the
  active cue through several indices while blur is on and asserts the
  active cue never auto-reveals (the spec's hard rule). Karaoke on does
  not change that contract. IPA overlay on also must not auto-reveal or
  leak stored phone labels through an unrevealed cue.
- `transcript_blur_long_list_perf_test.dart` — 10 000-line smoke
  under `ImageFiltered`; per-frame budget assertion.

## Alignment engine (Craft save + on-demand enrich)

`packages/forced_alignment` maps known text + 16 kHz extractable PCM to
word/phone timings (Echogarden-shaped result, flatten adapter for enjoy-web
`WordTiming` / `PhoneTiming`). Production success requires a same-language
**spoken** eSpeak-NG reference (waveform + word/phone events), not a
duration-model tone stand-in. Missing voice → `spokenReferenceUnavailable`.
**Craft save** is the automatic product caller ([ADR-0073](../decisions/0073-craft-timeline-enrichment.md) /
[ADR-0076](../decisions/0076-stacked-ipa-player-controls.md)):
every real (non-dedupe) Craft write attempts `alignSegments` and may attach
nested spans onto spec 030 lines. **On-demand enrich** ([ADR-0078](../decisions/0078-on-demand-transcript-enrichment.md))
is the CC-sheet button: owned media (local file **or** the learner’s cloud
`mediaUrl`) extracts 16 kHz mono PCM via
[`pcm16k_mono.dart`](../../lib/data/audio/pcm16k_mono.dart) (**FFmpegKit** on
Android/iOS/macOS; CLI `ffmpeg` on Windows and Linux, including a binary next
to the Linux app/AppImage). Cloud HTTP(S) URLs are first downloaded with Dart
[`http`](../../lib/data/audio/http_media_download.dart) so FFmpeg only sees a
local file on every platform. While a long file runs per-cue extract + `align()`,
the enrich tile shows **cue N of M** plus a determinate bar and stays tappable
to cancel. YouTube phonemizes
caption text (untimed words + IPA labels, no demux). Karaoke highlight
([ADR-0074](../decisions/0074-karaoke-word-highlight.md))
and IPA display ([ADR-0076](../decisions/0076-stacked-ipa-player-controls.md))
only **read** stored spans when their player transcript toggles are on **and**
capability gating allows it; they do not run alignment on open/play/seek.
Learners never hear the spoken reference. Import / YouTube / ASR remain
line-only writers until enrich. macOS embeds `libespeak-ng.dylib` and iOS
embeds `eSpeakNG.framework` plus the trimmed voice data (see
[packaging.md](../packaging.md#espeak-ng-alignment-reference)). Android
extracts the same tree from Flutter assets and must include `espeak-ng-data/lang/`
(Flutter does not recurse directory assets) or `espeak_SetVoiceByName`
fails; a missing lib on other packaged hosts still fail-closes. See
[ADR-0071](../decisions/0071-on-device-alignment-engine.md)
and [ADR-0072](../decisions/0072-spoken-alignment-reference.md).

## Future

- Multiple languages, editing timelines, export — parity with web `TranscriptDisplay`.
