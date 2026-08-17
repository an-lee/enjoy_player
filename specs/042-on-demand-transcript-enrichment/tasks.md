# Tasks: On-Demand Transcript Enrichment

**Input**: Design documents from `specs/042-on-demand-transcript-enrichment/`

**Note**: Slice 6 of issue #540. Gate karaoke/IPA on nested data + extractability; explicit CC-sheet enrich; owned media `alignSegments`; YouTube eSpeak IPA-only untimed words. See [plan.md](./plan.md), [research.md](./research.md). ADR-0078 is written in polish. Implement on git branch `042-on-demand-transcript-enrichment`.

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required for changed contracts (constitution + plan + spec independent tests). Manual checks per [quickstart.md](./quickstart.md) §§A–D.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **JSON / clocks**: `lib/data/subtitle/transcript_line.dart`, `lib/data/subtitle/current_transcript_word.dart`
- **Gating / language**: `lib/data/subtitle/transcript_display_readiness.dart`, `lib/data/subtitle/alignment_language.dart`
- **Mappers**: `lib/data/subtitle/attach_alignment_to_lines.dart`, `lib/data/subtitle/attach_phonemes_to_lines.dart`
- **PCM**: `lib/data/audio/pcm16k_mono.dart`
- **Package**: `packages/forced_alignment/lib/src/phonemize.dart`, `packages/forced_alignment/lib/forced_alignment.dart`
- **Enricher**: `lib/features/transcript/application/transcript_enrichment_controller.dart`, `lib/features/transcript/data/transcript_repository.dart`
- **Karaoke gate**: `lib/features/transcript/application/karaoke_word_index_provider.dart`
- **CC sheet**: `lib/features/transcript/presentation/transcript_display_settings_sheet.dart`, `lib/features/transcript/presentation/subtitle_track_picker_sheet.dart`
- **ARB**: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_CN.arb`
- **Pins**: `test/features/alignment/forced_alignment_inert_import_test.dart`, `test/features/transcript/subtitle_track_picker_sheet_test.dart`
- **Docs**: `docs/decisions/0078-on-demand-transcript-enrichment.md`, `docs/features/transcript.md`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Dedicated feature branch on a tree that already has karaoke + IPA overlay (ADR-0074/0076)

- [X] T001 Create git branch `042-on-demand-transcript-enrichment` from current `main` (or the branch that already contains ADR-0076 stacked IPA / CC-sheet switches)
- [X] T002 Confirm `TranscriptWord` / `TranscriptPhone` in `lib/data/subtitle/transcript_line.dart`, `currentWordIndex` / `wordMediaWindowMs` in `lib/data/subtitle/current_transcript_word.dart`, `attachAlignmentToLines` in `lib/data/subtitle/attach_alignment_to_lines.dart`, `EspeakSynthHost` in `packages/forced_alignment/lib/src/synth/espeak_synth_host.dart`, `CraftTimelineEnricher` in `lib/features/craft/application/craft_timeline_enricher.dart`, `SubtitleToggleTile` in `lib/features/transcript/presentation/subtitle_track_picker_primitives.dart`, and `TranscriptBusyListTile` in `lib/features/transcript/presentation/transcript_busy_action.dart`. Do **not** import `lib/features/asr` or `lib/features/craft` from transcript

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Optional JSON clocks, shared language map, pure display-readiness, in-place `replaceTimeline`, idle enricher notifier. Stories then add gating UI, owned align, and YouTube phonemize without a second storage shape

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 [P] Extend `test/data/subtitle/transcript_line_test.dart` so untimed words omit `start`/`duration`, untimed phones omit `startTime`/`endTime`, missing clocks parse as null, explicit `duration: 0` stays untimed for matching, and timed Craft fixtures still round-trip numbers per [contracts/optional-word-times.md](./contracts/optional-word-times.md)
- [X] T004 Make `TranscriptWord.startMs`/`durationMs` and `TranscriptPhone.startTime`/`endTime` nullable in `lib/data/subtitle/transcript_line.dart`; `toJson` omits null clocks; `fromJson` missing → null (do not default word duration to `0` on omit)
- [X] T005 Treat null `durationMs` as untimed in `lib/data/subtitle/current_transcript_word.dart` (`currentWordIndex`, `wordMediaWindowMs`) and extend `test/data/subtitle/current_transcript_word_test.dart`
- [X] T006 [P] Lift `alignmentLanguageForCraft` from `lib/features/craft/application/craft_timeline_enricher.dart` into `lib/data/subtitle/alignment_language.dart` as `alignmentLanguageForTranscript`; point Craft at the shared helper; keep fail-closed (no English swap)
- [X] T007 [P] Add pure `TranscriptDisplayReadiness` in `lib/data/subtitle/transcript_display_readiness.dart` plus `test/data/subtitle/transcript_display_readiness_test.dart` per [data-model.md](./data-model.md) and [contracts/display-gating.md](./contracts/display-gating.md) (`hasNestedWords`, `hasTimedWords`, `hasPhones`, `canTrustWordTimes`, `karaokeSwitchEnabled`, `ipaSwitchEnabled`, `showEnrich`; no Flutter)
- [X] T008 Add `TranscriptRepository.replaceTimeline` in `lib/features/transcript/data/transcript_repository.dart` (same id/source/language/label; rewrite `timelineJson` + `updatedAt`; invalidate lines cache) and a unit test under `test/features/transcript/` per [contracts/writers.md](./contracts/writers.md)
- [X] T009 Add keep-alive `@Riverpod` `TranscriptEnrichmentController` in `lib/features/transcript/application/transcript_enrichment_controller.dart` with idle/running/failed/succeeded, `cancel()`, and **no** work in `build()` (must not enrich on open/play/seek). Run `dart run build_runner build` and commit `transcript_enrichment_controller.g.dart`. Presentation must not import `package:forced_alignment/`
- [X] T010 Keep `test/features/alignment/forced_alignment_inert_import_test.dart` green for **presentation**, settings, player, ASR, lookup, l10n. Application enricher is still allowed to stay import-free until US2/US3. Confirm Craft save tests in `test/features/craft/` still pass

**Checkpoint**: App analyzes; optional clocks round-trip; readiness is pure; enricher exists but does nothing until a story calls `run`

---

## Phase 3: User Story 1 - Switches follow nested words; missing data offers enrich (Priority: P1) 🎯 MVP

**Goal**: Line-only primary tracks disable karaoke and IPA and show an enrich tile. Already-timed owned items keep switches enabled and hide enrich. Preferences are not wiped. Opening the sheet does not start enrich.

**Independent Test**: Open a line-only local item and a line-only YouTube item — both switches disabled, enrich visible, panel line-level. Open an enriched Craft item — karaoke/IPA enabled (if phones exist), enrich hidden ([spec.md](./spec.md) US1, [quickstart.md](./quickstart.md) §A).

### Tests for User Story 1

- [X] T011 [P] [US1] Extend `test/features/transcript/subtitle_track_picker_sheet_test.dart` (or add `test/features/transcript/transcript_display_gating_test.dart`): line-only lines → karaoke/IPA `onChanged == null` and enrich tile present; timed+phones+owned → switches enabled, enrich absent; preference `true` on line-only still shows switches off/disabled without writing SettingsDao false

### Implementation for User Story 1

- [X] T012 [P] [US1] Add enrich + gated-hint ARB keys in `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, and `lib/l10n/app_zh_CN.arb` per [contracts/enrich-control.md](./contracts/enrich-control.md) (owned vs YouTube title/subtitle; karaoke unavailable on YouTube; replace `transcriptIpaUnavailableHint` so it no longer says Craft-only). Run `flutter gen-l10n`
- [X] T013 [US1] Change `TranscriptDisplaySettingsSection` in `lib/features/transcript/presentation/transcript_display_settings_sheet.dart` to take `TranscriptDisplayReadiness` (not only `hasPhones`): switch value = `preference && capability`; `onChanged` null when gated; `TranscriptBusyListTile` enrich when `showEnrich`; busy/cancel/error from `transcriptEnrichmentControllerProvider`. Do not import `forced_alignment`
- [X] T014 [US1] Compute readiness in `lib/features/transcript/presentation/subtitle_track_picker_sheet.dart` from primary lines + YouTube/local-file extractability (`videoRowForMediaProvider`) and pass it into the display section. Empty/no lines → switches disabled, enrich hidden
- [X] T015 [US1] Gate paint in `lib/features/transcript/application/karaoke_word_index_provider.dart`: return null unless preference **and** `karaokeSwitchEnabled` (YouTube / untimed → 0 highlights even if preference is on). Do not change `kPositionBucketDisplayMs`
- [X] T016 [US1] Wire enrich tile `onTap` to `TranscriptEnrichmentController.run` / `cancel` only (no auto-start from panel, playback, seek, or switch toggles) in `lib/features/transcript/presentation/transcript_display_settings_sheet.dart`

