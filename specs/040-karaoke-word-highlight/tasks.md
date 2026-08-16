# Tasks: Karaoke Word Highlight

**Input**: Design documents from `specs/040-karaoke-word-highlight/`

**Note**: Slice 4 of issue #540. First transcript-panel consumer of stored word timings: opt-in in-place highlight while media plays. No IPA overlay, per-word tap, or play-time alignment. See [plan.md](./plan.md), [research.md](./research.md). ADR-0074 is written in polish.

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required for changed contracts (constitution + plan + spec independent tests). Manual checks per [quickstart.md](./quickstart.md) §§A–E.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Setting key**: `lib/data/db/settings_keys.dart`
- **Matcher**: `lib/data/subtitle/current_transcript_word.dart`
- **Karaoke bucket**: `lib/features/player/application/position_buckets.dart`
- **Setting notifier**: `lib/features/settings/application/karaoke_highlight_settings.dart`
- **Word index**: `lib/features/transcript/application/karaoke_word_index_provider.dart`
- **Markup / tile**: `lib/features/transcript/presentation/transcript_markup.dart`, `lib/features/transcript/presentation/transcript_line_tile.dart`
- **Settings hub**: `lib/features/settings/domain/settings_search_entry.dart`, `lib/features/settings/presentation/widgets/sections/transcript_section.dart`
- **ARB**: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_CN.arb`
- **Pins**: `test/features/alignment/forced_alignment_inert_import_test.dart`, `test/features/transcript/transcript_line_tile_nested_inert_test.dart`
- **Docs**: `docs/decisions/0074-karaoke-word-highlight.md`, `docs/features/transcript.md`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Feature branch on `main` (slice 3 already merged)

- [X] T001 Create git branch `040-karaoke-word-highlight` from current `main`
- [X] T002 Confirm `TranscriptLine.timeline` / `TranscriptWord` exist in `lib/data/subtitle/transcript_line.dart`, `transcriptPlaybackHighlightProvider` in `lib/features/transcript/application/transcript_playback_highlight_provider.dart`, `quantizedPositionStream` in `lib/features/player/application/quantized_position.dart`, and Settings Transcript section in `lib/features/settings/presentation/widgets/sections/transcript_section.dart`. Do **not** import `package:forced_alignment/` from transcript or settings

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Setting key (default off), pure matcher, 50 ms karaoke bucket, notifier, and a word-index provider that returns `null` when karaoke is off so stories can add paint without a second panel API

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 [P] Add `SettingsKeys.transcriptKaraokeHighlight = 'transcript.karaokeHighlight'` to the `_staticKeys` allowlist in `lib/data/db/settings_keys.dart` per [contracts/settings-toggle.md](./contracts/settings-toggle.md) (missing value ≡ off)
- [X] T004 [P] Implement `currentWordIndex` and `wordHighlightRange` in `lib/data/subtitle/current_transcript_word.dart` per [contracts/current-word.md](./contracts/current-word.md) and [data-model.md](./data-model.md) (media window from line start + relative word ms; last overlapping match; sequential substring on plain text; no Flutter imports)
- [X] T005 [P] Add `kPositionBucketKaraokeMs = 50` in `lib/features/player/application/position_buckets.dart`; do **not** change `kPositionBucketDisplayMs`
- [X] T006 Add keep-alive `@Riverpod` notifier `KaraokeHighlightSettings` in `lib/features/settings/application/karaoke_highlight_settings.dart` (read/write device-global `SettingsDao` like `lib/features/settings/application/timeline_enrichment_settings.dart`, including await/`resolveEnabled` so a still-loading read is not treated as off); run `dart run build_runner build` and commit `karaoke_highlight_settings.g.dart`
- [X] T007 Add `lib/features/transcript/application/karaoke_word_index_provider.dart` that returns `null` when karaoke is off or there is no current cue; when on, watch `rawEnginePositionStreamProvider` via `quantizedPositionStream(..., bucketMs: kPositionBucketKaraokeMs)` plus `transcriptPlaybackHighlightProvider` and `currentWordIndex` — never import `package:forced_alignment/`
- [X] T008 Keep `test/features/transcript/transcript_line_tile_nested_inert_test.dart` green (karaoke default off: nested words do not show IPA / extra chrome). Confirm `test/features/alignment/forced_alignment_inert_import_test.dart` still forbids transcript, settings, player, l10n from importing `package:forced_alignment/`

**Checkpoint**: App analyzes; setting defaults off; matcher/provider compile; nested-inert pin still holds

---

## Phase 3: User Story 1 - Default off: transcripts still behave as line-level (Priority: P1) 🎯 MVP

**Goal**: With karaoke at default (off), the panel matches post-slice-3 line-level chrome even on cues that already store word timings. No in-line highlight, IPA, or word chips.

**Independent Test**: Leave karaoke off. Open line-only items and at least one enriched Craft item. Play/pause/seek/echo/lookup/blur. No word highlight ([spec.md](./spec.md) US1, [quickstart.md](./quickstart.md) §A).

### Tests for User Story 1

> Write these FIRST; they must stay green with karaoke off even after nested fixtures

- [X] T009 [US1] Extend `test/features/transcript/transcript_line_tile_nested_inert_test.dart` (or add `test/features/transcript/transcript_karaoke_off_test.dart`): nested cue + karaoke off/missing → same visible line text/timestamp as line-only; no phone labels in semantics; tile `onTap` still fires as line tap

### Implementation for User Story 1

- [X] T010 [US1] In `lib/features/transcript/presentation/transcript_line_tile.dart`, only apply word highlight when `karaokeWordIndexProvider` is non-null for this **active** cue; inactive tiles must not watch the karaoke provider (`.select` / skip). Karaoke off → identical paint path to today
- [X] T011 [P] [US1] Confirm no IPA overlay, no per-word chips, and no new `media_kit` `Player()` in `lib/features/transcript/` and `lib/features/player/`; assessment take-replay karaoke in `lib/features/shadow_reading/` stays untouched
- [X] T012 [US1] Run existing regression: `flutter test test/features/transcript test/features/settings test/features/alignment/forced_alignment_inert_import_test.dart test/data/subtitle`

**Checkpoint**: US1 MVP — default panel unchanged; karaoke API exists but is inert when off

---

## Phase 4: User Story 2 - Opt-in karaoke highlights the spoken word (Priority: P1)

**Goal**: With karaoke on, the current timed word is highlighted in place on the primary line. Line chrome and tap-to-seek-to-line stay. Pause keeps the word at the paused position.

**Independent Test**: Karaoke on. Multi-word nested cue. Play at 1×. Highlighted word matches the stored window containing position; line rail still on the row ([spec.md](./spec.md) US2, [quickstart.md](./quickstart.md) §B).

### Tests for User Story 2

- [X] T013 [P] [US2] Add `test/data/subtitle/current_transcript_word_test.dart`: three timed words → index follows `positionMs`; overlap → last match; sequential substring ranges for `Hello world`
- [X] T014 [P] [US2] Add markup/highlight coverage in `test/features/transcript/transcript_markup_test.dart` (create if missing): optional highlight range tints the located substring without dropping markup; phone strings never appear

### Implementation for User Story 2

- [X] T015 [US2] Extend `transcriptMarkupToTextSpan` (or a sibling helper) in `lib/features/transcript/presentation/transcript_markup.dart` to accept an optional plain-text `[start, end)` highlight range per [contracts/panel-render.md](./contracts/panel-render.md)
- [X] T016 [US2] Finish `lib/features/transcript/application/karaoke_word_index_provider.dart` so karaoke on + current nested cue yields the matcher index; paused position keeps the last bucket; seek jumps immediately
- [X] T017 [US2] Wire `lib/features/transcript/presentation/transcript_line_tile.dart` (and selectable rich text) to paint `wordHighlightRange` on **primary** text only; secondary/translation stays unhighlighted
- [X] T018 [US2] Add `test/features/transcript/transcript_karaoke_highlight_test.dart`: karaoke on + position in first word → in-place highlight; no chips; no `phones[].phone` in the tree; tap on a non-active nested cue still calls line `onTap`

**Checkpoint**: Opt-in play shows the current word; IPA still hidden; line seek unchanged

---

## Phase 5: User Story 3 - Line-only and incomplete cues stay safe (Priority: P1)

**Goal**: Karaoke on never blanks a line, never invents a per-word split, and never blocks playback when timings are missing, incomplete, or out of window.

**Independent Test**: Mixed track: timed cue, line-only cue, words without times. Only timed windows highlight ([spec.md](./spec.md) US3, [quickstart.md](./quickstart.md) §C).

### Tests for User Story 3

- [X] T019 [US3] Extend `test/data/subtitle/current_transcript_word_test.dart`: empty/omitted timeline, zero duration, untimed words, out-of-window words, gap between words, missing substring → `null` index or `null` range; line fields unused as rewrite inputs

### Implementation for User Story 3

- [X] T020 [US3] Ensure `lib/data/subtitle/current_transcript_word.dart` and `lib/features/transcript/presentation/transcript_line_tile.dart` degrade to today’s line paint when index/range is null (no whitespace tokenization of line-only cues)
- [X] T021 [US3] Widget coverage in `test/features/transcript/transcript_karaoke_highlight_test.dart` (or a sibling): karaoke on + line-only active cue looks like karaoke off; mixed list does not throw

**Checkpoint**: Karaoke is per-cue fail-closed

---

## Phase 6: User Story 4 - Karaoke coexists with practice modes and Settings (Priority: P1)

**Goal**: Discoverable Settings row, persists without restart, independent of Craft enrichment. Echo/lookup/blur/translation keep line identity. Karaoke does not auto-reveal blurred cues or rewrite the library.

**Independent Test**: Toggle in Settings → Transcript; survives relaunch. Enrichment off + already-enriched item still highlights. Blur stays blurred until hover/hold ([spec.md](./spec.md) US4, [quickstart.md](./quickstart.md) §D).

### Tests for User Story 4

- [X] T022 [P] [US4] Add `test/features/settings/application/karaoke_highlight_settings_test.dart`: missing key → false; `setEnabled(true)` round-trips; delayed `true` is not treated as off
- [X] T023 [P] [US4] Extend `test/features/settings/domain/settings_search_entry_test.dart` and `test/features/settings/presentation/settings_screen_test.dart` so Transcript / `karaokeHighlight` is registered (assert the karaoke **title** string, not the unused section header)

### Implementation for User Story 4

- [X] T024 [P] [US4] Add ARB strings in `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, and `lib/l10n/app_zh_CN.arb` (switch title/subtitle, search keywords: karaoke, word highlight, timings); run `flutter gen-l10n`
- [X] T025 [US4] Register `rowId: 'karaokeHighlight'` in `lib/features/settings/domain/settings_search_entry.dart` and localize it in `lib/features/settings/application/settings_registry_localizer.dart`
- [X] T026 [US4] Add a second `SettingsRow` + `Switch.adaptive` in `lib/features/settings/presentation/widgets/sections/transcript_section.dart` bound to `karaokeHighlightSettingsProvider`; Settings Dart must **not** import `package:forced_alignment/`
- [X] T027 [US4] Extend blur tests (e.g. `test/features/transcript/transcript_blur_active_line_stays_blurred_test.dart` or a karaoke-specific sibling): karaoke on MUST NOT auto-reveal the active cue per [contracts/practice-modes.md](./contracts/practice-modes.md)
- [X] T028 [US4] Confirm echo merged card still uses `TranscriptLineTile` primary highlight only (`lib/features/transcript/presentation/transcript_echo_region_merged_card.dart`); translation/secondary text has 0 karaoke styles; Craft save still follows slice 3 regardless of karaoke (`test/features/craft` stays green)

