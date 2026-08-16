# Implementation Plan: Word-Level Practice

**Branch**: `041-word-level-practice` | **Date**: 2026-08-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/041-word-level-practice/spec.md`

**Note**: `/speckit-clarify` was skipped; defaults locked in [research.md](./research.md) (two independent Settings toggles; IPA is an annotation layer on stored phones; seek-to-word via plain-text hit-test on non-selectable rows; ephemeral word loop; inspect via Enjoy adaptive sheet). Git working tree may still be `040-karaoke-word-highlight` — implement on a dedicated `041-word-level-practice` branch, not in PR #559.

## Summary

Slice 5 of issue #540, absorbing stored-phone **display** from #527: two default-**off** Settings toggles. **IPA overlay** (`transcript.ipaOverlay`) paints stored pronunciation with each eligible primary-line word. **Word-level practice** (`transcript.wordPractice`) lets learners seek/loop/inspect timed words. Lookup stays on selectable (active/echo) rows. Karaoke (slice 4) and Craft enrichment (slice 3) stay independent. No alignment, no G2P, no library rewrite. ADR-0075; update `docs/features/transcript.md`.

## Technical Context

**Language/Version**: Dart 3.x / Flutter (stable channel per repo)

**Primary Dependencies**: Existing `TranscriptLine.timeline` / `TranscriptPhone`. Riverpod SettingsDao notifiers mirroring `KaraokeHighlightSettings` (awaited load; loading ≠ off). `currentWordIndex` / `wordHighlightRange` (extend, do not fork). `PlayerInteractions` / `PlayerController.seekToSeconds` / `EchoEnforcer`. `showEnjoyAdaptiveSheet` (ADR-0065). Transcript markup + blur. Settings hub registry (spec 004). ARB / `flutter gen-l10n`. **Not** `package:forced_alignment/`. **Not** a new `media_kit` `Player()`.

**Storage**: No new Drift table. Two SettingsDao keys `transcript.ipaOverlay` and `transcript.wordPractice` (`'true'`/`'false'`, missing ≡ off). Nested words/phones already in `transcripts.timeline_json`. Word loop and chosen word are **session-ephemeral** (not `SessionDao`).

**Testing**: Unit tests for IPA spelling concat, word-at-offset, word media window, word-loop wrap vs cancel. Widget tests: both off = nested inert (existing pin); overlay on = IPA visible but absent from selection/plain/lookup; practice on = non-selectable word tap seeks, selectable tap does not; loop does not rewrite echo; blur does not leak IPA or auto-reveal. Settings registry rows. `flutter analyze`; `dart run build_runner build` after `@Riverpod`; `flutter gen-l10n`; `bash .github/scripts/validate_ci_gates.sh --fix`.

**Target Platform**: Android, iOS, macOS, Windows, Linux (no web)

**Project Type**: Cross-platform Flutter app

**Performance Goals**: Typical enriched item (≤60 s, ≤100 lines) at 1×: transcript stays scrollable; current-line tracking unchanged. IPA annotation is layout-time per visible tile (not 50 ms). Only karaoke and current-word practice chrome subscribe to the **50 ms** karaoke position bucket; do **not** change `kPositionBucketDisplayMs = 400`. Word seek feels immediate (no wait for next line change) (SC-011).

**Constraints**: No `print()`; no new `media_kit` `Player()`; no Flutter web; no play-time alignment or IPA generation; no library rewrite; no `cueIdFor` change; transcript/settings/player/l10n MUST NOT import `forced_alignment`. Overlay and practice MUST NOT auto-reveal blurred cues or leak IPA through blur. Independent of `transcript.timelineEnrichment` and `transcript.karaokeHighlight`. Lookup text is never IPA.

**Scale/Scope**: Two Settings rows, two bool notifiers, pure helpers (IPA string, hit-test, media window), overlay annotation on tiles, word tap + loop enforcer + inspect sheet, ADR-0075, transcript (+ Settings search) docs. No Worker, no Craft save changes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Plan response |
|-----------|--------|---------------|
| I. Architecture | Pass | Pure helpers in `lib/data/subtitle`. Setting notifiers in settings application. Overlay + hit-test in transcript presentation. Word loop notifier in transcript application; enforcement next to `EchoEnforcer` in player application (justified: only `PlayerController` may seek). Persistence via `SettingsDao`. No transcript→Craft/ASR/`forced_alignment` imports. |
| II. Testing | Pass | Matcher/IPA/hit-test/loop unit tests; tile widget tests (off/on/incomplete/selectable); settings registry; blur + lookup coexistence; nested-inert pin remains off-path. |
| III. UX consistency | Pass | Two `SettingsRow` + `Switch.adaptive` in Transcript. ARB strings. `EnjoyTappableIcon` + tooltips for loop/inspect. Inspect via `showEnjoyAdaptiveSheet`. `Haptics` on word seek. No new chip row replacing the line. |
| IV. Performance | Pass | Overlay does not watch the 50 ms bucket. Active-tile current-word chrome shares karaoke bucket only when practice or karaoke is on. Hit-test is per tap, not per tick. |
| V. Documentation | Pass | ADR-0075; `docs/features/transcript.md`; Settings search copy. ADR-0070–0074 left intact. |
| Flutter Quality Gates | Pass | format + codegen + analyze + test; no web; no new `Player()`; `build_runner` for new notifiers; `flutter gen-l10n` |

**Post-design re-check**: Pass — contracts keep line identity, writers line-only, overlay/practice independent of karaoke and enrichment, lookup text excludes IPA, blur/echo unchanged except word-loop tick priority. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/041-word-level-practice/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── README.md
│   ├── settings-toggles.md
│   ├── ipa-overlay.md
│   ├── word-hit-test.md
│   ├── word-loop.md
│   ├── phone-inspect.md
│   ├── practice-modes.md
│   └── writers.md
└── tasks.md             # /speckit-tasks (not this command)
```