**Checkpoint**: US1 MVP — gated switches + visible enrich tile; generate may still fail closed until US2/US3 fill `run`

---

## Phase 4: User Story 2 - Owned media: enrich produces timed words and IPA (Priority: P1)

**Goal**: On extractable local/Craft audio, enrich runs `alignSegments`, persists timed words + phones in place, then karaoke and IPA become enableable without restart.

**Independent Test**: Short local line-only item, supported language, tap enrich. Lines unchanged; nested timed words + phones; switches enable; karaoke/tap-IPA work ([spec.md](./spec.md) US2, [quickstart.md](./quickstart.md) §B).

### Tests for User Story 2

- [X] T017 [P] [US2] Add `test/data/audio/pcm16k_file_decode_test.dart` (or extend `test/data/audio/pcm16k_mono_test.dart`) for `decodeFileToPcm16kMono` / windowed extract failure when path missing; do **not** import `lib/features/asr`
- [X] T018 [P] [US2] Add `test/features/transcript/application/transcript_enrichment_owned_test.dart`: inject fake PCM + `alignSegments` success → `replaceTimeline` with timed words/phones and unchanged line identity; unsupported language / extract fail / cancel → original JSON; `build()` does not start work

### Implementation for User Story 2

- [X] T019 [US2] Add `decodeFileToPcm16kMono` and per-window extract (`-ss`/`-t` + pad) in `lib/data/audio/pcm16k_mono.dart` per [contracts/owned-media-align.md](./contracts/owned-media-align.md). Never call this for YouTube URLs
- [X] T020 [US2] Implement owned branch of `run` in `lib/features/transcript/application/transcript_enrichment_controller.dart`: language via `alignmentLanguageForTranscript`; last cue end ≤ ~90 s → whole-file PCM + `alignSegments`; longer → per-cue window + `align()`; map with `attachAlignmentToLines`; persist via `replaceTimeline`. Fail closed. No Craft/ASR imports. Transcript **application** MAY import `package:forced_alignment/`
- [X] T021 [US2] Update `test/features/alignment/forced_alignment_inert_import_test.dart` so `lib/features/transcript/application` may import `forced_alignment`, but `lib/features/transcript/presentation`, settings, player, ASR, lookup, and l10n still must not
- [X] T022 [US2] After successful owned enrich, CC sheet switches recompute from new lines without restart (readiness in `lib/features/transcript/presentation/subtitle_track_picker_sheet.dart` watches lines stream). Confirm `test/features/craft/application/craft_timeline_enricher_test.dart` unchanged

