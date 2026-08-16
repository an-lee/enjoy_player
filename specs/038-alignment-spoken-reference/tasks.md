# Tasks: Spoken Alignment Reference

**Input**: Design documents from `specs/038-alignment-spoken-reference/`

**Note**: Slice 2b of issue #540. Upgrades unused `packages/forced_alignment` so production success requires a **spoken** eSpeak-NG reference (not duration-model tones). Product flows still must not call the engine. See [plan.md](./plan.md), [research.md](./research.md). ADR-0072 is written in polish.

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required for changed contracts (constitution + plan + spec independent tests). Manual product-unchanged check per [quickstart.md](./quickstart.md) §A. Real-voice goldens **skip** when FFI/data is missing; fail-closed tests **always** run.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Package**: `packages/forced_alignment/`
- **Barrel**: `packages/forced_alignment/lib/forced_alignment.dart`
- **Engine**: `packages/forced_alignment/lib/src/alignment_service.dart`
- **Synth**: `packages/forced_alignment/lib/src/synth/`
- **Native**: `packages/forced_alignment/native/`
- **App pin tests**: `test/features/alignment/`
- **Docs**: `docs/decisions/0072-spoken-alignment-reference.md`, `docs/features/transcript.md`, `docs/packaging.md`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Feature branch and native-artifact layout so later FFI work has a home without a second path package

- [X] T001 Create git branch `038-alignment-spoken-reference` from current `main` (package `packages/forced_alignment` already exists from slice 2)
- [X] T002 [P] Add `packages/forced_alignment/native/<os>/` placeholders (android, ios, macos, windows, linux), `packages/forced_alignment/native/espeak-ng-data/`, and `packages/forced_alignment/native/README.md` describing vendored `libespeak-ng` + trimmed focus-voice data (lazy load; do not compile on every `flutter test`)
- [X] T003 [P] Update `packages/forced_alignment/pubspec.yaml` description to require a spoken reference; add `ffi` only if bindings need `package:ffi` (prefer `dart:ffi`). Do **not** add pub.dev `espeak`. Do **not** add a new path package

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Synthesizer seam, new failure reason, and fail-closed production default so stories can fill eSpeak success and unavailable paths without a second API

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 [P] Add `AlignmentFailureReason.spokenReferenceUnavailable` in `packages/forced_alignment/lib/src/failures.dart` per [contracts/alignment-failures.md](./contracts/alignment-failures.md)
- [X] T005 [P] Extract `SpokenReferenceSynthesizer`, `ReferenceAudio`, `ReferenceWord`, and `ReferencePhone` into `packages/forced_alignment/lib/src/synth/spoken_reference.dart` per [data-model.md](./data-model.md) and [contracts/spoken-reference.md](./contracts/spoken-reference.md) (`synthesize(text, language)` only — no source-clip stretch argument)
- [X] T006 [P] Add linear resample (native rate → 16 kHz mono Float32) in `packages/forced_alignment/lib/src/synth/resample.dart`
- [X] T007 Thread an optional `@visibleForTesting SpokenReferenceSynthesizer` through `packages/forced_alignment/lib/src/alignment_service.dart`, `packages/forced_alignment/lib/src/alignment_isolate.dart` (`AlignIsolateJob`), and `packages/forced_alignment/lib/src/alignment_pipeline.dart`; omitted → production synthesizer
- [X] T008 Make the production default an `EspeakNgSynthesizer` stub in `packages/forced_alignment/lib/src/synth/espeak_ng_synthesizer.dart` that cannot load yet and surfaces `spokenReferenceUnavailable`. Move `DurationModelSynthesizer` out of the production path into `packages/forced_alignment/test/helpers/duration_model_synthesizer.dart` (or `@visibleForTesting` only). Delete letter-split G2P from production `packages/forced_alignment/lib/src/synth/espeak_reference.dart`
- [X] T009 Retarget existing slice 2 tests that currently call `DurationModelSynthesizer` then `align` without a double — `packages/forced_alignment/test/align_test.dart`, `packages/forced_alignment/test/align_segments_test.dart`, `packages/forced_alignment/test/pipeline_sync_test.dart`, `packages/forced_alignment/test/espeak_golden_test.dart` — to inject an explicit test `SpokenReferenceSynthesizer` so DTW/caps stay green while the omitted-parameter path is fail-closed

