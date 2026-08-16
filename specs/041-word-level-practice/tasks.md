# Tasks: Word-Level Practice

**Input**: Design documents from `specs/041-word-level-practice/`

**Note**: Slice 5 of issue #540, absorbing stored-phone display from #527. Two default-off Settings toggles: IPA overlay (annotation layer) and word-level practice (seek/loop/inspect). No G2P, play-time alignment, or new `Player()`. See [plan.md](./plan.md), [research.md](./research.md). ADR-0075 is written in polish. Implement on git branch `041-word-level-practice` (not in the karaoke PR).

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required for changed contracts (constitution + plan + spec independent tests). Manual checks per [quickstart.md](./quickstart.md) §§A–F.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Setting keys**: `lib/data/db/settings_keys.dart`
- **Matcher / IPA helpers**: `lib/data/subtitle/current_transcript_word.dart`, `lib/data/subtitle/transcript_word_ipa.dart`
- **Notifiers**: `lib/features/settings/application/ipa_overlay_settings.dart`, `lib/features/settings/application/word_practice_settings.dart`
- **Word index**: `lib/features/transcript/application/active_cue_word_index_provider.dart`, `lib/features/transcript/application/karaoke_word_index_provider.dart`
- **Session / loop**: `lib/features/transcript/application/word_practice_session.dart`, `lib/features/player/application/word_loop_enforcer.dart`, `lib/features/player/application/player_position_tracker.dart`, `lib/features/player/application/player_interactions.dart`
- **Overlay / tile / inspect**: `lib/features/transcript/presentation/transcript_word_ipa_layer.dart`, `lib/features/transcript/presentation/transcript_line_tile.dart`, `lib/features/transcript/presentation/word_phone_inspect_sheet.dart`, `lib/features/transcript/presentation/transcript_panel.dart`
- **Settings hub**: `lib/features/settings/domain/settings_search_entry.dart`, `lib/features/settings/application/settings_registry_localizer.dart`, `lib/features/settings/presentation/widgets/sections/transcript_section.dart`
- **ARB**: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_CN.arb`
- **Pins**: `test/features/alignment/forced_alignment_inert_import_test.dart`, `test/features/transcript/transcript_line_tile_nested_inert_test.dart`
- **Docs**: `docs/decisions/0075-word-level-practice.md`, `docs/features/transcript.md`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Dedicated feature branch that already contains slice 4 karaoke (ADR-0074)

- [X] T001 Create git branch `041-word-level-practice` from `040-karaoke-word-highlight` if karaoke is not on `main`, otherwise from `main`. Do not add these files to PR #559
- [X] T002 Confirm `TranscriptWord.phones` / `TranscriptPhone.phone` in `lib/data/subtitle/transcript_line.dart`, `currentWordIndex` / `wordHighlightRange` in `lib/data/subtitle/current_transcript_word.dart`, `KaraokeHighlightSettings` in `lib/features/settings/application/karaoke_highlight_settings.dart`, `EchoEnforcer` in `lib/features/player/application/echo_enforcer.dart`, `_seekLine` in `lib/features/player/application/player_interactions.dart`, and `showEnjoyAdaptiveSheet` in `lib/core/theme/widgets/enjoy_modal.dart`. Do **not** import `package:forced_alignment/` from transcript, settings, player, or l10n

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Two default-off keys, pure helpers, keep-alive notifiers, shared current-word index (50 ms only when karaoke **or** practice is on), panel hydration. Stories can then add overlay/tap without a second settings store

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 [P] Add `SettingsKeys.transcriptIpaOverlay = 'transcript.ipaOverlay'` and `SettingsKeys.transcriptWordPractice = 'transcript.wordPractice'` to the `_staticKeys` allowlist in `lib/data/db/settings_keys.dart` per [contracts/settings-toggles.md](./contracts/settings-toggles.md) (missing value ≡ off)
- [X] T004 [P] Extend `lib/data/subtitle/current_transcript_word.dart` with `allWordTextRanges`, `wordIndexAtPlainOffset`, and `wordMediaWindowMs` per [contracts/word-hit-test.md](./contracts/word-hit-test.md) and [data-model.md](./data-model.md) (sequential substring ranges; out-of-line windows are not targets; no Flutter imports)
- [X] T005 [P] Add `wordIpaSpelling` / `wordIpaPieces` in `lib/data/subtitle/transcript_word_ipa.dart` per [data-model.md](./data-model.md) (join non-empty `TranscriptPhone.phone` in order; null/empty if none; no invented IPA; no Flutter imports)
- [X] T006 Add keep-alive `@Riverpod` notifier `IpaOverlaySettings` in `lib/features/settings/application/ipa_overlay_settings.dart` (mirror `lib/features/settings/application/karaoke_highlight_settings.dart`, including await so a still-loading read is not treated as off); run `dart run build_runner build` and commit `ipa_overlay_settings.g.dart`
- [X] T007 Add keep-alive `@Riverpod` notifier `WordPracticeSettings` in `lib/features/settings/application/word_practice_settings.dart` (same pattern as T006); run `dart run build_runner build` and commit `word_practice_settings.g.dart`
- [X] T008 Add `lib/features/transcript/application/active_cue_word_index_provider.dart` that watches the 50 ms `karaokePositionProvider` **only when** karaoke **or** word-practice is on (`value == true`); keep `lib/features/transcript/application/karaoke_word_index_provider.dart` returning null unless karaoke is on. Never import `package:forced_alignment/`. Do **not** change `kPositionBucketDisplayMs`
- [X] T009 Hydrate `ipaOverlaySettingsProvider` and `wordPracticeSettingsProvider` from `lib/features/transcript/presentation/transcript_panel.dart` during skeleton (same watch as `karaokeHighlightSettingsProvider`)
- [X] T010 Keep `test/features/transcript/transcript_line_tile_nested_inert_test.dart` green (both new settings default off: nested words do not show IPA / extra chrome). Confirm `test/features/alignment/forced_alignment_inert_import_test.dart` still forbids transcript, settings, player, l10n from importing `package:forced_alignment/`

**Checkpoint**: App analyzes; both settings default off; helpers/providers compile; nested-inert and inert-import pins still hold

---

## Phase 3: User Story 1 - Default off: transcripts still behave as line-level (Priority: P1) 🎯 MVP

**Goal**: With IPA overlay and word-level practice at default (off), the panel matches post-slice-4 line-level chrome even on cues that already store words/phones. No IPA, seek-to-word, loop, or inspect.

**Independent Test**: Leave both new controls off. Open line-only items and at least one enriched Craft item. Play/tap/lookup/echo/karaoke/blur. No IPA and no word seek ([spec.md](./spec.md) US1, [quickstart.md](./quickstart.md) §A).

### Tests for User Story 1

> Write these FIRST; they must stay green with both settings off even after nested phone fixtures

- [X] T011 [US1] Extend `test/features/transcript/transcript_line_tile_nested_inert_test.dart` (or add `test/features/transcript/transcript_word_practice_off_test.dart`): nested cue + both settings off/missing → same visible line text/timestamp as line-only; no phone labels in the tree or semantics; tile `onTap` still fires as line tap. Isolated tests must override both new notifiers with off implementations (do not open SettingsDao)

### Implementation for User Story 1

- [X] T012 [US1] In `lib/features/transcript/presentation/transcript_line_tile.dart`, skip IPA annotation and word hit-test unless the matching setting’s awaited value is true; inactive tiles must not watch `activeCueWordIndexProvider`. Both off → identical paint/tap path to slice 4
- [X] T013 [P] [US1] Confirm no G2P/phonemizer, no per-word chips, and no new `media_kit` `Player()` in `lib/features/transcript/` and `lib/features/player/`; assessment take-replay karaoke in `lib/features/shadow_reading/` stays untouched
- [X] T014 [US1] Run existing regression: `flutter test test/features/transcript test/features/settings test/features/alignment/forced_alignment_inert_import_test.dart test/data/subtitle`

**Checkpoint**: US1 MVP — default panel unchanged; new APIs exist but are inert when off

---

## Phase 4: User Story 2 - Opt-in IPA overlay shows stored pronunciation on words (Priority: P1)

**Goal**: With IPA overlay on, stored phone labels appear with each eligible primary-line word as an IgnorePointer annotation layer. Orthography stays the selectable/karaoke text. Lookup never receives IPA. Line-only cues stay line-level.

**Independent Test**: Overlay on, practice off. Multi-word cue with phones on some words. Spelling only on words that have stored pieces; tap still line-seeks; lookup uses transcript text ([spec.md](./spec.md) US2, [quickstart.md](./quickstart.md) §B).

### Tests for User Story 2

- [X] T015 [P] [US2] Add `test/data/subtitle/transcript_word_ipa_test.dart`: ordered non-empty `phone` concat; skip empty pieces; no phones → null; never invent labels

### Implementation for User Story 2

- [X] T016 [US2] Implement `lib/features/transcript/presentation/transcript_word_ipa_layer.dart`: layout-time `TextPainter` boxes from plain line text + style + width; paint `wordIpaSpelling` above each matching word; `IgnorePointer`; exclude IPA from semantics used for lookup
- [X] T017 [US2] Wire the layer in `lib/features/transcript/presentation/transcript_line_tile.dart` inside the existing blur wrapper when overlay is on and the cue is revealed (or blur off); extra top inset so ruby is not clipped; **primary** only; karaoke highlight stays on word **text** per [contracts/ipa-overlay.md](./contracts/ipa-overlay.md)
- [X] T018 [US2] Add `test/features/transcript/transcript_ipa_overlay_test.dart`: overlay on + mixed phones → IPA in the annotation layer; `transcriptPlainForSelection` / lookup callback orthography only; overlay on + practice off → non-selectable tap still line `onTap`; line-only cue has no IPA widgets
- [X] T019 [US2] Fail-closed coverage in `test/features/transcript/transcript_ipa_overlay_test.dart`: unreadable/empty phones skip that word; overlay on does not blank the line or add chips

**Checkpoint**: Opt-in reading shows stored IPA; lookup text unchanged; taps still line-level while practice is off

---

## Phase 5: User Story 3 - Opt-in: tap a timed word to hear it (Priority: P1)

**Goal**: With word-level practice on, tapping a timed word on a **non-selectable** nested row seeks to that word’s media start. Timestamp/chrome and misses still line-seek. Selectable rows keep lookup.

**Independent Test**: Practice on. Nested cue not active/echo. Tap a middle timed word → position in that word’s window; tap timestamp → line start; active line selection still lookup ([spec.md](./spec.md) US3, [quickstart.md](./quickstart.md) §C).

### Tests for User Story 3

- [X] T020 [P] [US3] Extend `test/data/subtitle/current_transcript_word_test.dart`: `wordIndexAtPlainOffset` hits timed tokens; space/gap/untimed → null; `wordMediaWindowMs` uses line start + relative word ms; out-of-line window is not a target

### Implementation for User Story 3

- [X] T021 [US3] Add `seekToWord` in `lib/features/player/application/player_interactions.dart` per [contracts/word-hit-test.md](./contracts/word-hit-test.md): seek `(line.startMs + word.startMs)/1000` then play; if echo is already active, keep today’s line echo **retarget** but land on the word start; wrap with `Haptics`; set chosen word on `lib/features/transcript/application/word_practice_session.dart` (create the session notifier here if US4 has not)
- [X] T022 [US3] On non-selectable primary text in `lib/features/transcript/presentation/transcript_line_tile.dart`, when practice is on, map tap offset via `TextPainter.getPositionForOffset` + `wordIndexAtPlainOffset`; hit → `seekToWord`; miss/timestamp/meta → existing line `onTap`. Selectable `TranscriptSelectableRichText` must **not** call `seekToWord`
- [X] T023 [US3] Add `test/features/transcript/transcript_word_seek_test.dart` (and extend `test/features/player/player_interactions_test.dart` if needed): practice on + tap second timed word → word seek; timestamp → line seek; selectable row → no word seek; practice off → all line-level

**Checkpoint**: Opt-in word tap works only where lookup is not the primary gesture

---

## Phase 6: User Story 4 - Loop one word, then inspect its stored phones (Priority: P1)

**Goal**: Loop repeats one timed word’s media window until cancel without rewriting echo. Inspect shows ordered stored phone pieces in an Enjoy adaptive sheet, or no inspect chrome when phones are missing.

**Independent Test**: Practice on. Loop current/chosen word → repeats that window; echo expand/shrink still line-based; inspect lists stored pieces; no phones → no inspect icon ([spec.md](./spec.md) US4, [quickstart.md](./quickstart.md) §D).

### Tests for User Story 4

- [X] T024 [P] [US4] Add `test/features/player/application/word_loop_enforcer_test.dart` (pure wrap/cancel decisions if extracted, otherwise controller tests): position at `mediaEndMs` → seek start; inside window → no-op; practice off / stop → inactive

### Implementation for User Story 4

- [X] T025 [US4] Finish ephemeral `WordPracticeSession` in `lib/features/transcript/application/word_practice_session.dart` (chosen word + loop `{lineIndex, wordIndex, mediaStartMs, mediaEndMs}`); not written to `SessionDao`; clear on media switch / practice off. Run `dart run build_runner build` and commit `word_practice_session.g.dart`
- [X] T026 [US4] Implement `lib/features/player/application/word_loop_enforcer.dart` and call it from `lib/features/player/application/player_position_tracker.dart` **before** `EchoEnforcer.enforceTick`; skip echo pause-and-rewind while looping; `reset` on tracker `cancel`; no new `Player()`
- [X] T027 [US4] Add loop + inspect `EnjoyTappableIcon`s (tooltips) on the **selectable** active/echo cue meta row in `lib/features/transcript/presentation/transcript_line_tile.dart` when practice is on and `activeCueWordIndexProvider` is non-null; inspect omitted when `wordIpaPieces` is empty; inspect opens `lib/features/transcript/presentation/word_phone_inspect_sheet.dart` via `showEnjoyAdaptiveSheet` in `lib/core/theme/widgets/enjoy_modal.dart` (root navigator)
- [X] T028 [US4] Widget/controller coverage in `test/features/transcript/transcript_word_loop_test.dart`: start loop → wraps without changing echo start/end; cancel via practice off; karaoke may still highlight the looping word; auto-follow still the line
- [X] T029 [P] [US4] Add `test/features/transcript/word_phone_inspect_sheet_test.dart`: phones `["æ", "n"]` listed in order; empty phones → no inspect control; no alignment / `/pronounce` calls

**Checkpoint**: Word loop and inspect work; echo membership stays line-based; missing phones stay quiet

---

## Phase 7: User Story 5 - Overlay and practice coexist with karaoke, echo, lookup, blur, and Settings (Priority: P1)

**Goal**: Discoverable Settings rows, persist without restart, independent of karaoke and Craft enrichment. Echo/lookup/blur/translation keep line identity. Overlay does not auto-reveal or leak IPA through blur.

**Independent Test**: Toggle both in Settings → Transcript; survives relaunch. Enrichment off + already-enriched item still overlays/practices. Blur stays blurred until hover/hold; lookup text has no IPA ([spec.md](./spec.md) US5, [quickstart.md](./quickstart.md) §E).

### Tests for User Story 5

- [X] T030 [P] [US5] Add `test/features/settings/application/ipa_overlay_settings_test.dart` and `test/features/settings/application/word_practice_settings_test.dart`: missing key → false; `setEnabled(true)` round-trips; delayed `true` is not treated as off
- [X] T031 [P] [US5] Extend `test/features/settings/domain/settings_search_entry_test.dart` and `test/features/settings/presentation/settings_screen_test.dart` so Transcript / `ipaOverlay` / `wordPractice` are registered (assert **title** strings)

### Implementation for User Story 5

- [X] T032 [P] [US5] Add ARB strings in `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, and `lib/l10n/app_zh_CN.arb` (overlay + practice switch titles/subtitles; loop/inspect tooltips; inspect sheet title; search keywords: IPA, pronunciation, word tap, word loop); run `flutter gen-l10n`
- [X] T033 [US5] Register `rowId: 'ipaOverlay'` and `rowId: 'wordPractice'` in `lib/features/settings/domain/settings_search_entry.dart` and localize in `lib/features/settings/application/settings_registry_localizer.dart`
- [X] T034 [US5] Add two `SettingsRow` + `Switch.adaptive` **after karaoke** in `lib/features/settings/presentation/widgets/sections/transcript_section.dart` bound to the new notifiers; Settings Dart must **not** import `package:forced_alignment/`
- [X] T035 [US5] Extend `test/features/transcript/transcript_blur_active_line_stays_blurred_test.dart` (or a sibling): overlay on MUST NOT auto-reveal; IPA MUST NOT be visible through an unrevealed cue per [contracts/practice-modes.md](./contracts/practice-modes.md). Confirm translation/secondary text has 0 IPA and 0 word seeks; karaoke highlight still independent; Craft save still follows slice 3 (`test/features/craft` stays green)