**Checkpoint**: Owned line-only captions can become karaoke+IPA capable via the button

---

## Phase 5: User Story 3 - YouTube: IPA without karaoke (Priority: P1)

**Goal**: Non-extractable items keep karaoke disabled. Enrich phonemizes caption text, stores untimed words + IPA labels, enables IPA only. No YouTube demux. Tap IPA does not seek.

**Independent Test**: YouTube line-only captions → karaoke off, enrich, then IPA on, karaoke still off, no usable word windows, IPA tap does not seek ([spec.md](./spec.md) US3, [quickstart.md](./quickstart.md) §C).

### Tests for User Story 3

- [X] T023 [P] [US3] Add `packages/forced_alignment/test/phonemize_test.dart`: `phonemize` / `phonemizeLines` returns token + IPA labels without source-audio times; unsupported language / cancel fail closed; skip native if `espeakFfiIsAvailable()` is false
- [X] T024 [P] [US3] Add `test/data/subtitle/attach_phonemes_to_lines_test.dart`: line text/start/duration unchanged; words omit clocks; phones have labels; `wordMediaWindowMs` null
- [X] T025 [P] [US3] Add `test/features/transcript/application/transcript_enrichment_youtube_test.dart`: YouTube/non-extractable `run` never calls PCM/FFmpeg helpers; persist untimed words; karaoke readiness stays false; IPA readiness true when labels exist

