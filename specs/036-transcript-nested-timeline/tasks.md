# Tasks: Nested Transcript Timeline

**Input**: Design documents from `specs/036-transcript-nested-timeline/`

**Note**: Nested types are the enjoy web cue JSON (`timeline` / `phones` / `PhoneTiming` seconds). See [data-model.md](./data-model.md) and [ADR-0070](../../docs/decisions/0070-nested-transcript-timeline.md).

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required for changed contracts (constitution + plan + spec independent tests). Manual E2E per [quickstart.md](./quickstart.md).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Model**: `lib/data/subtitle/transcript_line.dart`
- **JSON helpers**: `lib/core/json/json_cast.dart` (`castJsonObjectOrNull`, `intFromJson`)
- **Line identity**: `lib/features/transcript/domain/transcript_blur.dart` (`cueIdFor`)
- **Panel tile**: `lib/features/transcript/presentation/transcript_line_tile.dart`
- **Tests**: `test/data/subtitle/transcript_line_test.dart`, `test/features/domain_gaps_coverage_test.dart`, `test/features/transcript/`
- **Docs**: `docs/decisions/0070-nested-transcript-timeline.md`, `docs/features/transcript.md`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm touch points; no new packages or Drift tables

- [X] T001 Confirm edit points: `TranscriptLine` in `lib/data/subtitle/transcript_line.dart`; `cueIdFor` in `lib/features/transcript/domain/transcript_blur.dart`; `TranscriptLineTile` in `lib/features/transcript/presentation/transcript_line_tile.dart`; ADR index in `docs/decisions/README.md`; feature note in `docs/features/transcript.md` per [plan.md](./plan.md)
- [X] T002 [P] Confirm no new pubspec dependencies and no Drift schema change: `pubspec.yaml` unchanged; `lib/data/db/tables/transcripts.dart` still opaque `timelineJson` TEXT only

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: In-memory nested types on the cue so stories can persist, compare, and ignore spans without a schema migration

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Add immutable `TranscriptWord` and `TranscriptPhoneme` classes and optional `List<TranscriptWord>? words` on `TranscriptLine` (default `null`) in `lib/data/subtitle/transcript_line.dart` per [data-model.md](./data-model.md); do not rename or remove `text`, `startMs`, `durationMs`, or `sourceKey`
- [X] T004 Normalize empty `words` / `phonemes` lists to `null` in `TranscriptLine` / `TranscriptWord` construction in `lib/data/subtitle/transcript_line.dart` per [research.md](./research.md) (omitted ≡ empty)

**Checkpoint**: Types exist; existing `const TranscriptLine(...)` call sites still compile; JSON still line-only until US2

---

## Phase 3: User Story 1 - Existing transcripts are unchanged (Priority: P1) 🎯 MVP

**Goal**: Line-only cues keep the same JSON and practice behavior. Nested fields are additive and omitted when absent. Existing producers still write line-only cues.

**Independent Test**: `fromJson`/`toJson` of a historical `{text, start, duration}` cue is unchanged; existing transcript tests stay green; no producer requires `words` ([spec.md](./spec.md) US1, [quickstart.md](./quickstart.md) §A).

### Tests for User Story 1

> Write these tests FIRST, ensure they FAIL before implementation if `toJson` would emit `words` by default

- [X] T005 [US1] Add line-only JSON pins in `test/data/subtitle/transcript_line_test.dart`: `toJson()` is exactly `{text, start, duration}` (plus `sourceKey` when set); `fromJson` of a fixture without `words` yields `words == null`; round-trip does not invent nested spans per [contracts/transcript-line-json.md](./contracts/transcript-line-json.md)

### Implementation for User Story 1

- [X] T006 [US1] Make `TranscriptLine.toJson` in `lib/data/subtitle/transcript_line.dart` omit `words` when null/empty (same omit-empty pattern as `sourceKey`)
- [X] T007 [US1] Confirm existing producers still emit line-only cues (no `words` writes) in `lib/data/subtitle/subtitle_parser.dart`, `lib/features/asr/domain/asr_timeline_builder.dart`, `lib/features/craft/data/craft_tts_service_synthesizer.dart`, `lib/features/transcript/data/transcript_repository_auto_translate.dart`, and YouTube timeline mapping under `lib/features/transcript/data/`
- [X] T008 [US1] Run existing transcript regression: `flutter test test/features/transcript/transcript_repository_test.dart test/features/transcript/transcript_lines_provider_dedupe_test.dart test/features/transcript/auto_translate_controller_test.dart test/data/subtitle/transcript_line_test.dart`