**Checkpoint**: Package analyzes; production `align()` without a double returns `spokenReferenceUnavailable`; injected-double tests still cover DTW/flatten/caps

---

## Phase 3: User Story 1 - Existing library and Craft behavior is unchanged (Priority: P1) 🎯 MVP

**Goal**: The spoken-reference upgrade stays inside the unused package. Learners see the same lines, times, Craft saves, Settings, and **playback audio** as before.

**Independent Test**: Same curated library set as slices 1–2 (import, YouTube captions, speech-to-text, Craft). Line text/order/times and interactions match pre-feature. Craft save still line-only. No Settings row for enrichment or “reference voice”. Playback is existing media, not a synthetic reference ([spec.md](./spec.md) US1, [contracts/inert-product.md](./contracts/inert-product.md), [quickstart.md](./quickstart.md) §A).

### Tests for User Story 1

> Write these tests FIRST, ensure they FAIL before implementation if a forbidden import or Settings key already exists

- [X] T010 [US1] Keep and extend `test/features/alignment/forced_alignment_inert_import_test.dart`: fail if `lib/features/craft/`, `lib/features/transcript/`, `lib/features/player/`, `lib/features/asr/`, `lib/features/lookup/`, or Settings/l10n sources import `package:forced_alignment/` per [contracts/inert-product.md](./contracts/inert-product.md)

### Implementation for User Story 1

- [X] T011 [P] [US1] Confirm no `transcript.timelineEnrichment` and no “reference voice” Settings/ARB strings in `lib/features/settings/` and `lib/l10n/`; confirm no new `media_kit` `Player()` and no playback of reference PCM
- [X] T012 [US1] Run existing line-only / Craft regression: `flutter test test/data/subtitle/transcript_line_test.dart test/features/transcript/transcript_repository_test.dart test/features/transcript/transcript_lines_provider_dedupe_test.dart test/features/transcript/auto_translate_controller_test.dart test/features/craft/`

**Checkpoint**: US1 MVP — product behavior unchanged; safe no-UI merge **does not** yet satisfy slice 2b (continue US2+)

---

## Phase 4: User Story 2 - Alignment compares the clip to a spoken rendering (Priority: P1)

**Goal**: Whole-clip `align` builds a same-language spoken `ReferenceAudio` (eSpeak-NG waveform + word/phone events), compares it to source PCM via existing MFCC + windowed DTW, and returns source-timeline words (and default-quality phones that are pronunciation units, not letter-splits). Reference duration MAY differ from the clip. Caller transcript string is not rewritten.

**Independent Test**: Short **spoken** English fixture (≥2 words): 100% expected words in order; each start within **50 ms** of **that run’s** spoken-reference word events; at least one word has phones; phones are not a letter-split of “hello” ([spec.md](./spec.md) US2, SC-003/SC-004, [contracts/align-api.md](./contracts/align-api.md), [contracts/spoken-reference.md](./contracts/spoken-reference.md)).

### Tests for User Story 2

> Write these tests FIRST, ensure they FAIL before implementation

- [X] T013 [P] [US2] Rewrite `packages/forced_alignment/test/espeak_golden_test.dart`: real production synthesizer only; `"hello world"` / `en-US` / `medium`; word starts ±50 ms vs **that run’s** reference word events; phones not `h,e,l,l,o`; `skip` with reason if FFI/data missing — do **not** pass by feeding duration-model tones labeled as eSpeak
- [X] T014 [P] [US2] Add unequal-length remap coverage in `packages/forced_alignment/test/pipeline_sync_test.dart` (or `packages/forced_alignment/test/spoken_reference_pipeline_test.dart`): injected spoken double whose PCM duration ≠ source duration still returns times on the **source** timeline; `transcript` unchanged
- [X] T015 [P] [US2] Add always-on injected-double helper `packages/forced_alignment/test/helpers/fake_spoken_synthesizer.dart` that emits speech-like or tone PCM **plus IPA phones** (not letter-split) for DTW tests that must run without native FFI