**Checkpoint**: Opt-in is visible and sticky; practice modes keep their contracts

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Traceability, docs, and CI gates

- [X] T036 [P] Write ADR-0075 in `docs/decisions/0075-word-level-practice.md` (two settings, annotation-layer IPA, hit-test seek, ephemeral loop, inspect sheet, no G2P / play-time alignment / new Player). Do **not** rewrite ADR-0070–0074
- [X] T037 [P] Index ADR-0075 in `docs/decisions/README.md`
- [X] T038 [P] Update `docs/features/transcript.md`: overlay and word practice when settings are on; lookup text excludes IPA; blur/echo/karaoke unchanged except documented coexistence
- [X] T039 Run `dart run build_runner build` and `flutter gen-l10n` if needed; commit `*.g.dart` / generated l10n
- [X] T040 Run [quickstart.md](./quickstart.md) automated checks: `flutter test test/data/subtitle test/features/transcript test/features/settings test/features/player test/features/alignment`, `flutter analyze`, `bash .github/scripts/validate_ci_gates.sh --fix` (do not mix unrelated format files)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start from karaoke-complete tree
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **User Stories (Phase 3–7)**: All depend on Foundational
  - US1 can ship as a no-behavior-change MVP once overlay/tap are inert when off
  - US2 overlay and US3 hit-test both edit `transcript_line_tile.dart` — do not split that file across two people
  - US4 loop/inspect depends on `seekToWord` / session from US3 (or create the session in T021)
  - US5 Settings chrome can start after T006/T007 even in parallel with US2 if the switches only read the bools
