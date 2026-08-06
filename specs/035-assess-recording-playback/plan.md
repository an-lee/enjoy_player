# Implementation Plan: Assessment Recording Playback

**Branch**: `035-assess-recording-playback` | **Date**: 2026-08-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/035-assess-recording-playback/spec.md`

**Note**: `/speckit-clarify` was skipped; defaults locked in [research.md](./research.md) (extend `RecordingPreviewPlayer` for take/clips; Azure ticks → ms; chip select stops full-take; mutual exclusion with model pronounce).

## Summary

After pronunciation assessment, the result detail must let learners **replay their take**, follow a **karaoke-style word highlight** driven by Azure per-word timings, and on a selected word **A/B listen**: existing model pronounce plus a **clip of their recording** for that word. Implementation extends the ADR-0003-allowed `RecordingPreviewPlayer` (seek + play-until), threads `localPath` into `showAssessmentResultDialog`, and coordinates stop with `PronouncePlaybackController`.

## Technical Context

**Language/Version**: Dart 3.x / Flutter (stable channel per repo)

**Primary Dependencies**: Flutter, Riverpod, existing `RecordingPreviewPlayer` (`media_kit` preview exception), `PronouncePlaybackController` / `PronounceIconButton` (`audioplayers`), `azure_speech` assessment models, Enjoy modals, ARB l10n, `EnjoyTappable*`

**Storage**: No Drift schema changes. Uses existing `RecordingRow.localPath` + `assessmentJson` (Azure tick timings already persisted)

**Testing**: `flutter test` (ticks→ms + active-word index pure logic; preview seek/clip unit tests with fake/mock where practical; widget tests for play/clip/karaoke/disabled states + audio mutex), `flutter analyze`, `bash .github/scripts/validate_ci_gates.sh --fix`; codegen only if new `@Riverpod` APIs are introduced

**Target Platform**: Android, iOS, macOS, Windows, Linux (no web)

**Project Type**: Cross-platform Flutter desktop/mobile app

**Performance Goals**: Tap → audible local take/clip &lt;1s when file on disk (SC-006); karaoke highlight updates from position stream without jank on short practice sentences; no heavy work in `build`; no third `media_kit` `Player`

**Constraints**: Lesson media stays on `PlayerController` only; take audio stays on the existing preview player (ADR-0003); no `print()`; mutual exclusion among full take, word clip, and model pronounce on the result surface; omit/zero-duration words disable clip; chip select stops full-take (spec assumption)

**Scale/Scope**: Shadow-reading assessment result dialog/sheet + core preview player APIs + small domain helpers; docs (`shadow-reading.md`); no Worker API changes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Plan response |
|-----------|--------|---------------|
| I. Architecture | Pass | Timing helpers in `shadow_reading/domain`; preview API in `lib/core/audio`; UI stays in assessment result presentation; no feature↔feature shortcuts beyond composing pronounce + preview |
| II. Testing | Pass | Pure unit tests for tick conversion + karaoke index; preview clip/stop behavior; widget tests for controls and dismiss stop; manual quickstart for E2E sync |
| III. UX consistency | Pass | Distinct “my recording” vs model pronounce labels/tooltips; `EnjoyTappable*` / existing icon patterns; ARB strings; update `docs/features/shadow-reading.md` |
| IV. Performance | Pass | Single shared preview player; position-driven highlight; clip stop via position listener; no decode/copy of WAV for clips |
| V. Documentation | Pass | Feature doc update; contracts for preview clip + result UI + audio mutex; ADR only if preview API scope needs a new decision (otherwise cite ADR-0003) |
| Flutter Quality Gates | Pass | format + analyze + test; no web; **no new** `media_kit` `Player()` — extend existing `RecordingPreviewPlayer` |

**Post-design re-check**: Pass — contracts bound preview clip API, result UI wiring, and audio mutex only; timestamps reuse persisted Azure assessment fields; no unjustified schema or Worker changes.

## Project Structure

### Documentation (this feature)

```text
specs/035-assess-recording-playback/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── README.md
│   ├── recording-preview-clip.md
│   ├── assessment-result-playback-ui.md
│   └── assessment-audio-mutex.md
└── tasks.md             # /speckit-tasks (not this command)
```

### Source Code (repository root)

```text
lib/core/audio/
  recording_preview_player.dart          # + seek / playClip / clip end stop
  recording_preview_player_provider.dart # unchanged ownership; consumers call new APIs

lib/features/shadow_reading/
  domain/
    assessment_word_timing.dart          # ticks→ms, usable clip?, active word index
  presentation/
    assessment_result_dialog.dart        # recordingPath, full-take control, karaoke, my-clip
    recording_assessment_flow.dart       # pass row.localPath into showAssessmentResultDialog

lib/features/pronounce/
  presentation/pronounce_icon_button.dart  # optional: stop preview before model play (or result wraps)

lib/l10n/app_en.arb (+ zh / zh_CN)
docs/features/shadow-reading.md

test/features/shadow_reading/
  domain/assessment_word_timing_test.dart
  presentation/assessment_result_*_test.dart (extend or add)
test/core/audio/
  recording_preview_player_*_test.dart   # seek/clip if testable without native player
```

**Structure Decision**: Stay inside existing shadow-reading + core audio modules. Domain timing helpers are pure Dart (UI-free). No new top-level feature package; model pronounce remains in `lib/features/pronounce/`.

## Complexity Tracking

> No constitution violations requiring justification. Extending the documented ADR-0003 preview-player exception is simpler than introducing a third engine or routing takes through `PlayerController`.