### Implementation for User Story 3

- [X] T026 [US3] Add `phonemize` / `phonemizeLines` in `packages/forced_alignment/lib/src/phonemize.dart` using `EspeakSynthHost.synthesize` (discard PCM) and export from `packages/forced_alignment/lib/forced_alignment.dart`. Cancel between lines. Do not call `align` / `alignSegments`
- [X] T027 [US3] Add `attachPhonemesToLines` in `lib/data/subtitle/attach_phonemes_to_lines.dart` (untimed `TranscriptWord` + label-only `TranscriptPhone` per [contracts/youtube-ipa-only.md](./contracts/youtube-ipa-only.md) / [optional-word-times.md](./contracts/optional-word-times.md)). No dummy equal-split durations
- [X] T028 [US3] Implement non-extractable branch of `run` in `lib/features/transcript/application/transcript_enrichment_controller.dart`: YouTube/remote-without-file → phonemize only; never FFmpeg the media URL; persist via `replaceTimeline`
- [X] T029 [US3] Confirm IPA overlay in `lib/features/transcript/presentation/transcript_line_tile.dart` shows labels on untimed words and `_onIpaTap` stays a no-op when `wordMediaWindowMs` is null. Add/extend `test/features/transcript/transcript_ipa_overlay_test.dart` (or a dedicated untimed-IPA widget test)
- [X] T030 [US3] Use YouTube-specific ARB copy on the enrich tile when `canTrustWordTimes` is false in `lib/features/transcript/presentation/transcript_display_settings_sheet.dart`

**Checkpoint**: YouTube can show IPA without karaoke or a local copy of the video

---

## Phase 6: User Story 4 - Partial data, mixed library, and safe degradation (Priority: P1)

**Goal**: Controls follow this primary track and media type. Incomplete nested data never blanks a line. Enrich is not required once this media type’s nested data exists. Empty tracks do not fake capability.

**Independent Test**: Cycle enriched Craft, line-only import, YouTube after IPA-only, words with zero/omitted duration ([spec.md](./spec.md) US4, [quickstart.md](./quickstart.md) §D).

### Tests for User Story 4

- [X] T031 [P] [US4] Extend `test/data/subtitle/transcript_display_readiness_test.dart`: nested untimed words → karaoke off, IPA on if phones; nested words without phones → IPA off, karaoke on only if timed+owned; empty lines → no enrich; already nested → `showEnrich` false
- [X] T032 [P] [US4] Extend `test/features/transcript/application/transcript_enrichment_owned_test.dart` (or youtube test) for partial long-file success: some cues nested, some line-only, track still loads; cancel mid-run leaves captions playable

### Implementation for User Story 4

- [X] T033 [US4] Honor partial attach in `lib/features/transcript/application/transcript_enrichment_controller.dart` (failed cues stay line-only; do not blank the track). Retry from failed state without blocking playback
- [X] T034 [US4] Keep echo, lookup, blur, auto-translate, and line tap-to-seek on line fields in `lib/features/transcript/presentation/transcript_line_tile.dart` after enrich (no `cueIdFor` change). Pin with existing transcript regression tests
- [X] T035 [US4] Confirm secondary/translation lines are not enriched and get no karaoke/IPA/enrich in `lib/features/transcript/presentation/subtitle_track_picker_sheet.dart` (primary-only)

