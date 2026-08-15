# Tasks: Alignment Engine

**Input**: Design documents from `specs/037-alignment-engine/`

**Note**: Slice 2 of issue #540. Path package `packages/forced_alignment` is PCM-in / timings-out and **unused** by Craft, transcript panel, player, ASR, and Settings. See [plan.md](./plan.md), [research.md](./research.md), [ADR-0071](../../docs/decisions/0071-on-device-alignment-engine.md) (written in polish).

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required for changed contracts (constitution + plan + spec independent tests). Manual product-unchanged check per [quickstart.md](./quickstart.md) §A. eSpeak goldens **skip** when FFI is missing.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Package**: `packages/forced_alignment/`
- **Barrel**: `packages/forced_alignment/lib/forced_alignment.dart`
- **Engine**: `packages/forced_alignment/lib/src/alignment_service.dart`
- **App pin tests**: `test/features/alignment/`
- **Allowlist**: `.github/scripts/check_no_new_path_deps.sh`, `docs/decisions/0029-supply-chain-risk.md`
- **Docs**: `docs/decisions/0071-on-device-alignment-engine.md`, `docs/features/transcript.md`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: First-party path package + CI allowlist so later tasks can compile and CI cannot fail `check_no_new_path_deps`

- [X] T001 Create `packages/forced_alignment/` skeleton: `pubspec.yaml` (`publish_to: none`, SDK `^3.12.0`, deps `logging`, `espeak`, `mcfcc_nsn`, `ffi`; `flutter_lints` + `flutter_test`), `analysis_options.yaml`, `README.md`, `.gitignore`, empty barrel `packages/forced_alignment/lib/forced_alignment.dart`, and `lib/src/` + `test/` dirs per [plan.md](./plan.md)
- [X] T002 Add `forced_alignment: path: packages/forced_alignment` to root `pubspec.yaml` (same pattern as `azure_speech`)
- [X] T003 [P] Add `packages/forced_alignment` to `ALLOWLIST` in `.github/scripts/check_no_new_path_deps.sh`
- [X] T004 [P] Add the `packages/forced_alignment` row to the local-path table in `docs/decisions/0029-supply-chain-risk.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Public types, failure reasons, language map, isolate helper, and stub `align` / `alignSegments` so stories can fill success and failure paths without inventing a second API

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 [P] Add `TimelineEntry`, `AlignmentGranularity` (`low` / `medium` / `high`), and `AlignmentResult` in `packages/forced_alignment/lib/src/types.dart` per [data-model.md](./data-model.md)
- [X] T006 [P] Add `AlignmentFailureReason` and `AlignmentFailure` in `packages/forced_alignment/lib/src/failures.dart` per [contracts/alignment-failures.md](./contracts/alignment-failures.md)
- [X] T007 [P] Add `AlignmentRequest`, `AlignmentSegment`, and `AlignmentCancelToken` in `packages/forced_alignment/lib/src/request.dart` per [data-model.md](./data-model.md)
- [X] T008 [P] Add sealed `AlignmentOutcome` (`success` + `AlignmentResult` | `failure` + `AlignmentFailure`) in `packages/forced_alignment/lib/src/outcome.dart`
- [X] T009 [P] Map v1 focus tags (`en-US`, `en-GB`, `ja-JP`, `ko-KR`, `es-ES`, `es-MX`, `fr-FR`, `fr-CA`) to eSpeak voice ids in `packages/forced_alignment/lib/src/language_map.dart` (do **not** import `package:enjoy_player/...`; unknown tag → `unsupportedLanguage`)
- [X] T010 Add `Isolate.run` helper + `Logger('forced_alignment')` (never `print`) in `packages/forced_alignment/lib/src/alignment_isolate.dart` following `lib/features/shadow_reading/application/echo_region_pitch_analyzer.dart`
- [X] T011 Export stub `align` / `alignSegments` from `packages/forced_alignment/lib/src/alignment_service.dart` via `packages/forced_alignment/lib/forced_alignment.dart` (return typed `AlignmentOutcome`; no FFmpeg, Drift, widgets, or `TranscriptLine` imports)

**Checkpoint**: Package analyzes; public API exists; stubs may return `internal` until story phases land

---

## Phase 3: User Story 1 - Existing library and Craft behavior is unchanged (Priority: P1) 🎯 MVP

**Goal**: The engine exists as a package but **no product flow calls it**. Learners see the same lines, times, Craft saves, and Settings as before.

**Independent Test**: Same curated library set as slice 1 (import, YouTube captions, speech-to-text, Craft). Line text/order/times and interactions match pre-feature. Craft save still line-only. No Settings row for timeline enrichment ([spec.md](./spec.md) US1, [contracts/inert-product.md](./contracts/inert-product.md), [quickstart.md](./quickstart.md) §A).

### Tests for User Story 1

> Write these tests FIRST, ensure they FAIL before implementation if a forbidden import already exists

- [X] T012 [US1] Add `test/features/alignment/forced_alignment_inert_import_test.dart`: fail if `lib/features/craft/`, `lib/features/transcript/`, `lib/features/player/`, `lib/features/asr/`, `lib/features/lookup/`, or Settings/l10n sources import `package:forced_alignment/` per [contracts/inert-product.md](./contracts/inert-product.md)

### Implementation for User Story 1

- [X] T013 [P] [US1] Confirm no `transcript.timelineEnrichment` (or any new enrichment Settings key) in `lib/features/settings/` and `lib/l10n/`
- [X] T014 [P] [US1] Confirm no `package:forced_alignment/` imports under `lib/features/craft/`, `lib/features/transcript/`, `lib/features/player/`, `lib/features/asr/`, `lib/features/lookup/`
- [X] T015 [US1] Run existing line-only / Craft regression: `flutter test test/data/subtitle/transcript_line_test.dart test/features/transcript/transcript_repository_test.dart test/features/transcript/transcript_lines_provider_dedupe_test.dart test/features/transcript/auto_translate_controller_test.dart test/features/craft/`

**Checkpoint**: US1 MVP — package may be in `pubspec.yaml` but product behavior is unchanged; safe no-UI merge **does not** yet satisfy slice 2 (continue US2+)

---

## Phase 4: User Story 2 - Known text and extractable audio can be aligned (Priority: P1)

**Goal**: Whole-clip `align` maps known text + 16 kHz mono Float32 PCM + language to ordered word timings on the source audio; default (`medium`) also returns phones with parent-word association. Caller transcript string is not rewritten. Flatten adapter yields enjoy-web `WordTiming` / `PhoneTiming`.

**Independent Test**: Short known clip (≥2 words) in English: 100% expected words in order; word starts within **50 ms** of the engine’s own reference; at least one word has phones; every phone `wordIndex` exists ([spec.md](./spec.md) US2, SC-003/SC-004, [contracts/align-api.md](./contracts/align-api.md), [contracts/flatten-to-web-timings.md](./contracts/flatten-to-web-timings.md)).

### Tests for User Story 2

> Write these tests FIRST, ensure they FAIL before implementation

- [X] T016 [P] [US2] Add flatten tests in `packages/forced_alignment/test/flatten_test.dart`: word order; phone `wordIndex` in range; `low` omits phones; phones without a parent word dropped; times in seconds per [contracts/flatten-to-web-timings.md](./contracts/flatten-to-web-timings.md)
- [X] T017 [P] [US2] Add windowed-DTW tests in `packages/forced_alignment/test/dtw_test.dart`: synthetic MFCC matrices produce a known warp path (always run in CI; no native FFI)
- [X] T018 [US2] Add whole-clip tests in `packages/forced_alignment/test/align_test.dart`: words in transcript order; `medium` has phones; result `transcript` equals request text; `low` has no phones; duration `< 1.0` s → `tooShort`
- [X] T019 [P] [US2] Add skippable eSpeak golden in `packages/forced_alignment/test/espeak_golden_test.dart`: `"hello world"` / `en-US` / `medium`, word starts ±50 ms; `skip` with reason if FFI missing
- [X] T020 [P] [US2] Add catalog pin in `test/features/alignment/forced_alignment_language_catalog_test.dart`: package-supported tags equal `kSupportedFocusLanguageTags` in `lib/core/application/app_language_catalog.dart`

### Implementation for User Story 2

- [X] T021 [P] [US2] Add enjoy-web `WordTiming` / `PhoneTiming` in `packages/forced_alignment/lib/src/web_timings.dart` (`startTime`/`endTime` seconds; phone `phone`/`text`/`wordIndex`)
- [X] T022 [US2] Implement `flattenToWordPhoneTimings` in `packages/forced_alignment/lib/src/flatten.dart` and export it from `packages/forced_alignment/lib/forced_alignment.dart`
- [X] T023 [P] [US2] Wrap `mcfcc_nsn` with Echogarden hop/window/coef presets (`low` / `medium` / `high`) in `packages/forced_alignment/lib/src/mfcc/mfcc_extractor.dart`
- [X] T024 [P] [US2] Implement windowed DTW + path mapping in `packages/forced_alignment/lib/src/dtw/windowed_dtw.dart`
- [X] T025 [US2] Wrap/extend eSpeak-NG FFI (PCM + phone events) in `packages/forced_alignment/lib/src/synth/espeak_reference.dart`; keep the wrapper inside this package (no second path package)
- [X] T026 [US2] Implement whole-clip `align` in `packages/forced_alignment/lib/src/alignment_service.dart`: validate PCM/text/language/caps, run DSP via T010 isolate, default granularity `medium`, do not rewrite `transcript`
- [X] T027 [US2] Wire granularity in `packages/forced_alignment/lib/src/alignment_service.dart` + `packages/forced_alignment/lib/src/mfcc/mfcc_extractor.dart`: `low` = words only; `medium`/`high` = words + phones (`high` finer hop)

**Checkpoint**: US2 — `align` returns a mappable Echogarden-shaped result; flatten is testable without Drift; US1 inert pins still pass

---

## Phase 5: User Story 3 - Existing cue windows align locally (Priority: P1)

**Goal**: `alignSegments` aligns each cue from its own PCM slice and offsets times onto the source timeline. Word times stay inside the cue window ±50 ms pad. Whole-clip `align` of audio **>90 s** is refused; multi-minute PCM is valid for `alignSegments`. Caller cue line start/end are not mutated.

**Independent Test**: ≥2 cue windows on a short clip → words per cue inside window ±50 ms; 0 cues have line start/duration rewritten; `align` on multi-minute PCM → `wholeClipTooLong`; `alignSegments` on that PCM still runs ([spec.md](./spec.md) US3, SC-005/SC-006, [contracts/align-api.md](./contracts/align-api.md)).

### Tests for User Story 3

> Write these tests FIRST, ensure they FAIL before implementation

- [X] T028 [US3] Add `packages/forced_alignment/test/align_segments_test.dart`: two windows get local word times offset by `startTime`; times in `[startTime - 0.050, endTime + 0.050]`; input `AlignmentSegment` start/end unchanged; window `< 1.0` s skipped while siblings succeed; every cue `tooShort` → typed failure not empty success; PCM `> 90` s is valid for `alignSegments`

### Implementation for User Story 3

- [X] T029 [US3] Implement `alignSegments` in `packages/forced_alignment/lib/src/alignment_service.dart`: slice at `startSample = startTime * 16000`, align fragment, add cue `startTime` to child times; omit failed cues; if none succeed return the typed failure
- [X] T030 [US3] Enforce whole-clip cap in `packages/forced_alignment/lib/src/alignment_service.dart`: `align` with duration `> 90` s → `wholeClipTooLong`; add that case to `packages/forced_alignment/test/align_test.dart` (do **not** auto-convert to `alignSegments`)
- [X] T031 [US3] Apply per-cue timeout **30 s** (vs whole-clip **2 min**) in `packages/forced_alignment/lib/src/alignment_service.dart` / `packages/forced_alignment/lib/src/alignment_isolate.dart`

**Checkpoint**: US3 — per-cue jobs work; unbounded whole-file fine-quality alignment cannot run

---

## Phase 6: User Story 4 - Alignment can fail or be cancelled without harm (Priority: P1)

**Goal**: Each expected problem is a typed `AlignmentFailure`. Failures are not empty-success results, do not write `transcripts` rows, and do not crash the app. Cancel and timeout stop work.

**Independent Test**: Drive `audioUnavailable`, `tooShort` (already US2), `blankText`, `unsupportedLanguage`, `cancelled`, `timedOut`, `internal`; 100% typed failures; 0 crashes; 0 transcript-row writes ([spec.md](./spec.md) US4, SC-007/SC-008, [contracts/alignment-failures.md](./contracts/alignment-failures.md)).

### Tests for User Story 4

> Write these tests FIRST, ensure they FAIL before implementation

- [X] T032 [P] [US4] Add `packages/forced_alignment/test/failures_test.dart`: `blankText`, `unsupportedLanguage`, null/empty PCM → `audioUnavailable` or `tooShort` as specified; `unsupportedLanguage` does not fall back to `en-US`; failure is not `AlignmentResult(wordTimeline: [])`
- [X] T033 [P] [US4] Add `packages/forced_alignment/test/cancel_timeout_test.dart`: cancel an in-flight `align` on a long synthetic buffer → `cancelled` without hanging; timeout → `timedOut`
- [X] T034 [P] [US4] Add `test/features/alignment/alignment_no_transcript_writes_test.dart`: `packages/forced_alignment` sources must not import Drift / `app_database` / `transcript_repository`

### Implementation for User Story 4

- [X] T035 [US4] Implement remaining request validation in `packages/forced_alignment/lib/src/alignment_service.dart`: `blankText`, `unsupportedLanguage` (via T009), `audioUnavailable` for missing PCM; never silent language swap
- [X] T036 [US4] Implement cancel + wall-clock timeout in `packages/forced_alignment/lib/src/alignment_service.dart` and `packages/forced_alignment/lib/src/alignment_isolate.dart` (defaults 2 min whole-clip / 30 s per cue from T031); cancelled work must not block a later call
- [X] T037 [US4] Map synth/DTW/FFI errors to `internal` in `packages/forced_alignment/lib/src/alignment_service.dart`; log via `Logger('forced_alignment')` with no PII dump and no `print()`

**Checkpoint**: US4 — every failure class is reproducible; product still has no caller (US1 pins remain green)

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: ADR, feature-doc note, package README, and CI gates for the whole slice

- [X] T038 [P] Write ADR-0071 (path package, Echogarden result interface, PCM-in, isolate, eSpeak-NG GPL into AGPL, YouTube/user-recording exclusion, unused by product) in `docs/decisions/0071-on-device-alignment-engine.md`
- [X] T039 Index ADR-0071 in `docs/decisions/README.md`
- [X] T040 [P] Add an “Alignment engine (unused)” note to `docs/features/transcript.md` (no Settings toggle; no panel chrome; mapping to nested cues is slice 3)
- [X] T041 [P] Document `align` / `alignSegments` / flatten / skippable goldens in `packages/forced_alignment/README.md`
- [X] T042 Run `flutter test packages/forced_alignment/test`, `flutter test test/features/alignment`, `flutter analyze`, and `bash .github/scripts/validate_ci_gates.sh --fix` per [quickstart.md](./quickstart.md); fix until green

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (package name must exist for the inert-import pin)
- **User Story 2 (Phase 4)**: Depends on Foundational — whole-clip success path; independent of US3/US4 except shared `alignment_service.dart`
- **User Story 3 (Phase 5)**: Depends on US2 `align` internals (T026) so segments reuse the same DSP
- **User Story 4 (Phase 6)**: Depends on Foundational; validation/cancel can land in parallel with US2 if they touch disjoint helpers, but `alignment_service.dart` is a hotspot
- **Polish (Phase 7)**: Depends on US1–US4

### User Story Dependencies

- **User Story 1 (P1)**: After Phase 2 — no dependency on US2–US4. This is the **safety MVP** (no learner change).
- **User Story 2 (P1)**: After Phase 2 — delivers the actual capability. Slice 2 is incomplete without it.
- **User Story 3 (P1)**: After US2 T026 (`align` DSP must exist to slice)
- **User Story 4 (P1)**: After Phase 2; T035–T037 should follow T011; cancel tests need T010. `tooShort` is covered in US2; `wholeClipTooLong` in US3.

`packages/forced_alignment/lib/src/alignment_service.dart` is the hotspot — do not parallel T011/T026/T027/T029/T030/T035/T036/T037.

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Types (Phase 2) before DSP
- Flatten and DTW math before `align`
- `align` before `alignSegments`
- Story complete before moving on when sharing `alignment_service.dart`

### Parallel Opportunities

- T003 and T004 after T001 (allowlist script vs ADR-0029)
- T005–T009 (five different source files)
- T013 and T014 (confirm-only, different trees) after T012
- T016, T017, T019, T020, T021 (different test/source files) after Phase 2
- T023 and T024 after T017 exists
- T032, T033, T034 (three test files) after Phase 2
- T038 and T040 (different docs) after stories land; T039 after T038

---

## Parallel Example: User Story 2

```bash
# After Phase 2 types exist, launch US2 tests / models in parallel:
Task: "Flatten tests in packages/forced_alignment/test/flatten_test.dart"
Task: "DTW tests in packages/forced_alignment/test/dtw_test.dart"
Task: "WordTiming/PhoneTiming in packages/forced_alignment/lib/src/web_timings.dart"
Task: "Language catalog pin in test/features/alignment/forced_alignment_language_catalog_test.dart"
```

---

## Parallel Example: User Story 4

```bash
# After Phase 2, launch US4 contract tests in parallel:
Task: "Failure-enum tests in packages/forced_alignment/test/failures_test.dart"
Task: "Cancel/timeout tests in packages/forced_alignment/test/cancel_timeout_test.dart"
Task: "No Drift imports in test/features/alignment/alignment_no_transcript_writes_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: inert-import test + existing Craft/transcript tests green
5. This MVP is safe to merge as a no-behavior-change **but does not ship the engine** — continue US2–US4 before calling slice 2 done

### Incremental Delivery

1. Setup + Foundational → package + stub API + allowlist
2. US1 → product cannot regress → demo/merge-safe
3. US2 → whole-clip `align` + flatten → capability exists
4. US3 → `alignSegments` + 90 s whole-clip cap → long media path
5. US4 → typed failures / cancel / timeout → slice 3 can rely on fallback
6. Polish → ADR-0071 + transcript note + CI gates

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. One developer owns `alignment_service.dart` (US2 then US3 then US4 wiring)
3. Meanwhile another can land US1 pins, flatten/DTW tests, and T038/T040 docs
4. eSpeak FFI (T025) can proceed beside DTW math (T024) until T026 integrates them

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to spec user stories US1–US4
- Do not add Settings, karaoke, IPA overlay, Craft pipeline wiring, YouTube demux, or `lib/features/alignment` production code
- Do not import `TranscriptLine` into the package
- Do not create a Drift migration or write `timeline_json`
- Verify tests fail before implementing DSP / flatten / isolate cancel
- Commit after each task or logical group (setup, US1, US2, US3, US4, polish)
- Avoid: `print()`, new `media_kit` `Player()`, Flutter web, bit-exact timestamp claims, second path package for eSpeak