**Checkpoint**: Opt-in is visible and sticky; practice modes keep their contracts

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Traceability, docs, and CI gates

- [X] T029 [P] Write ADR-0074 in `docs/decisions/0074-karaoke-word-highlight.md` (panel consumer, independent setting, in-place highlight, 50 ms karaoke bucket, no IPA / word tap / play-time alignment). Do **not** rewrite ADR-0070–0073
- [X] T030 [P] Index ADR-0074 in `docs/decisions/README.md`
- [X] T031 [P] Update `docs/features/transcript.md`: nested spans are consumed for karaoke when the setting is on; still no IPA / per-word tap; blur/echo/lookup unchanged
- [X] T032 Run `dart run build_runner build` and `flutter gen-l10n` if needed; commit `*.g.dart` / generated l10n
- [X] T033 Run [quickstart.md](./quickstart.md) automated checks: `flutter test test/data/subtitle test/features/transcript test/features/settings test/features/alignment`, `flutter analyze`, `bash .github/scripts/validate_ci_gates.sh --fix` (do not mix unrelated format files)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately from `main`
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **User Stories (Phase 3–6)**: All depend on Foundational
  - US1 can ship as a no-behavior-change MVP once highlight is inert when off
  - US2–US3 share matcher + tile paint (implement success then fail-closed, or both in one pass)
  - US4 Settings chrome can start after T003/T006 even in parallel with US2 if the switch only reads the bool