### Implementation for User Story 2

- [X] T016 [P] [US2] Add eSpeak-NG `dart:ffi` bindings (`espeak_Initialize`, `espeak_SetVoiceByName`, `espeak_SetSynthCallback`, `espeak_Synth`, `espeak_EVENT`) in `packages/forced_alignment/lib/src/synth/espeak_ng_bindings.dart` per [contracts/spoken-reference.md](./contracts/spoken-reference.md)
- [X] T017 [US2] Implement `EspeakNgSynthesizer.synthesize` in `packages/forced_alignment/lib/src/synth/espeak_ng_synthesizer.dart`: `AUDIO_OUTPUT_SYNCHRONOUS`, `PHONEME_EVENTS | PHONEME_IPA`, voice from `packages/forced_alignment/lib/src/language_map.dart`, collect int16 PCM + WORD/PHONEME events (`audio_position`, `text_position`), resample via T006
- [X] T018 [US2] Change `runAlignPipeline` in `packages/forced_alignment/lib/src/alignment_pipeline.dart` to consume spoken `ReferenceAudio` **without** stretching it to the source duration; remap events onto the source timeline; keep `low` = words only
- [X] T019 [US2] Initialize eSpeak once per alignment isolate in `packages/forced_alignment/lib/src/alignment_isolate.dart`; do not call `espeak_Synth` on the UI isolate; lazy `DynamicLibrary.open` from `packages/forced_alignment/native/`
- [X] T020 [US2] Vendor at least the current-dev OS `libespeak-ng` plus trimmed `espeak-ng-data` for focus voices under `packages/forced_alignment/native/` (other OS binaries may land in the same PR or follow immediately). If a runner has no binary, goldens skip; production `align` stays fail-closed

**Checkpoint**: US2 — production `align` with a loaded voice returns a spoken-reference timeline; flatten still maps to enjoy-web timings; US1 inert pins still pass

---

## Phase 5: User Story 3 - Missing spoken reference fails; it does not silently succeed (Priority: P1)

**Goal**: Mapped language + missing lib/data/voice → distinct `spokenReferenceUnavailable`. Unmapped language → `unsupportedLanguage`. Never a successful word list from duration-model tones or letter-split phones. Never a silent language swap.

**Independent Test**: Disable the spoken voice in a harness; unmapped language. 100% typed failures; 0 empty-success disguises; 0 transcript-row writes ([spec.md](./spec.md) US3, SC-005, [contracts/alignment-failures.md](./contracts/alignment-failures.md)).

### Tests for User Story 3

> Write these tests FIRST, ensure they FAIL before implementation

- [X] T021 [P] [US3] Add `packages/forced_alignment/test/spoken_reference_unavailable_test.dart`: omitted synthesizer with FFI forced off **and** an injected unavailable synthesizer → `spokenReferenceUnavailable`; not `internal` only; not `AlignmentResult(wordTimeline: [])`; 0 duration-model successes
- [X] T022 [P] [US3] Extend `packages/forced_alignment/test/failures_test.dart`: unmapped language still `unsupportedLanguage` (no `en-US` fallback); assert production factory is not `DurationModelSynthesizer`

### Implementation for User Story 3

- [X] T023 [US3] Map initialize / `SetVoiceByName` / empty-PCM / missing native+data failures to `spokenReferenceUnavailable` in `packages/forced_alignment/lib/src/synth/espeak_ng_synthesizer.dart` and `packages/forced_alignment/lib/src/alignment_service.dart`; reserve `internal` for DTW/remap after a spoken reference existed
- [X] T024 [US3] Keep `unsupportedLanguage` before synth via `packages/forced_alignment/lib/src/language_map.dart`; never swap to another tag’s voice. Confirm `test/features/alignment/alignment_no_transcript_writes_test.dart` still forbids Drift imports

**Checkpoint**: US3 — unavailable is a typed failure on every CI runner; product still has no caller (US1 pins remain green)

---

## Phase 6: User Story 4 - Per-cue jobs and safety caps still hold (Priority: P1)

