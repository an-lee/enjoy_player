# Tasks: Craft Timeline Enrichment

**Input**: Design documents from `specs/039-craft-timeline-enrichment/`

**Note**: Slice 3 of issue #540. First product caller of `packages/forced_alignment`: opt-in Craft save may store nested word/phone spans on spec 030 lines. Default remains today’s transcript. See [plan.md](./plan.md), [research.md](./research.md). ADR-0073 is written in polish. Stack this branch on `038-alignment-spoken-reference` if PR #556 is not merged.

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required for changed contracts (constitution + plan + spec independent tests). Manual checks per [quickstart.md](./quickstart.md) §§A–D.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Setting key**: `lib/data/db/settings_keys.dart`
- **Mapper**: `lib/data/subtitle/attach_alignment_to_lines.dart`
- **PCM**: `lib/data/audio/pcm16k_mono.dart`
- **Enricher**: `lib/features/craft/application/craft_timeline_enricher.dart`
- **Craft save**: `lib/features/craft/application/craft_controller.dart`
- **Setting notifier**: `lib/features/settings/application/timeline_enrichment_settings.dart`
- **Settings hub**: `lib/features/settings/domain/settings_search_entry.dart`, `lib/features/settings/presentation/widgets/`
- **ARB**: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_CN.arb`
- **Pins**: `test/features/alignment/forced_alignment_inert_import_test.dart`
- **Docs**: `docs/decisions/0073-craft-timeline-enrichment.md`, `docs/features/craft.md`, `docs/features/transcript.md`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Feature branch on top of spoken-reference alignment so Craft can call `alignSegments`

- [X] T001 Create git branch `039-craft-timeline-enrichment` from current `main`, or from `038-alignment-spoken-reference` if [PR #556](https://github.com/baizhiheizi/enjoy_player/pull/556) is not merged
- [X] T002 Confirm production `alignSegments` / `spokenReferenceUnavailable` / `EspeakSynthHost` exist in `packages/forced_alignment/lib/src/alignment_service.dart` and `packages/forced_alignment/lib/src/synth/` (slice 2b). Do **not** add a second path package or import `AsrAudioExtractor` from Craft

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Setting key (default off), pure mapper, PCM helper, and a Craft enricher that no-ops when the setting is off so stories can fill success/fallback/UI without a second save API

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 [P] Add `SettingsKeys.transcriptTimelineEnrichment = 'transcript.timelineEnrichment'` to the `_staticKeys` allowlist in `lib/data/db/settings_keys.dart` per [contracts/settings-toggle.md](./contracts/settings-toggle.md) (missing value ≡ off)
- [X] T004 [P] Implement `attachAlignmentToLines` in `lib/data/subtitle/attach_alignment_to_lines.dart` per [contracts/nested-mapping.md](./contracts/nested-mapping.md) and [data-model.md](./data-model.md) (segment `id` = line index; word ms relative to line; phones in media seconds; never change line text/start/duration)
- [X] T005 [P] Add `lib/data/audio/pcm16k_mono.dart` to turn Craft WAV/`Uint8List` into 16 kHz mono `Float32List` (decode PCM WAV in-process when possible; otherwise temp file + FFmpeg `pcm_s16le -ar 16000 -ac 1`). Do **not** import `lib/features/asr/`
- [X] T006 Add keep-alive `@Riverpod` notifier `TimelineEnrichmentSettings` in `lib/features/settings/application/timeline_enrichment_settings.dart` (read/write `SettingsDao` like `lib/core/diagnostics/diagnostics_verbose_provider.dart`); run `dart run build_runner build` and commit `timeline_enrichment_settings.g.dart`
- [X] T007 Add `lib/features/craft/application/craft_timeline_enricher.dart` that returns the spec 030 JSON unchanged when the setting is off, JSON is null, or the save is a dedupe skip per [contracts/craft-save-enrichment.md](./contracts/craft-save-enrichment.md) and [contracts/fallback.md](./contracts/fallback.md); log with `logNamed` (never `print()`)
- [X] T008 Retarget `test/features/alignment/forced_alignment_inert_import_test.dart` per [contracts/inert-consumers.md](./contracts/inert-consumers.md): **allow** `lib/features/craft`, `lib/data/subtitle`, `lib/data/audio` to import `package:forced_alignment/`; **forbid** transcript, player, ASR, lookup, Settings, l10n; **assert** `transcript.timelineEnrichment` exists in `lib/data/db/settings_keys.dart`

**Checkpoint**: App analyzes; setting defaults off; mapper/PCM/enricher compile; inert pins match the first-caller rules

---

## Phase 3: User Story 1 - Default off: Craft and library behave as today (Priority: P1) 🎯 MVP

**Goal**: With the setting at default (off), Craft save, blank-transcript path, library playback, and panel interactions match the pre-feature build. Learners never hear a spoken-reference voice.

**Independent Test**: Leave the switch off. Curated set from slices 1–2b (import, YouTube captions, speech-to-text, Craft synthesis, blank Craft). Line text/order/times unchanged. New Craft saves stay line-only or blank per spec 030 ([spec.md](./spec.md) US1, [quickstart.md](./quickstart.md) §A).

### Tests for User Story 1

> Write these tests FIRST, ensure they FAIL before the controller hook if save already writes nested spans

- [X] T009 [US1] Extend `test/features/craft/application/craft_controller_test.dart` (and/or `test/features/craft/application/craft_timeline_enricher_test.dart`): setting missing/off + solid word boundaries → `primaryTimelineJson` is line-only (no `timeline` arrays); blank 030 path still persists `null`

### Implementation for User Story 1

- [X] T010 [US1] Call the enricher from `lib/features/craft/application/craft_controller.dart` `saveToLibrary` **after** `buildCraftPrimaryTimelineJson` and **before** `importCraftedFromText` / `updateCraftedFromText`; skip on `wasDedupe`
- [X] T011 [P] [US1] Confirm no karaoke / IPA / per-word chips and no new `media_kit` `Player()` in `lib/features/transcript/` and `lib/features/player/`; Craft playback still uses `previewAudioBytes` / saved WAV, not reference PCM
- [X] T012 [US1] Run existing regression: `flutter test test/features/craft test/data/subtitle/transcript_line_test.dart test/features/transcript/transcript_repository_test.dart test/features/transcript/transcript_lines_provider_dedupe_test.dart test/features/transcript/auto_translate_controller_test.dart test/features/alignment`

**Checkpoint**: US1 MVP — default Craft/library behavior unchanged; enrichment API exists but is inert when off

---

## Phase 4: User Story 2 - Opt-in Craft save stores nested word and phone timings (Priority: P1)

**Goal**: With the setting on and extractable Craft audio, save attaches ordered word spans (and default-quality phones) onto the **same** spec 030 lines via `alignSegments`. Panel still shows line-level chrome.

**Independent Test**: Setting on. Short multi-line Craft item with solid synthesis timings. Reopen: line text/start/duration match spec 030; stored cues include word spans in order and at least one phone list; times on the parent line ±50 ms pad ([spec.md](./spec.md) US2, [quickstart.md](./quickstart.md) §B).

### Tests for User Story 2

- [X] T013 [P] [US2] Add `test/data/subtitle/attach_alignment_to_lines_test.dart`: two-line fixture keeps line fields; word ms relative to line; phones in seconds; `wordIndex` in range for **that** line; missing segment → that line stays line-only
- [X] T014 [P] [US2] Add `test/data/audio/pcm16k_mono_test.dart` for a tiny PCM WAV fixture → non-empty 16 kHz `Float32List` (skip or stub FFmpeg fallback if the runner has no binary)

### Implementation for User Story 2

- [X] T015 [US2] When the setting is on and JSON/PCM exist, `lib/features/craft/application/craft_timeline_enricher.dart` must call `alignSegments` with `AlignmentSegment(id: lineIndex, …)` and `AlignmentGranularity.medium`, then `attachAlignmentToLines` — do **not** call whole-clip `align()` or rewrite line text
- [X] T016 [US2] Extend `test/features/craft/application/craft_controller_test.dart` / `craft_timeline_enricher_test.dart`: setting on + injected spoken double (or FFI) → persisted JSON has `timeline` + `phones` on successful lines; line `text`/`start`/`duration` unchanged; audio bytes unchanged
- [X] T017 [US2] Confirm transcript panel tests still pass with a nested-cue fixture (line-level render only) via `flutter test test/features/transcript`

**Checkpoint**: Opt-in save can persist slice 1 nested JSON; UI still ignores it for chrome

---

## Phase 5: User Story 3 - Alignment failure keeps today’s Craft transcript (Priority: P1)

**Goal**: Setting on + spoken-reference unavailable, unsupported language, extract failure, cancel, or timeout → save still succeeds with spec 030 line-only (or blank) JSON. No fake nested timeline. No blocking `CraftSaveFailure`.

**Independent Test**: Drive each fallback class. Save completes. Transcript matches pre-feature Craft for that path. 0 nested spans from a stand-in ([spec.md](./spec.md) US3, [contracts/fallback.md](./contracts/fallback.md), [quickstart.md](./quickstart.md) §C).

### Tests for User Story 3

- [X] T018 [US3] Extend `test/features/craft/application/craft_timeline_enricher_test.dart`: setting on + `spokenReferenceUnavailable` / `unsupportedLanguage` / extract throw / timeout → original line-only JSON; save not `CraftSaveFailure`; 0 duration-model nested spans; blank 030 JSON stays `null` (do not invent lines)

### Implementation for User Story 3

- [X] T019 [US3] Map extract and `AlignmentFailed` outcomes to quiet fallback in `lib/features/craft/application/craft_timeline_enricher.dart` (`logNamed` warning, no learner-required error chrome) per [contracts/fallback.md](./contracts/fallback.md)
- [X] T020 [US3] Partial cue success: attach nested spans only on lines whose tagged segment succeeded; failed lines stay line-only; line fields unchanged — cover in `test/data/subtitle/attach_alignment_to_lines_test.dart` and the enricher test

**Checkpoint**: Slice 3 can trust fallback; Craft save is no more fragile than today

---

## Phase 6: User Story 4 - Setting is discoverable, persists, and does not rewrite the library (Priority: P1)

**Goal**: Settings → Transcript shows the switch, default off, persists without restart. Turning it on does not backfill old items. Import / YouTube / ASR stay line-only writers.

**Independent Test**: Fresh profile: switch off. Toggle survives relaunch. Pre-existing library cues unchanged until Craft re-save. Import/YouTube/ASR tracks remain line-only ([spec.md](./spec.md) US4, [quickstart.md](./quickstart.md) §D).

### Tests for User Story 4

- [X] T021 [P] [US4] Add `test/features/settings/application/timeline_enrichment_settings_test.dart`: missing key → false; `setEnabled(true)` round-trips via `SettingsDao`
- [X] T022 [P] [US4] Extend `test/features/settings/domain/settings_search_entry_test.dart` and hub tests (`test/features/settings/presentation/settings_screen_test.dart`, `test/features/settings/application/settings_section_collapse_provider_test.dart`) so the Transcript section / `timelineEnrichment` row is registered

### Implementation for User Story 4

- [X] T023 [P] [US4] Add ARB strings in `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, and `lib/l10n/app_zh_CN.arb` (section title/hint, switch title/subtitle, search keywords); run `flutter gen-l10n`
- [X] T024 [US4] Add `SettingsSectionIds.transcript` and registry descriptors in `lib/features/settings/domain/settings_search_entry.dart`; wire `lib/features/settings/application/settings_registry_localizer.dart`, `lib/features/settings/presentation/widgets/settings_section_visuals.dart`, `lib/features/settings/presentation/widgets/settings_layout_single_column.dart`, and `lib/features/settings/presentation/widgets/settings_layout_two_pane.dart`
- [X] T025 [US4] Add `lib/features/settings/presentation/widgets/sections/transcript_section.dart`: `SettingsRow` + `Switch.adaptive` bound to `timelineEnrichmentSettingsProvider` (diagnostics pattern); Settings Dart must **not** import `package:forced_alignment/`
- [X] T026 [US4] Pin inert writers: import / YouTube / ASR paths still omit nested `timeline` (existing tests under `test/features/` plus a note in `test/features/alignment/`); confirm dedupe in `test/features/craft/application/craft_controller_test.dart` does not rewrite the existing item when the setting is on