- **Polish (Phase 8)**: Depends on US1–US5

### User Story Dependencies

- **User Story 1 (P1)**: After Phase 2 — default-off paint/tap path
- **User Story 2 (P1)**: After Phase 2 — needs IPA helper + overlay setting; independently testable with a nested phone fixture
- **User Story 3 (P1)**: After Phase 2 — needs hit-test helpers + practice setting; independently testable with fake tap + `seekToWord`
- **User Story 4 (P1)**: After US3’s `seekToWord` / session (same tile PR is fine)
- **User Story 5 (P1)**: After T006/T007 — UI + registry + blur; does not require a live Craft save to prove persist / independence

### Within Each User Story

- Tests first where marked; confirm off-path tests fail if IPA or word seek leaks
- Helpers before widgets before wiring
- Notifiers before Settings rows
- Story complete before calling the slice done

### Parallel Opportunities

- T003, T004, T005 in parallel (different files)
- T006 and T007 in parallel after T003 (then codegen once)
- T015 in parallel with T016 after T005
- T020 in parallel with T021 after T004
- T024 and T029 in parallel with T025–T027 if files differ
- T030/T031/T032 in parallel with US2 implementation if the switches only bind notifiers
- T036–T038 docs in parallel during polish

---

## Parallel Example: User Story 1