### Source Code (repository root)

```text
lib/data/db/settings_keys.dart
lib/data/subtitle/current_transcript_word.dart   # + all word ranges, offset→index, media window
lib/data/subtitle/transcript_word_ipa.dart       # stored-phone spelling concat
lib/features/settings/application/
  ipa_overlay_settings.dart                      # @Riverpod SettingsDao bool
  word_practice_settings.dart                    # @Riverpod SettingsDao bool
lib/features/settings/domain/settings_search_entry.dart
lib/features/settings/presentation/widgets/sections/transcript_section.dart
lib/features/transcript/application/
  active_cue_word_index_provider.dart            # karaoke OR practice gate
  word_loop_controller.dart                      # ephemeral loop state
  karaoke_word_index_provider.dart               # keep karaoke paint gate
lib/features/player/application/
  word_loop_enforcer.dart                        # wrap seek; skip echo rewind while looping
  player_position_tracker.dart                   # tick word loop before echo
  player_interactions.dart                       # seekToWord
lib/features/transcript/presentation/
  transcript_panel.dart                          # hydrate both settings
  transcript_line_tile.dart                      # overlay layer, word tap, practice icons
  transcript_word_ipa_layer.dart                 # IgnorePointer IPA annotation
  word_phone_inspect_sheet.dart                  # Enjoy adaptive sheet
lib/l10n/*.arb
test/data/subtitle/…
test/features/transcript/…
test/features/settings/…
test/features/player/…                           # word loop vs echo
docs/decisions/0075-word-level-practice.md
docs/features/transcript.md
```

**Structure Decision**: Do not add a new feature module. Settings owns the two persisted bools (same as karaoke/enrichment). Transcript owns overlay paint, hit-test, inspect UI, and loop **state**. Player owns loop **enforcement** (single `Player()`). Shared matching stays in `lib/data/subtitle`.

## Complexity Tracking

> None. No constitution violations.