**Checkpoint**: Opt-in is visible and sticky; the rest of the library is untouched

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Traceability, docs, and CI gates

- [X] T027 [P] Write ADR-0073 in `docs/decisions/0073-craft-timeline-enrichment.md` (first product caller, default-off setting, spec 030 lines + `alignSegments`, fail-closed save, mapping rules, no karaoke / no reference playback). Do **not** rewrite ADR-0070–0072
- [X] T028 [P] Index ADR-0073 in `docs/decisions/README.md`
- [X] T029 [P] Update `docs/features/craft.md`: opt-in nested spans on save; fallback; blank 030 unchanged; audio still Azure/Craft WAV
- [X] T030 [P] Update `docs/features/transcript.md`: unused-engine note → Craft may persist nested JSON when the setting is on; panel still line-level; no karaoke in this slice
- [X] T031 Run `dart run build_runner build` and `flutter gen-l10n` if needed; commit `*.g.dart` / generated l10n
- [X] T032 Run [quickstart.md](./quickstart.md) automated checks: `flutter test test/features/craft test/features/alignment test/features/settings test/data/subtitle`, `flutter test packages/forced_alignment/test`, `flutter analyze`, `bash .github/scripts/validate_ci_gates.sh --fix` (do not mix unrelated format files). Document SC-008 if a platform is slower than 10 s for ≤60 s Craft enrichment

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately (needs slice 2b on the branch)
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **User Stories (Phase 3–6)**: All depend on Foundational
  - US1 can ship as a no-behavior-change MVP once the hook is inert when off
  - US2–US3 share `craft_timeline_enricher.dart` (implement success then fallback, or both in one pass)
  - US4 Settings chrome can start after T003/T006 (key + notifier) even in parallel with US2 if the switch only reads the bool