**Checkpoint**: US1 MVP — additive field cannot change stored line-only transcripts or current producers

---

## Phase 4: User Story 2 - A cue can remember optional word and phone spans (Priority: P1)

**Goal**: Nested word/phone spans round-trip through `toJson`/`fromJson` without changing line text, start, or duration. Malformed nested data degrades to line-only for that cue.

**Independent Test**: Persist a cue with ≥3 words and ≥1 word with phones; reload; nested fields preserved; line fields identical; bad `words` does not drop the cue ([spec.md](./spec.md) US2, [contracts/transcript-line-json.md](./contracts/transcript-line-json.md)).

### Tests for User Story 2

> Write these tests FIRST, ensure they FAIL before implementation

- [X] T009 [US2] Add nested round-trip tests in `test/data/subtitle/transcript_line_test.dart`: words+phonemes preserved in order; optional `start`/`duration`/`ipa` omitted when absent; empty lists omitted; `fromJson(toJson(line)) == line` per [contracts/transcript-line-json.md](./contracts/transcript-line-json.md)
- [X] T010 [US2] Add malformed-nested tests in `test/data/subtitle/transcript_line_test.dart`: `words` not a list, non-object element, empty word `text`, empty phone `ipa` — line fields still load; junk skipped; `fromJson` does not throw

### Implementation for User Story 2

- [X] T011 [US2] Implement nested `fromJson` in `lib/data/subtitle/transcript_line.dart` using `castJsonObjectOrNull` and `intFromJson` from `lib/core/json/json_cast.dart`; missing nested times stay `null` (not `0`); never rewrite line `text`/`start`/`duration` from nested times
- [X] T012 [US2] Implement nested `toJson` write rules in `lib/data/subtitle/transcript_line.dart` (word always `text`; phone always `ipa`; omit empty `phonemes`/`ipa`/`start`/`duration`) per [contracts/transcript-line-json.md](./contracts/transcript-line-json.md)

**Checkpoint**: US2 — nested spans persist in `timeline_json`; line-only path from US1 still holds

---

## Phase 5: User Story 3 - Nested data is inert until a later slice uses it (Priority: P1)

**Goal**: Nested spans do not change line identity (blur, echo, seek, auto-translate) or panel chrome. Value equality includes `words` so a later enrichment can notify listeners. The tile still shows `line.text` only.

**Independent Test**: Same line text/times with vs without `words` → same `cueIdFor` and same tile text/timestamp; different `words` → not `==`; no karaoke/IPA/chips ([spec.md](./spec.md) US3, [contracts/transcript-line-identity.md](./contracts/transcript-line-identity.md), [contracts/inert-nested-render.md](./contracts/inert-nested-render.md)).

### Tests for User Story 3

> Write these tests FIRST, ensure they FAIL before implementation

- [X] T013 [P] [US3] Add identity tests: `cueIdFor` unchanged when `words` added; `sourceKey` unchanged; `null` vs empty `words` are `==` after normalize — in `test/data/subtitle/transcript_line_test.dart` and extend the `cueIdFor` group in `test/features/domain_gaps_coverage_test.dart` per [contracts/transcript-line-identity.md](./contracts/transcript-line-identity.md)
- [X] T014 [P] [US3] Add value-equality case in `test/features/transcript/transcript_lines_provider_dedupe_test.dart`: identical line fields with different `words` are not `==`
- [X] T015 [P] [US3] Add widget test in `test/features/transcript/transcript_line_tile_nested_inert_test.dart`: two `TranscriptLineTile`s with the same `text`/`startMs`/`durationMs` (one line-only, one with words+phones) expose the same primary plain text and timestamp; no IPA in semantics per [contracts/inert-nested-render.md](./contracts/inert-nested-render.md)

### Implementation for User Story 3