**Goal**: `alignSegments` builds a spoken reference **per cue job**, not one utterance over a multi-minute file. Whole-clip `>90 s` is refused **before** synth. Cancel/timeout abort in-flight `espeak_Synth` (callback return `1`). Slice 2 caps and blank/too-short/missing-audio failures stay.

**Independent Test**: ≥2 cue windows on a short spoken clip → words inside window ±50 ms; 0 line start/duration rewrites; `align` on multi-minute PCM → `wholeClipTooLong`; cancel/timeout typed failures ([spec.md](./spec.md) US4, SC-006/SC-007, [contracts/align-api.md](./contracts/align-api.md)).

### Tests for User Story 4

> Write these tests FIRST, ensure they FAIL before implementation

- [X] T025 [P] [US4] Extend `packages/forced_alignment/test/align_segments_test.dart`: two windows still get local words offset by `startTime` with ±50 ms pad when using a spoken (injected or real) reference per cue; input segment start/end unchanged; PCM `> 90` s valid for `alignSegments`
- [X] T026 [P] [US4] Extend `packages/forced_alignment/test/cancel_timeout_test.dart`: cancel/timeout during in-flight spoken-reference work → `cancelled` / `timedOut` without hanging; blank/too-short/missing PCM still fail **before** synth

### Implementation for User Story 4

- [X] T027 [US4] Build the spoken reference per job in `packages/forced_alignment/lib/src/alignment_service.dart` (`align` once; `alignSegments` once per cue text/window) — do not synthesize an entire multi-minute file as one utterance
- [X] T028 [US4] Abort in-flight `espeak_Synth` from the synth callback (return `1`) when the cancel token fires in `packages/forced_alignment/lib/src/synth/espeak_ng_synthesizer.dart` and `packages/forced_alignment/lib/src/alignment_isolate.dart`
- [X] T029 [US4] Keep slice 2 caps in `packages/forced_alignment/lib/src/alignment_service.dart`: `align` `> 90` s → `wholeClipTooLong` before synth; `< 1.0` s → `tooShort`; punctuation-only success with zero words skips synth

**Checkpoint**: US4 — spoken reference does not undo slice 2 cost/safety rules

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: ADR, feature-doc note, packaging/license, and CI gates for the whole slice

- [X] T030 [P] Write ADR-0072 (spoken-reference requirement, eSpeak-NG `espeak_Synth` FFI, vendored native + trimmed data, fail-closed, GPL-3.0 into AGPL, unused by product, does not rewrite ADR-0071) in `docs/decisions/0072-spoken-alignment-reference.md`
- [X] T031 Index ADR-0072 in `docs/decisions/README.md`
- [X] T032 [P] Update the unused-engine note in `docs/features/transcript.md`: production alignment requires a spoken reference; duration-model is not a production success; still no Settings / panel chrome
- [X] T033 [P] Document vendored `libespeak-ng`, trimmed `espeak-ng-data`, lazy load, and GPL note in `docs/packaging.md`
- [X] T034 [P] Update the `packages/forced_alignment` follow-up sentence in `docs/decisions/0029-supply-chain-risk.md` (eSpeak waveform wrap landing in this package)
- [X] T035 [P] Document spoken-reference contract, fail-closed behavior, skippable goldens, and native layout in `packages/forced_alignment/README.md`
- [X] T036 Run `flutter test packages/forced_alignment/test`, `flutter test test/features/alignment`, `flutter analyze`, and `bash .github/scripts/validate_ci_gates.sh --fix` per [quickstart.md](./quickstart.md); fix until green. Document SC-008 (<10 s for ≤60 s including synth) if a platform is slower

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (package + failure enum must exist for pins)
- **User Story 2 (Phase 4)**: Depends on Foundational — spoken success path; independent of US3/US4 except shared synth/service files
- **User Story 3 (Phase 5)**: Depends on Foundational fail-closed stub (T008); tighten mapping after T017 exists so real FFI errors use the right reason
- **User Story 4 (Phase 6)**: Depends on US2 pipeline (T018) so per-cue jobs reuse spoken remap
- **Polish (Phase 7)**: Depends on US1–US4