- **Polish (Phase 7)**: Depends on US1–US4

### User Story Dependencies

- **User Story 1 (P1)**: After Phase 2 — default-off hook
- **User Story 2 (P1)**: After Phase 2 — needs mapper + PCM + enricher; independently testable with a spoken test double
- **User Story 3 (P1)**: After US2’s `alignSegments` call exists (or the same enricher PR)
- **User Story 4 (P1)**: After T003/T006 — UI + registry; does not require a successful alignment to prove default off / persist / no backfill

### Within Each User Story

- Tests first where marked; confirm they fail before the hook writes nested JSON
- Mapper/PCM before enricher success path
- Enricher before Craft controller wiring (US1 can wire a no-op enricher first)
- Story complete before calling the slice done

### Parallel Opportunities

- T003, T004, T005 in parallel (different files)
- T013 and T014 in parallel
- T021/T022/T023 in parallel with US2 implementation if the switch only binds the notifier
- T027–T030 docs in parallel during polish

---

## Parallel Example: User Story 1

```bash
# After Phase 2:
Task: "craft_controller_test.dart setting-off line-only / blank"
Task: "confirm no karaoke / no new Player() in transcript + player"
```

---

## Parallel Example: User Story 2

```bash
# After Phase 2 mapper + PCM exist:
Task: "attach_alignment_to_lines_test.dart"
Task: "pcm16k_mono_test.dart"
# Then enricher + controller success path (same files as US3 — do not split across two people)
```