- **Polish (Phase 7)**: Depends on US1–US4

### User Story Dependencies

- **User Story 1 (P1)**: After Phase 2 — default-off paint path
- **User Story 2 (P1)**: After Phase 2 — needs matcher + markup + provider; independently testable with a nested fixture + fake position
- **User Story 3 (P1)**: After US2’s paint path exists (or the same tile PR)
- **User Story 4 (P1)**: After T003/T006 — UI + registry + blur; does not require a live Craft save to prove persist / independence from enrichment

### Within Each User Story

- Tests first where marked; confirm karaoke-off tests fail if highlight leaks
- Matcher before markup before tile
- Provider before tile watch
- Story complete before calling the slice done

### Parallel Opportunities

- T003, T004, T005 in parallel (different files)
- T013 and T014 in parallel
- T022/T023/T024 in parallel with US2 implementation if the switch only binds the notifier
- T029–T031 docs in parallel during polish

---

## Parallel Example: User Story 1

```bash
# After Phase 2:
Task: "transcript_line_tile_nested_inert_test.dart karaoke off"
Task: "confirm no IPA / no new Player() in transcript + player"
```

---

## Parallel Example: User Story 2

```bash
# After Phase 2 matcher exists:
Task: "current_transcript_word_test.dart"
Task: "transcript_markup highlight-range test"
# Then provider + tile paint (same files as US3 — do not split across two people)
```

