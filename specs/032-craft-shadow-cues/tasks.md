# Tasks: Craft Shadow-Friendly Transcript Cues

**Input**: Design documents from `/specs/032-craft-shadow-cues/`

**Prerequisites**: [plan.md](plan.md) (required), [spec.md](spec.md) (required), [research.md](research.md), [data-model.md](data-model.md), [contracts/azure-speech-word-boundaries.md](contracts/azure-speech-word-boundaries.md), [quickstart.md](quickstart.md)

**Tests**: Included — the Enjoy Player constitution (Principle II) mandates automated tests for every behavior change. The segmenter is pure Dart and fully unit-testable; the native Swift change relies on manual device verification (quickstart.md Scenario B) since the `azure_speech` plugin has no hostless native test harness.

**Organization**: Tasks are grouped by user story. US1 (Apple word-boundary capture) and US2 (shadow-friendly sizing) are the two P1 slices and are **independent of each other** — US1 touches only the native Swift plugin; US2–US4 touch only the Dart segmenter + controller. They can be developed in parallel by different people.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (e.g. US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Shared infrastructure reused across user stories.

- [X] T001 [P] Create CJK language helper `lib/core/application/cjk_language.dart` exposing a pure `bool isCjkLanguage(String languageTag)` built on `primaryLanguageSubtag(tag) ∈ {'zh','ja','ko'}` (research.md §R9.7; data-model.md §3). Stateless, no dependencies on feature code.
- [X] T002 [P] Add unit test `test/core/application/cjk_language_test.dart` covering zh-CN, zh-TW, ja-JP, ko-KR (true) and en-US, fr-FR, de-DE (false), plus edge cases (empty, aliases `zho`/`jpn`/`kor`).

**Checkpoint**: Shared helper ready for the segmentation user stories.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core segmenter configuration that US2/US3/US4 all depend on.

**⚠️ CRITICAL**: The segmentation user stories (US2, US3, US4) cannot begin until this phase is complete. US1 (native plugin) is independent and can proceed in parallel with this phase.

- [X] T003 Define `ShadowLineBudget` constants (min 1200ms, targetMin 1500ms, softMax 6000ms, hardMax 7000ms, pauseGap 250ms) and `BreakPriority` enum (sentenceEnd, clauseMark, silenceGap, hardCap) inside `lib/features/craft/domain/word_boundary_segmenter.dart` (data-model.md §2; research.md §R7). Pure declarations — no algorithm yet.

**Checkpoint**: Segmenter config types ready. US1 can proceed independently; US2–US4 unblocked.

---

## Phase 3: User Story 1 — Apple learners get timed cues on save (Priority: P1) 🎯 MVP

**Goal**: iOS and macOS Craft saves produce a timed transcript (non-blank) instead of the current blank-transcript fallback, by capturing Azure Speech SDK word-boundary events.

**Independent Test**: quickstart.md Scenario B — on an iOS or macOS device, Craft a multi-sentence paragraph with Enjoy default TTS, save, open in player; the transcript panel shows timed lines (not the empty/generate state).

**Note**: This story is **independent of US2–US4** — it only changes native Swift files; the Dart parser and segmenter are untouched. It can be developed, merged, and shipped on its own.

### Implementation for User Story 1

- [X] T004 [P] [US1] Register `synthesizer.addSynthesisWordBoundaryEventHandler` **before** `synthesizer.speakText(text)` in `packages/azure_speech/ios/Classes/AzureSpeechPlugin.swift` `performSynthesis`. In the handler, append `{"text": eventArgs.text, "audioOffset": eventArgs.audioOffset, "duration": Int(eventArgs.duration * 10_000_000)}` (convert seconds→ticks, research.md §R8 gotcha 1) into the captured `wordBoundaries` array. Do NOT emit `boundaryType` (defective enum, §R8 gotcha 2). Remove the stale comment at lines 221-226 that claims the handler is unavailable.
- [X] T005 [P] [US1] Apply the identical change to `packages/azure_speech/macos/Classes/AzureSpeechPlugin.swift` `performSynthesis` (shared Swift implementation mirrors iOS).
- [X] T006 [US1] Verify `packages/azure_speech/lib/src/method_channel_azure_speech.dart` needs **no change** — it already decodes `{"text","audioOffset","duration"}` JSON when the native response starts with `{` (research.md §R9.1). Confirm the Swift-emitted JSON parses correctly by code review against lines 109–135.

**Checkpoint**: US1 complete. Apple Craft saves now produce word boundaries → a timed transcript. Verify on device (quickstart.md Scenario B) before merging. The existing segmenter runs unchanged on these new boundaries, so Apple users immediately get cues (improved further by US2–US4 once landed).

---

## Phase 4: User Story 2 — Lines break at shadow-friendly sizes (Priority: P1) 🎯 MVP

**Goal**: Replace the fixed 6-word chunking with a duration-aware segmenter so every transcript line is a repeatable shadow phrase (1.2–7.0 s window), splitting long sentences at the best natural boundary and merging too-short fragments.

**Independent Test**: quickstart.md Scenario C — Craft a paragraph with one long multi-clause sentence and one short sentence; the long sentence splits into ≤2 lines within the shadow window while the short sentence stays whole.

**Note**: This story is **independent of US1** — it only changes Dart files. It can be developed in parallel with US1.

### Tests for User Story 2

- [X] T007 [P] [US2] Update `test/features/craft/domain/word_boundary_segmenter_test.dart`: **preserve** the locked contracts (empty→`[]`/`null`, punctuation-only→`null`, standalone punct never starts a line / merges onto prior word, sentence-end forces flush, `start`=first onset / `duration`=last release − start, wire JSON `{text,start,duration}`). Research.md §R9.3 enumerates exactly which tests are preserved vs updated.
- [X] T008 [P] [US2] Add new tests in `test/features/craft/domain/word_boundary_segmenter_test.dart`: (a) a sentence whose spoken span exceeds `softMaxMs` splits into ≥2 lines each ≤ `hardMaxMs`; (b) no standalone line is shorter than `minLineMs` (short fragments merge into a neighbor); (c) a short single sentence stays as one line; (d) when no punctuation falls inside the window, the split lands at the largest inter-word silence gap ≥ `pauseGapMs` rather than an arbitrary word count (FR-004). Use synthetic `CraftWordBoundary` lists with explicit ms timings.
- [X] T009 [US2] Replace the pure word-count-chop tests ("splits long sentences at preferred word count") with duration-driven expectations. The `preferredWordsPerSegment` parameter is removed or demoted to a last-resort tiebreaker (data-model.md §2, §3).

### Implementation for User Story 2

- [X] T010 [US2] Rewrite `segmentWordBoundaries` in `lib/features/craft/domain/word_boundary_segmenter.dart` per data-model.md §3: keep `mergePunctuationTokens` (unchanged), then partition words into sentences at sentence-end boundaries, then per sentence run `shadow-split` (accumulate while span < `softMaxMs`; on overflow pick the break candidate by `BreakPriority`: clauseMark > silenceGap > hardCap), then `mergeShortFragments` (absorb lines < `minLineMs` into a neighbor). Keep `segmentsToTimelineJson` and `buildCraftPrimaryTimelineJson` (the solid gate) unchanged.
- [X] T011 [US2] Thread `state.synthLanguage` into the single `buildCraftPrimaryTimelineJson` call-site at `lib/features/craft/application/craft_controller.dart` lines 226–230 so the segmenter receives the language for CJK detection (used by US3). Add an optional `String? language` parameter to `buildCraftPrimaryTimelineJson` / `segmentWordBoundaries`.

**Checkpoint**: US2 complete. Lines are now duration-sized. Run `flutter test test/features/craft/domain/word_boundary_segmenter_test.dart` — all green.

---

## Phase 5: User Story 3 — Clause and phrase punctuation guide breaks (Priority: P2)

**Goal**: Honor clause-level punctuation (commas, semicolons, colons, em-dashes, CJK `、，；：`) as preferred break candidates inside long sentences, and use a punctuation+duration path (never word count) for CJK text.

**Independent Test**: quickstart.md Scenario D — Craft a Chinese or Japanese paragraph with full-width comma-separated clauses; lines break at the full-width commas, not by a Latin word-count rule.

**Depends on**: US2 (the duration-aware segmenter core must exist).

### Tests for User Story 3

- [X] T012 [P] [US3] Add tests in `test/features/craft/domain/word_boundary_segmenter_test.dart`: (a) Latin text with commas/semicolons/colons/em-dashes splits at those clause marks when within the shadow window (FR-005); (b) CJK text (language `zh-CN`/`ja-JP`/`ko-KR`) with full-width clause punctuation `、，；：` breaks at those marks (FR-006); (c) CJK text joins segment text with no inter-word space (data-model.md §3); (d) a clause mark adjacent to a sentence-ending mark does not override the sentence end and no line begins with punctuation (FR-007).

### Implementation for User Story 3

- [X] T013 [US3] Extend the `clauseMark` punctuation set in `lib/features/craft/domain/word_boundary_segmenter.dart` to `,;:—、，；：` (data-model.md §2 `BreakPriority.clauseMark`). Wire it into the `shadow-split` candidate selection so clause marks are preferred break points between `sentenceEnd` and `silenceGap`.
- [X] T014 [US3] Add the CJK branch to `segmentWordBoundaries` using `isCjkLanguage(language)` (T001): when CJK, skip any word-count logic entirely, join segment text spaceless (`''`), and break only at punctuation + duration + silence gaps (FR-006; research.md §R4).

**Checkpoint**: US3 complete. Clause + CJK punctuation now guide breaks. Run the segmenter tests — green.

---

## Phase 6: User Story 4 — Timing accurately frames each phrase (Priority: P2)

**Goal**: Each line's start equals its first word's onset and its end equals its last word's release; a line's duration never artificially extends across an inter-line silence into the next line's words.

**Independent Test**: quickstart.md Scenario — Craft a paragraph; play it back; each line highlights exactly when its first word is heard and stops as the last word ends.

**Depends on**: US2 (segment construction must exist). Largely preserved from the current segmenter (the timing rule is unchanged), but US4 adds explicit verification that `mergeShortFragments` and the pause-aware splits do not introduce timing drift.

### Tests for User Story 4

- [X] T015 [P] [US4] Add/verify tests in `test/features/craft/domain/word_boundary_segmenter_test.dart`: (a) each segment's `startMs` == first boundary `audioOffsetMs` and `durationMs` == `(last.audioOffsetMs + last.durationMs) − start` (FR-008); (b) a silence gap between two lines is NOT included in the first line's duration (the first line's end stops at its last word's release); (c) after `mergeShortFragments`, the merged line's timing spans the combined first-onset → last-release without gaps.

### Implementation for User Story 4

- [X] T016 [US4] Verify the segment timing construction in `lib/features/craft/domain/word_boundary_segmenter.dart` (the `flush()` / segment-build path) computes `start` and `duration` strictly from the first and last boundary in the segment — never from sentence span or audio duration. Add an assertion or clarity comment only if the existing construction is ambiguous; no behavior change expected if US2/US3 were implemented correctly.

**Checkpoint**: US4 complete. Timing is accurate. Run the full segmenter test suite — green.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, CI gates, and final validation across all stories.

- [X] T017 [P] Update `docs/features/craft.md` "Word-segmented transcript" section: document (a) iOS/macOS now produce word boundaries (remove the "Apple platforms do not produce boundaries" note), (b) the new shadow-friendly segmentation rules (duration window, clause punctuation, CJK path), (c) BYOK OpenAI TTS and Linux remain blank+STT (constitution Principle V).
- [X] T018 Run `dart run build_runner build` — expected no-op (no Drift/Riverpod/Freezed annotation changes), but required to confirm zero codegen drift (AGENTS.md).
- [X] T019 Run `bash .github/scripts/validate_ci_gates.sh` — format + codegen drift + `flutter analyze` + `flutter test` must all pass with zero errors (AGENTS.md hard rule).
- [X] T020 Manual validation on an iOS or macOS device: quickstart.md Scenario B (timed cues on save) + Scenario C (shadow-friendly sizing) + Scenario D (clause/CJK punctuation). Confirm no save failures (SC-007) and ≤10% latency regression vs `main` (SC-006, Scenario F).
- [X] T021 [P] Verify no-regression on blank-transcript paths: BYOK OpenAI TTS and Linux still save blank transcripts with the player Generate affordance intact (quickstart.md Scenario E; FR-002 out-of-scope boundaries).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately. T001/T002 parallel.
- **Foundational (Phase 2)**: T003 standalone — blocks US2/US3/US4 only.
- **US1 (Phase 3)**: Independent of Phases 1–2. Can start immediately and ship alone (MVP A).
- **US2 (Phase 4)**: Depends on T003 (Foundational). Independent of US1. MVP candidate B.
- **US3 (Phase 5)**: Depends on US2 (segmenter core must exist).
- **US4 (Phase 6)**: Depends on US2.
- **Polish (Phase 7)**: Depends on all implemented stories.

### User Story Dependencies

- **US1 (P1)**: No dependencies on other stories. Native-only change.
- **US2 (P1)**: Depends on T003 (config types) + T001 (CJK helper if US3 follows). Dart-only.
- **US3 (P2)**: Depends on US2 (extends the segmenter).
- **US4 (P2)**: Depends on US2 (verifies segment timing).

### Parallel Opportunities

- **T001 ∥ T002 ∥ T003 ∥ T004 ∥ T005** all touch different files and can run together (Setup + Foundational + US1 native).
- **US1 (Phases 3) and US2 (Phase 4)** are fully independent — one developer on native Swift, another on the Dart segmenter.
- **T007 ∥ T008 ∥ T012 ∥ T015** test tasks within/between stories can run in parallel (same test file but additive; coordinate to avoid merge conflicts, or develop sequentially).
- **T017 ∥ T021** (docs + no-regression check) in Polish.

---

## Parallel Example: US1 + US2

```bash
# Developer A — native plugin (US1), independent of segmenter work:
Task T004: "iOS Swift plugin in packages/azure_speech/ios/Classes/AzureSpeechPlugin.swift"
Task T005: "macOS Swift plugin in packages/azure_speech/macos/Classes/AzureSpeechPlugin.swift"

# Developer B — segmenter (US2), independent of native work:
Task T007/T008/T009: "tests in test/features/craft/domain/word_boundary_segmenter_test.dart"
Task T010: "segmenter rewrite in lib/features/craft/domain/word_boundary_segmenter.dart"
Task T011: "controller call-site in lib/features/craft/application/craft_controller.dart"
```

---

## Implementation Strategy

### MVP Option A — US1 only (Apple coverage)

1. Complete Phase 1 (T001–T002 can wait; US1 doesn't need the CJK helper).
2. Complete US1 (T004–T006).
3. **STOP and VALIDATE**: quickstart.md Scenario B on iOS/macOS.
4. Ship — Apple users immediately get timed cues via the **existing** segmenter.

### MVP Option B — US2 only (shadow-friendly sizing)

1. Complete Phase 1 + Phase 2 (T001, T003).
2. Complete US2 (T007–T011).
3. **STOP and VALIDATE**: quickstart.md Scenario C (headless unit tests suffice).
4. Ship — Android/Windows/Apple users all get better line sizes.

### Full Delivery (recommended)

1. US1 + US2 in parallel (two independent MVPs).
2. US3 (clause + CJK) once US2 lands.
3. US4 (timing verification) once US2 lands.
4. Polish: docs + CI gates + device validation.

### Notes

- Tests are included per constitution Principle II, not optional.
- The native Swift change (US1) has no hostless automated test — manual device validation (quickstart.md Scenario B) is the documented test plan for that story.
- Every Dart segmenter change is pure logic and fully covered by unit tests.
- No schema migration, no codegen expected (T018 is a no-op confirmation).
- Commit after each task or logical group; the tree must be green before push (AGENTS.md).

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US1 and US2 are independently shippable P1 MVPs (native coverage vs. segmenter quality)
- US3/US4 extend US2 and depend on it
- Verify tests fail before implementing (TDD where practical); segmenter tests must be green before push
- Commit after each task or logical group
- Stop at any checkpoint to validate a story independently