---

## Parallel Example: User Story 4

```bash
# After T006 notifier exists:
Task: "timeline_enrichment_settings_test.dart"
Task: "ARB strings in app_en.arb / app_zh.arb / app_zh_CN.arb"
Task: "settings_search_entry_test.dart + hub registry tests"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Craft save still line-only/blank; existing Craft/transcript tests green
5. This MVP is safe as a no-behavior-change **but does not ship nested Craft JSON** — continue US2–US4 before calling slice 3 done

### Incremental Delivery

1. Setup + Foundational → key, mapper, PCM, skip-when-off enricher, retargeted pins
2. US1 → default Craft/library unchanged → merge-safe
3. US2 → opt-in nested spans on save
4. US3 → fail-closed fallback
5. US4 → Settings Transcript switch + no library rewrite
6. Polish → ADR-0073 + craft/transcript docs + CI gates

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Developer A: US1 hook + US2/US3 enricher (owns `craft_timeline_enricher.dart` / `craft_controller.dart`)
3. Developer B: US4 Settings section + ARB + registry tests (owns settings presentation; must not import `forced_alignment`)
4. Developer C: mapper/PCM unit tests + docs (T004/T005/T013/T014/T027–T030)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to spec user stories US1–US4
- Do not add karaoke, IPA overlay, per-word tap, YouTube demux, library backfill, or first-play alignment
- Do not invent a transcript when spec 030 returns blank
- Do not import `AsrAudioExtractor` from Craft; do not import `TranscriptLine` into `packages/forced_alignment`
- Do not play the spoken reference or replace Craft playback audio
- Do not rewrite ADR-0070–0072
- Verify setting-off and fallback tests fail before wiring nested writes
- Commit after each task or logical group (setup, foundation, US1, US2, US3, US4, polish)
- Avoid: `print()`, new `media_kit` `Player()`, Flutter web, extra AI credits, blocking save errors on alignment failure