**Checkpoint**: Mixed library degrades per cue; preferences survive gated items

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: ADR, feature docs, quality gates, import pins

- [X] T036 [P] Add `docs/decisions/0078-on-demand-transcript-enrichment.md` (gated switches, explicit enrich, YouTube IPA-only untimed words, optional clocks, no demux) and link it from `docs/decisions/README.md`. Supplement ADR-0070; supersede ADR-0076’s “no generate path / Craft-only phones” for this button only. Do not rewrite ADR-0070–0076 bodies
- [X] T037 [P] Update `docs/features/transcript.md` for gated CC-sheet switches, enrich tile, owned vs YouTube outcomes, optional word times
- [X] T038 Confirm `test/features/alignment/forced_alignment_inert_import_test.dart` plus Craft/import/YouTube/ASR writer tests: those writers stay line-only until the learner taps enrich; no first-play align
- [X] T039 Run `dart format` on `lib`, `test`, and `packages/forced_alignment`; `flutter analyze`; targeted tests from [quickstart.md](./quickstart.md); then `bash .github/scripts/validate_ci_gates.sh --fix`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — **BLOCKS** all user stories
- **User Story 1 (Phase 3)**: After Foundational — MVP gating + enrich tile
- **User Story 2 (Phase 4)**: After Foundational; should follow US1 so the tile can actually generate on owned media
- **User Story 3 (Phase 5)**: After Foundational; can proceed after US1 in parallel with US2 if staffed (different files: `phonemize.dart` / `attach_phonemes_to_lines.dart` vs PCM / owned `run` branch — merge `transcript_enrichment_controller.dart` carefully)
- **User Story 4 (Phase 6)**: After US2 and US3 (needs both persist paths)
- **Polish (Phase 7)**: After desired stories

### User Story Dependencies

- **US1**: No story dependencies after Phase 2. Enrich `run` may still fail closed
- **US2**: Needs US1 tile + Phase 2 `replaceTimeline` / controller
- **US3**: Needs US1 tile + Phase 2 controller; independent of owned PCM except shared `run` method
- **US4**: Needs US2 + US3 persist behavior

### Within Each User Story

- Tests listed first should fail before implementation
- Models/helpers before controller branches
- Controller before sheet copy/behavior that depends on success
- Story complete before next priority unless parallelizing US2/US3

### Parallel Opportunities

- T003 / T006 / T007 in Phase 2 (different files)
- T011 / T012 in US1
- T017 / T018 in US2
- T023 / T024 / T025 in US3
- T031 / T032 in US4
- T036 / T037 in polish
- US2 and US3 after US1 if two people split owned vs YouTube files

---

## Parallel Example: User Story 3

```bash
# Tests together:
Task: "phonemize_test.dart in packages/forced_alignment/test/"
Task: "attach_phonemes_to_lines_test.dart in test/data/subtitle/"
Task: "transcript_enrichment_youtube_test.dart in test/features/transcript/application/"

# Then implementation:
Task: "phonemize.dart + barrel export"
Task: "attach_phonemes_to_lines.dart"
Task: "YouTube branch of transcript_enrichment_controller.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Line-only vs enriched Craft gating in the CC sheet ([quickstart.md](./quickstart.md) §A)
5. Demo gated switches even if Generate still fail-closes

### Incremental Delivery

1. Setup + Foundational → clocks, readiness, idle controller
2. US1 → gated UI + enrich tile (MVP)
3. US2 → owned timed enrich
4. US3 → YouTube IPA-only
5. US4 → partial/mixed edges
6. Polish → ADR-0078 + docs + CI gates

### Parallel Team Strategy

1. Team completes Setup + Foundational
2. Then: Developer A US1 → US4 edges; Developer B US2 owned; Developer C US3 YouTube (`phonemize` + mapper first, then share controller)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to spec US1–US4
- Presentation/settings/l10n never import `package:forced_alignment/`
- Transcript never imports Craft or ASR
- No YouTube demux, no fake word clocks, no first-play enrich
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at checkpoints to validate the story independently