- [X] T016 [US3] Include `words` in `TranscriptLine.==` and `hashCode` in `lib/data/subtitle/transcript_line.dart` (treat null and empty as equal after T004 normalize)
- [X] T017 [P] [US3] Confirm `cueIdFor` in `lib/features/transcript/domain/transcript_blur.dart` reads only `startMs`, `durationMs`, and plain `line.text` (no `words`)
- [X] T018 [P] [US3] Confirm `TranscriptLineTile` in `lib/features/transcript/presentation/transcript_line_tile.dart` still renders `widget.line.text` and `widget.line.startMs` only (no `words` in body, timestamp, or semantics)

**Checkpoint**: US3 — nested data is inert in the UI and cannot reset practice line identity

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Decision record, feature doc, and CI gates for the whole slice

- [X] T019 [P] Write ADR-0070 (additive nested cue JSON; line identity unchanged; alignment tree not stored on the cue) in `docs/decisions/0070-nested-transcript-timeline.md`
- [X] T020 Index ADR-0070 in `docs/decisions/README.md`
- [X] T021 [P] Add a “Nested word/phone spans (storage only)” note to `docs/features/transcript.md` (no Settings toggle; panel still line-level)
- [X] T022 Run `flutter analyze`, `flutter test`, and `bash .github/scripts/validate_ci_gates.sh --fix` as listed in `specs/036-transcript-nested-timeline/quickstart.md`; fix until green

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories (`transcript_line.dart` types)
- **User Story 1 (Phase 3)**: Depends on Foundational — omit-empty JSON + producer freeze
- **User Story 2 (Phase 4)**: Depends on US1 `toJson` omit rules (T006) so nested write builds on the same omit-empty policy
- **User Story 3 (Phase 5)**: Depends on Foundational for in-memory `words`; identity/`==` should land after US2 JSON so round-tripped nested cues compare correctly
- **Polish (Phase 6)**: Depends on US1–US3

### User Story Dependencies

- **User Story 1 (P1)**: After Phase 2 — no dependency on US2/US3
- **User Story 2 (P1)**: After US1 T006 (shared `toJson` in `transcript_line.dart`)
- **User Story 3 (P1)**: After Phase 2; T016 (`==`) should follow US2 so nested round-trips participate in equality; T015 widget test can start once T003 exists

`lib/data/subtitle/transcript_line.dart` is the hotspot — do not parallel T003/T004/T006/T011/T012/T016.

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Story complete before moving to the next priority when sharing `transcript_line.dart`

### Parallel Opportunities

- T001 and T002 (read-only confirms)
- T013, T014, T015 (three different test files) after types exist
- T017 and T018 (confirm-only, different files) after T015/T016
- T019 and T021 (different docs) after stories land; T020 after T019
- T009 and T010 are the **same** test file — run sequentially, not [P]

---

## Parallel Example: User Story 3

```bash
# After Phase 2 types exist, launch US3 tests in parallel:
Task: "Identity tests in test/data/subtitle/transcript_line_test.dart + test/features/domain_gaps_coverage_test.dart"
Task: "Equality case in test/features/transcript/transcript_lines_provider_dedupe_test.dart"
Task: "Inert tile widget test in test/features/transcript/transcript_line_tile_nested_inert_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: line-only JSON unchanged; existing transcript tests green
5. This MVP is safe to merge as a no-behavior-change, but **does not yet store nested spans** — continue US2+US3 before calling slice 1 done

### Incremental Delivery

1. Setup + Foundational → optional `words` field exists
2. US1 → existing transcripts cannot regress → demo/merge-safe
3. US2 → nested round-trip works → substrate for #540 slices 2–5
4. US3 → identity + inert UI locked → slice 1 complete
5. Polish → ADR-0070 + feature doc + CI gates

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (single-file model)
2. One developer owns `transcript_line.dart` JSON (US1 then US2)
3. Meanwhile another can draft T013–T015 tests and T019/T021 docs
4. US3 `==` / tile confirm after JSON lands

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to spec user stories US1–US3
- Do not add Settings, karaoke, IPA overlay, Craft DTW, or `packages/forced_alignment` in this slice
- Do not create a Drift migration
- Verify tests fail before implementing JSON/`==` changes
- Commit after each task or logical group (US1, US2, US3, polish)
- Avoid: recursive Echogarden `timeline` on the stored cue; seconds instead of ms; `print()`