```bash
# After Phase 2:
Task: "transcript_line_tile_nested_inert_test.dart both settings off"
Task: "confirm no G2P / no new Player() in transcript + player"
```

---

## Parallel Example: User Story 2

```bash
# After T005 IPA helper exists:
Task: "transcript_word_ipa_test.dart"
Task: "transcript_word_ipa_layer.dart"
# Then tile stack (same file as US3 — one owner)
```

---

## Parallel Example: User Story 5

```bash
# After T006/T007 notifiers exist:
Task: "ipa_overlay_settings_test.dart + word_practice_settings_test.dart"
Task: "ARB strings in app_en.arb / app_zh.arb / app_zh_CN.arb"
Task: "settings_search_entry_test.dart + settings_screen_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Nested cues still look line-level when both settings are off; existing transcript tests green
5. This MVP is safe as a no-behavior-change **but does not ship overlay or word tap** — continue US2–US5 before calling slice 5 done

### Incremental Delivery

1. Setup + Foundational → keys, helpers, notifiers, gated word index, hydrate, inert pins
2. US1 → default panel unchanged → merge-safe
3. US2 → opt-in stored IPA annotation
4. US3 → opt-in seek-to-word on non-selectable rows
5. US4 → word loop + inspect sheet
6. US5 → Settings rows + blur/echo/lookup/karaoke coexistence
7. Polish → ADR-0075 + transcript docs + CI gates

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Developer A: US1–US4 tile/overlay/hit-test/loop/inspect (owns `transcript_line_tile.dart`, IPA layer, session, enforcer)
3. Developer B: US5 Settings section + ARB + registry tests (owns settings presentation; must not import `forced_alignment`)
4. Developer C: docs + ADR-0075 (T036–T038)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to spec user stories US1–US5
- Do not generate IPA for line-only captions (remaining #527 G2P)
- Do not add play-time alignment, YouTube demux, library backfill, or phone-level karaoke
- Do not change `kPositionBucketDisplayMs` (Windows a11y)
- Do not import `package:forced_alignment/` from transcript, settings, player, or l10n
- Do not rewrite ADR-0070–0074
- Overlay and practice MUST NOT auto-reveal blurred cues or leak IPA through blur
- Lookup payload MUST exclude IPA
- Isolated widget tests: override new settings notifiers to off (karaoke lesson: do not default a gate to false while SettingsDao loads)
- Verify off-path tests fail if IPA or word seek leaks before wiring
- Commit after each task or logical group (setup, foundation, US1, US2, US3, US4, US5, polish)
- Avoid: `print()`, new `media_kit` `Player()`, Flutter web