---

## Parallel Example: User Story 4

```bash
# After T006 notifier exists:
Task: "karaoke_highlight_settings_test.dart"
Task: "ARB strings in app_en.arb / app_zh.arb / app_zh_CN.arb"
Task: "settings_search_entry_test.dart + settings_screen_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Nested cues still look line-level when karaoke is off; existing transcript tests green
5. This MVP is safe as a no-behavior-change **but does not ship visible karaoke** — continue US2–US4 before calling slice 4 done

### Incremental Delivery

1. Setup + Foundational → key, matcher, 50 ms bucket, skip-when-off provider, inert pins
2. US1 → default panel unchanged → merge-safe
3. US2 → opt-in in-place word highlight
4. US3 → fail-closed incomplete cues
5. US4 → Settings row + blur/echo/lookup coexistence
6. Polish → ADR-0074 + transcript docs + CI gates

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Developer A: US1–US3 matcher/markup/tile/provider (owns `current_transcript_word.dart`, `transcript_line_tile.dart`, `karaoke_word_index_provider.dart`)
3. Developer B: US4 Settings section + ARB + registry tests (owns settings presentation; must not import `forced_alignment`)
4. Developer C: docs + ADR-0074 (T029–T031)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to spec user stories US1–US4
- Do not add IPA overlay, per-word tap/seek/loop, play-time alignment, YouTube demux, or library backfill
- Do not change `kPositionBucketDisplayMs` (Windows a11y)
- Do not import `package:forced_alignment/` from transcript, settings, player, or l10n
- Do not rewrite ADR-0070–0073
- Karaoke MUST NOT auto-reveal blurred cues
- Verify karaoke-off tests fail if highlight leaks before wiring paint
- Commit after each task or logical group (setup, foundation, US1, US2, US3, US4, polish)
- Avoid: `print()`, new `media_kit` `Player()`, Flutter web
