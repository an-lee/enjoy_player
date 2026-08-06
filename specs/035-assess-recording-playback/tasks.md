# Tasks: Assessment Recording Playback

**Input**: Design documents from `specs/035-assess-recording-playback/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required for changed contracts (constitution + plan). Manual E2E per [quickstart.md](./quickstart.md).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Preview player**: `lib/core/audio/recording_preview_player.dart`, `recording_preview_player_provider.dart`
- **Domain**: `lib/features/shadow_reading/domain/assessment_word_timing.dart`
- **UI / flow**: `lib/features/shadow_reading/presentation/assessment_result_dialog.dart`, `recording_assessment_flow.dart`
- **Model pronounce**: `lib/features/pronounce/` (compose / stop only)
- **Tests**: `test/core/audio/`, `test/features/shadow_reading/`
- **l10n**: `lib/l10n/app_*.arb`
- **Docs**: `docs/features/shadow-reading.md`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm touch points and scaffolding targets

- [X] T001 Confirm edit points: `RecordingPreviewPlayer` APIs in `lib/core/audio/recording_preview_player.dart`; `showAssessmentResultDialog` / `_SelectedWordPanel` / `_WordChip` in `lib/features/shadow_reading/presentation/assessment_result_dialog.dart`; path pass-through in `lib/features/shadow_reading/presentation/recording_assessment_flow.dart`; ADR-0003 preview exception in `docs/decisions/0003-player-core-media-kit.md`
- [X] T002 [P] List ARB keys needed for full-take play/stop, my-clip play/stop, unavailable (missing file / no timing), and tooltips distinct from model pronounce in `lib/l10n/app_en.arb` (+ `app_zh.arb`, `app_zh_CN.arb`)
- [X] T003 [P] Create empty domain + test dirs if missing: `lib/features/shadow_reading/domain/`, `test/features/shadow_reading/domain/`, `test/core/audio/` per [plan.md](./plan.md)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Timing helpers, preview seek/clip APIs, dialog `recordingPath` plumbing, shared ARB — required before story UI

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 [P] Implement `azureTicksToMs`, `isWordClipUsable`, and `activeWordIndex` in `lib/features/shadow_reading/domain/assessment_word_timing.dart` per [data-model.md](./data-model.md) and [research.md](./research.md) (ticks `/10000`; omission / zero duration unusable)
- [X] T005 [P] Unit test timing helpers (1s = `10000000` ticks → 1000 ms; omission/zero duration; karaoke index gaps) in `test/features/shadow_reading/domain/assessment_word_timing_test.dart`
- [X] T006 Add `seek(Duration)` and `playClip(String path, Duration start, Duration end)` (open/seek/play until `position >= end` then stop; cancel prior clip watcher) to `lib/core/audio/recording_preview_player.dart` per [contracts/recording-preview-clip.md](./contracts/recording-preview-clip.md); keep single existing `media_kit` player; use `logNamed`, never a second `Player()`
- [X] T007 [P] Add unit/fake-friendly tests for clip end-stop and invalid `end <= start` / missing file behavior in `test/core/audio/recording_preview_player_clip_test.dart` (mock player internals or extract testable clip scheduler if native media_kit is impractical in CI)
- [X] T008 [P] Add ARB strings for assessment take/clip play-stop and unavailable states to `lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_CN.arb`; run `flutter gen-l10n`
- [X] T009 Thread optional `recordingPath` through `showAssessmentResultDialog`, `AssessmentResultDialog`, and `AssessmentResultSheet` in `lib/features/shadow_reading/presentation/assessment_result_dialog.dart` without UI chrome yet (null-safe; scores still render)
- [X] T010 Pass `row.localPath` as `recordingPath` from both stored-JSON and fresh-success paths in `lib/features/shadow_reading/presentation/recording_assessment_flow.dart`

**Checkpoint**: Foundation ready — timing + preview clip APIs + path plumbing; story UI can begin

---

## Phase 3: User Story 1 - Replay the full assessment take (Priority: P1) 🎯 MVP

**Goal**: Result detail offers play/stop for the learner’s full take; dismiss stops audio; missing file disables control without blocking scores.

**Independent Test**: Open assessment result with a take on disk → tap play my recording → full take from start → tap stop / dismiss ends audio; missing path disables play ([spec.md](./spec.md) US1, [quickstart.md](./quickstart.md) §A).

### Tests for User Story 1

- [X] T011 [P] [US1] Widget test: full-take control enabled when `recordingPath` present, disabled when null/missing; play invokes preview; dispose/dismiss stops preview (and pronounce) with fakes in `test/features/shadow_reading/presentation/assessment_result_take_playback_test.dart`

### Implementation for User Story 1

- [X] T012 [US1] Add full-take play/stop control near overall score/header in `lib/features/shadow_reading/presentation/assessment_result_dialog.dart` (dialog + sheet inner layout) using `recordingPreviewPlayerProvider`; idle tap plays from start via `play(path)`; playing tap calls `stop()`; subscribe to `playing` for affordance
- [X] T013 [US1] Before starting full-take playback, call `pronouncePlaybackControllerProvider.notifier.stop()` per [contracts/assessment-audio-mutex.md](./contracts/assessment-audio-mutex.md)
- [X] T014 [US1] On dialog/sheet dispose, stop preview take playback in addition to existing pronounce stop in `assessment_result_dialog.dart`
- [X] T015 [US1] When `recordingPath` is null or file missing, disable full-take control with localized tooltip/reason; keep scores and word chips usable in `assessment_result_dialog.dart`

**Checkpoint**: US1 MVP — full take replay demoable without karaoke or word clips

---

## Phase 4: User Story 2 - Karaoke-style word highlight (Priority: P2)

**Goal**: During full-take playback, word chips highlight the current timed word; highlight clears on stop/end/chip select (chip select also stops full take).

**Independent Test**: Play full take with multi-word timings → chips advance with speech → stop clears current; mid-play chip tap stops take and clears karaoke ([spec.md](./spec.md) US2, [quickstart.md](./quickstart.md) §B).

### Tests for User Story 2

- [X] T016 [P] [US2] Unit/widget test: position updates map to `activeWordIndex` and clear when not in full-take mode in `test/features/shadow_reading/presentation/assessment_result_karaoke_test.dart` (and/or extend timing tests)

### Implementation for User Story 2

- [X] T017 [US2] While full-take playing, subscribe to preview `position` in `assessment_result_dialog.dart` and compute current word via `activeWordIndex` from `assessment_word_timing.dart`
- [X] T018 [US2] Apply karaoke “current” visual on `_WordChip` in `assessment_result_dialog.dart` (distinct from selection + score colors); clear on stop, natural end, or leaving full-take mode
- [X] T019 [US2] On chip selection change, stop full-take preview playback and clear karaoke current word in `assessment_result_dialog.dart` (spec assumption)

**Checkpoint**: US2 works on top of US1 full-take; independently verifiable with position fakes

---

## Phase 5: User Story 3 - Compare model pronunciation with my word clip (Priority: P2)

**Goal**: Selected-word detail keeps model pronounce and adds “my clip” for that word’s timed interval; mutual exclusion; unusable timings disable clip.

**Independent Test**: Select timed word → play model → play my clip (word portion only) → no overlap; omission disables clip; chip change stops prior streams ([spec.md](./spec.md) US3, [quickstart.md](./quickstart.md) §C).

### Tests for User Story 3

- [X] T020 [P] [US3] Widget test: my-clip enabled only when `isWordClipUsable` + path; playClip called with converted start/end; starting clip stops pronounce and vice versa; omission disables clip in `test/features/shadow_reading/presentation/assessment_result_word_clip_test.dart`

### Implementation for User Story 3

- [X] T021 [US3] Add “my clip” control beside existing `PronounceIconButton` in `_SelectedWordPanel` in `lib/features/shadow_reading/presentation/assessment_result_dialog.dart` with distinct localized tooltip/a11y labels per [contracts/assessment-result-playback-ui.md](./contracts/assessment-result-playback-ui.md)
- [X] T022 [US3] Wire my-clip to `playClip(recordingPath, start, end)` using `azureTicksToMs` / word offset+duration; disable when path missing or `!isWordClipUsable` in `assessment_result_dialog.dart`
- [X] T023 [US3] Enforce mutex: before my-clip / full-take → stop pronounce; before model pronounce from this panel → stop preview (wrap tap or stop in panel) per [contracts/assessment-audio-mutex.md](./contracts/assessment-audio-mutex.md)
- [X] T024 [US3] On chip change, stop any in-progress word clip (and existing pronounce stop); retarget clip controls to the new word in `assessment_result_dialog.dart`

**Checkpoint**: All three stories independently functional; A/B listen complete

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Docs, gates, manual validation across stories

- [X] T025 [P] Update pronunciation assessment section in `docs/features/shadow-reading.md` (full-take replay, karaoke highlight, my-clip vs model pronounce; cite ADR-0003 preview player)
- [X] T026 [P] Confirm takes-toolbar preview still works with shared `recordingPreviewPlayerProvider` after seek/clip changes; fix regressions in shadow panel call sites if needed (`lib/features/shadow_reading/presentation/shadow_reading_panel.dart` or takes toolbar)
- [X] T027 Run manual scenarios A–D from [quickstart.md](./quickstart.md) and fix gaps (timing sanity: 10 000 000 ticks = 1s)
- [X] T028 Run `bash .github/scripts/validate_ci_gates.sh --fix` (format, codegen drift if any, analyze, tests) and fix until green

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — **BLOCKS** all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational — MVP
- **User Story 2 (Phase 4)**: Depends on Foundational + US1 full-take playing mode (karaoke rides full-take)
- **User Story 3 (Phase 5)**: Depends on Foundational; needs `playClip` + selected-word panel; can proceed in parallel with US2 after US1 if staffed carefully (shared `assessment_result_dialog.dart` → prefer sequential US1 → US2 → US3 on one owner)
- **Polish (Phase 6)**: Depends on desired stories complete

### User Story Dependencies

- **US1 (P1)**: After Foundational only — no dependency on karaoke/clip
- **US2 (P2)**: Needs US1 full-take play path for karaoke position stream
- **US3 (P2)**: Needs Foundational `playClip` + path; model pronounce already exists; mutex integrates with US1 stop rules

### Within Each User Story

- Tests marked first SHOULD fail before implementation where practical
- Domain/helpers before UI wiring
- Story complete before next priority when one developer owns `assessment_result_dialog.dart`

### Parallel Opportunities

- T002/T003 after T001; T004/T005 and T008 in parallel during Foundational
- T006 then T007; T009 then T010
- T011 can be sketched alongside T012–T015
- T016 parallel with early US2 work; T020 parallel with early US3 work
- T025/T026 in polish can run in parallel
- **Caution**: US2 and US3 both edit `assessment_result_dialog.dart` — serialize UI tasks or split carefully

---

## Parallel Example: Foundational

```bash
# After T001–T003:
Task: "Implement assessment_word_timing.dart"
Task: "Unit test assessment_word_timing_test.dart"
Task: "Add ARB strings + flutter gen-l10n"

# Then preview APIs:
Task: "Add seek/playClip to recording_preview_player.dart"
Task: "recording_preview_player_clip_test.dart"
```

## Parallel Example: User Story 1

```bash
Task: "Widget test assessment_result_take_playback_test.dart"
# Then implementation T012–T015 on assessment_result_dialog.dart (single owner)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Quickstart §A + T011
5. Demo full-take replay

### Incremental Delivery

1. Setup + Foundational → foundation ready
2. US1 → full take MVP
3. US2 → karaoke listen-along
4. US3 → my-clip vs model A/B
5. Polish → docs + CI gates

### Parallel Team Strategy

- Shared Foundational first
- One owner for `assessment_result_dialog.dart` (US1→US2→US3)
- Second owner: domain tests, preview player clip API/tests, ARB, docs

---

## Notes

- [P] = different files, no incomplete-task dependencies
- Do **not** construct a new `media_kit` `Player` — extend `RecordingPreviewPlayer` only
- Never use `print()`; use `logNamed`
- Azure timings are ticks, not ms — convert before `Duration`
- Commit after each task or logical group
- Avoid seek-by-chip during karaoke (out of scope)
