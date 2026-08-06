# Feature: Shadow reading (echo)

## Summary

Shadow reading is the **record-while-you-listen** flow that lives below the **echo region** in the expanded player. The user listens to a cue, records themselves reading it back via the **shadow reading panel**, optionally runs **Azure pronunciation assessment** on the take, and (now) can **export a shareable practice poster** (see [`echo-mode.md`](echo-mode.md) and [`share-poster.md`](share-poster.md)).

The panel is mounted when **echo mode is active** in the expanded player (with a usable transcript), and also in the vocabulary review **Echo reading** practice overlay (recorder-only, with the context sentence shown above the controls). Global record / play-take / pitch / assess hotkeys pulse `ShadowReadingHotkeyBus` whenever a player session is open **or** vocabulary echo practice is open.

## Recording bus

The recording bus is the single source of truth for "is the user recording right now":

- `ShadowReadingHotkeyBus` (a singleton bus, generated from `shadow_reading_hotkey_bus.dart`) emits typed events (`ShadowRecordingHotkeyEvent`) when the user presses the global shortcut, toggling the panel's idle toolbar state. The bus decouples the hotkey layer (which knows nothing about the panel) from the UI.
- Mic selection is persisted in `SettingsKeys.prefsRecordingInputDeviceId` and re-read on every take via `recordingInputDeviceCtrlProvider`. Unknown / virtual devices are skipped by `pickPreferredInputDeviceId` (GlideX Shared Audio, VoiceMeeter, VB-Audio CABLE, NVIDIA Broadcast, etc.) so Windows defaults don't silently capture only zeros.

## Idle toolbar (centered FAB)

- The panel shows an **idle toolbar** with the **pitch icon**, a centered **FAB** (start recording), **play**, and **pronunciation assess**. Delete moves into a **more** menu gated by a confirmation dialog.
- When recording is in flight, the panel swaps to **recording-only focus**: FAB + countdown vs the active echo segment, with the pitch chart and takes list hidden until the take is committed.
- All idle toolbar controls use **≥44×44** hit targets where possible; the assessment badge control is **44×44** with explicit `Semantics(label, button)` so VoiceOver / TalkBack see it as a control, not only a tooltip.

## Pitch contour

When the user opts in, the panel runs **pitch contour** analysis on the take:

1. `echo_segment_pcm_extractor.dart` extracts the relevant echo segment to a temp `.raw` via **FFmpeg** (CLI on Windows, FFmpegKit elsewhere). Extraction is **cancellable** (`EchoPcmCancelToken` kills the live FFmpeg process/session) and **bounded** by a per-call timeout; failures surface a typed `EchoPcmExtractionException` (e.g. `ffmpegMissing`) instead of a silent `null`. FFmpeg binary resolution goes through the single shared `FfmpegMediaProbe.resolveFfmpegExecutable()` (memoized for the process lifetime).
2. The byte→Float32 **decode + YIN** (`yin_pitch.dart`) both run inside **one worker isolate** (`Isolate.run`), so the multi-megabyte PCM buffer never blocks the UI thread and never crosses an isolate port — only the ~520-point analysis result is returned.
3. `echo_pitch_analysis_service.dart` caches results per region/recording (so re-opening a region reuses the analysis) and **cancels** — not merely discards — an in-flight extraction when the region/recording changes. Exposed as the keep-alive `echoPitchAnalysisServiceProvider`.
4. `pitch_contour_chart.dart` renders the envelope; `pitch_contour_section.dart` exposes it as a collapsible section that can be **parent-driven** (`expanded`, `showHeader: false` for chart-only body). The merged reference+user series is **memoized** (`EchoMergedSeriesMemo`) so it is built once per (reference, user) pair — identical across playback ticks — and `shouldRepaint` compares the points by content so the painter skips work when only the progress cursor moves.

## Pronunciation assessment (Azure)

The optional **pronunciation assessment** path runs after a take lands:

1. `recording_assessment_controller.dart` requests a **Worker Azure speech token** from Enjoy (`POST /ai/pronunciation/token`) and passes it to the native `azure_speech` plugin. The Azure locale is resolved from the **media/recording language** via [`resolveAzureAssessmentLocaleForPractice`](../../lib/core/application/app_language_catalog.dart). Supported regional tags (e.g. `en-US`, `en-GB`, `es-ES`, `fr-CA`) are preserved. Unknown media tags (`und` / empty — typical for YouTube imports without a set content language) fall back to the learner's **focus language** (then `en-US` default). Real unsupported primaries still **disable** assessment with an explanatory tooltip — the app does **not** silently coerce those to `en-US`.
2. The plugin returns a JSON `pronunciationScore` / `accuracyScore` / `fluencyScore` / `completenessScore` plus per-word detail. The result is persisted to the recording row (`pronunciation_score`, `assessment_json`).
3. `AssessmentResultDialog` / sheet reopens the score when the user taps the score badge. The wide layout uses the **rail breakpoint** (900px), not the transcript breakpoint (720px).
4. Take menu shows per-take scores and a **Re-assess** entry when the current take already has `assessment_json`.
5. **Model pronounce on results** — The selected-word panel offers a shared **Pronounce** control ([ADR-0064](../decisions/0064-word-pronounce-client.md)) for the chosen chip word. It plays Worker model audio (standard pronunciation). Locale uses the same `resolveAzureAssessmentLocaleForPractice` path as the assessment run (`und`/empty media → learning language), not the raw recording tag.
6. **Take replay + karaoke + word clips** — The result surface receives `recordingPath` (`RecordingRow.localPath`). A **Play my recording** control near the overall score replays the full take via the ADR-0003 `RecordingPreviewPlayer` (not `PlayerController`). While the full take plays, word chips get a karaoke-style “current” highlight from Azure per-word `Offset`/`Duration` ticks (converted to ms). Selecting a chip stops full-take playback. The selected-word panel also offers **Play my recording of this word** (timed clip via `playClip`); omissions / zero-duration words disable the clip. Model pronounce, full take, and word clip are mutually exclusive (starting one stops the others). Dismissing the dialog/sheet stops take/clip and model pronounce.

Silent FFmpeg WAV normalize is auto-detected and the resample chain is retried (see commit history around Azure assessment). Zero-score runs are persisted and logged.

## Related

- Echo mode (parent context): [`docs/features/echo-mode.md`](echo-mode.md)
- Share practice poster (echo-tailored export): [`docs/features/share-poster.md`](share-poster.md)
- AI capability routes (assessment, chat, translation): [`docs/features/ai.md`](ai.md)
- Native speech package: `packages/azure_speech/`
- ADR: [`docs/decisions/0005-mvp-scope-local-only.md`](../decisions/0005-mvp-scope-local-only.md) (echo + shadow reading scope)