### User Story Dependencies

- **User Story 1 (P1)**: After Phase 2 — no dependency on US2–US4. This is the **safety MVP** (no learner change).
- **User Story 2 (P1)**: After Phase 2 — delivers the spoken-reference capability. Slice 2b is incomplete without it.
- **User Story 3 (P1)**: After Phase 2 T008; T023 should follow T017 so initialize/set-voice errors are not `internal`.
- **User Story 4 (P1)**: After US2 T018 (`align` DSP must consume spoken `ReferenceAudio` before per-cue reuse).

Hotspots — do not parallel writers on the same file:

- `packages/forced_alignment/lib/src/alignment_service.dart` — T007, T027, T029
- `packages/forced_alignment/lib/src/alignment_pipeline.dart` — T007, T018
- `packages/forced_alignment/lib/src/alignment_isolate.dart` — T007, T019, T028
- `packages/forced_alignment/lib/src/synth/espeak_ng_synthesizer.dart` — T008, T017, T023, T028

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Seam + failure enum (Phase 2) before eSpeak FFI
- Injected-double DTW tests before relying on native goldens
- Production `align` before per-cue spoken jobs
- Story complete before moving on when sharing the hotspot files

### Parallel Opportunities

- T002 and T003 after T001 (native layout vs pubspec)
- T004, T005, T006 (three different source files)
- T011 after T010 (confirm-only, different trees)
- T013, T014, T015, T016 (different test/source files) after Phase 2
- T021 and T022 (two test files) after Phase 2
- T025 and T026 (two test files) after T018
- T030, T032, T033, T034, T035 (different docs) after stories land; T031 after T030

---

## Parallel Example: User Story 2

```bash
# After Phase 2 seam exists, launch US2 tests / bindings in parallel:
Task: "Rewrite espeak_golden_test.dart for real-voice ±50 ms"
Task: "Unequal-length remap test in pipeline_sync_test.dart"
Task: "FakeSpoken helper in test/helpers/fake_spoken_synthesizer.dart"
Task: "eSpeak-NG dart:ffi bindings in lib/src/synth/espeak_ng_bindings.dart"
```

---

## Parallel Example: User Story 3

```bash
# After Phase 2 fail-closed stub exists:
Task: "spoken_reference_unavailable_test.dart"
Task: "failures_test.dart factory + unsupportedLanguage pin"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: inert-import test + existing Craft/transcript tests green
5. This MVP is safe to merge as a no-behavior-change **but does not ship spoken alignment** — continue US2–US4 before calling slice 2b done

### Incremental Delivery

1. Setup + Foundational → seam + fail-closed production default + injected-double tests
2. US1 → product cannot regress → demo/merge-safe
3. US2 → eSpeak `espeak_Synth` + no-stretch DTW → capability exists
4. US3 → typed unavailable / no stand-in success → slice 3 can trust fallback
5. US4 → per-cue synth + cancel/caps → slice 2 rules still hold
6. Polish → ADR-0072 + transcript/packaging notes + CI gates

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. One developer owns `alignment_service.dart` / pipeline / isolate (US2 then US4)
3. Meanwhile another can land US1 pins, US3 fail-closed tests, and T016 bindings
4. Native vendoring (T020) can proceed beside Dart FFI (T016) until T017 integrates them

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to spec user stories US1–US4
- Do not add Settings, karaoke, IPA overlay, Craft pipeline wiring, YouTube demux, or `lib/features/alignment` production code
- Do not play the spoken reference or replace Craft/library playback audio
- Do not import `TranscriptLine` into the package
- Do not create a Drift migration or write `timeline_json`
- Do not add `packages/enjoy_espeak` or depend on pub.dev `espeak` for production synth
- Do not leave `DurationModelSynthesizer` as the omitted-parameter production default
- Verify fail-closed and golden tests fail before implementing FFI / pipeline changes
- Commit after each task or logical group (setup, foundation, US1, US2, US3, US4, polish)
- Avoid: `print()`, new `media_kit` `Player()`, Flutter web, bit-exact timestamp claims, compiling eSpeak on every `flutter test`
