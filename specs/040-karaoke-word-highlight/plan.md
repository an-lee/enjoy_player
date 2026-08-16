# Implementation Plan: Karaoke Word Highlight

**Branch**: `040-karaoke-word-highlight` | **Date**: 2026-08-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/040-karaoke-word-highlight/spec.md`

**Note**: `/speckit-clarify` was skipped; defaults locked in [research.md](./research.md) (Settings Transcript display toggle independent of Craft enrichment, in-place highlight, 50 ms karaoke position bucket, no IPA / per-word tap).

## Summary

Slice 4 of issue #540: first **transcript-panel consumer** of stored word timings. A default-**off** Settings toggle (`transcript.karaokeHighlight`) highlights the current word in place on the primary line while media plays, when that cue already has timed words (typically Craft items from slice 3). Line-level current-cue, tap-to-seek, echo, lookup, blur, and auto-translate stay on line fields. No alignment at play time. No IPA overlay. ADR-0074; update `docs/features/transcript.md`.

## Technical Context

**Language/Version**: Dart 3.x / Flutter (stable channel per repo)

**Primary Dependencies**: Existing `TranscriptLine.timeline` (`TranscriptWord.startMs` / `durationMs` relative to the line). Riverpod (`displayPositionProvider` pattern, SettingsDao notifier like `timelineEnrichmentSettingsProvider`). Transcript markup (`transcriptMarkupToTextSpan`). Settings hub registry (spec 004). ARB / `flutter gen-l10n`. **Not** `package:forced_alignment/`.

**Storage**: No new Drift table. One SettingsDao key `transcript.karaokeHighlight` (`'true'`/`'false'`, missing ≡ off). Nested word times already in `transcripts.timeline_json`.

**Testing**: Unit tests for current-word matching and plain-text range mapping. Widget tests: karaoke off = nested inert (existing pin); karaoke on = in-place highlight, no IPA text, no word chips. Settings registry row. Blur does not auto-reveal. `flutter analyze`; `dart run build_runner build` after `@Riverpod`; `flutter gen-l10n`; `bash .github/scripts/validate_ci_gates.sh --fix`.

**Target Platform**: Android, iOS, macOS, Windows, Linux (no web)

**Project Type**: Cross-platform Flutter app

**Performance Goals**: Typical enriched item (≤60 s, ≤100 lines) at 1×: transcript stays scrollable; current-line tracking unchanged. Only the **active** cue tile rebuilds when the current word index changes. Karaoke position uses a **50 ms** bucket (same family as the scrubber); do **not** tighten the 400 ms display bucket (Windows a11y — `flutter/flutter#182444`). Highlight must not trail a full word behind (SC-008).

**Constraints**: No `print()`; no new `media_kit` `Player()`; no Flutter web; no play-time alignment; no library rewrite; no `cueIdFor` change; transcript/settings MUST NOT import `forced_alignment`. Karaoke MUST NOT auto-reveal blurred cues. Independent of `transcript.timelineEnrichment`.

**Scale/Scope**: One Settings row, one bool notifier, one pure matcher, one karaoke position provider, tile/markup paint path, ADR-0074, transcript (+ Settings search) docs. No Worker, no Craft save changes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Plan response |
|-----------|--------|---------------|
| I. Architecture | Pass | Matcher in `lib/data/subtitle` (UI-free). Setting notifier in settings application. Karaoke index provider + tile paint in transcript. Persistence via `SettingsDao`. No transcript→Craft/ASR/`forced_alignment` imports. |
| II. Testing | Pass | Matcher unit tests, tile widget tests (off/on/incomplete), settings registry, blur coexistence, existing nested-inert pin retargeted (off remains inert). |
| III. UX consistency | Pass | Second `SettingsRow` + `Switch.adaptive` in existing Transcript section. ARB strings. In-place text, not new chips. `EnjoyTappableSurface` unchanged (line tap still line-level). |
| IV. Performance | Pass | 50 ms karaoke bucket subscribed only by the word-index provider; list still uses 400 ms line highlight. Active tile `.select`s word index. No per-tick work in list `itemBuilder` for inactive rows. |
| V. Documentation | Pass | ADR-0074; `docs/features/transcript.md`; Settings search copy. ADR-0070–0073 left intact. |
| Flutter Quality Gates | Pass | format + codegen + analyze + test; no web; no new `Player()`; `build_runner` for setting + karaoke providers; `flutter gen-l10n` |

**Post-design re-check**: Pass — contracts keep line identity, writers line-only, karaoke independent of enrichment, blur/echo/lookup unchanged. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/040-karaoke-word-highlight/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── README.md
│   ├── settings-toggle.md
│   ├── current-word.md
│   ├── panel-render.md
│   ├── practice-modes.md
│   └── writers.md
└── tasks.md             # /speckit-tasks (not this command)
```

### Source Code (repository root)

```text
lib/data/db/settings_keys.dart                 # + transcriptKaraokeHighlight
lib/data/subtitle/current_transcript_word.dart # pure matcher + text ranges
lib/features/settings/application/
  karaoke_highlight_settings.dart              # @Riverpod SettingsDao bool
lib/features/settings/domain/settings_search_entry.dart
lib/features/settings/presentation/widgets/sections/transcript_section.dart
lib/features/transcript/application/
  karaoke_word_index_provider.dart             # mediaId → int? on current line
lib/features/player/application/position_buckets.dart  # + kPositionBucketKaraokeMs
lib/features/transcript/presentation/
  transcript_markup.dart                       # optional highlight range
  transcript_line_tile.dart                    # watch index when karaoke on
lib/l10n/*.arb
test/data/subtitle/current_transcript_word_test.dart
test/features/transcript/…                     # tile on/off, blur, nested inert
test/features/settings/…                       # registry + default off
docs/decisions/0074-karaoke-word-highlight.md
docs/features/transcript.md
```

**Structure Decision**: Do not add a new feature module. Settings owns the persisted bool (same as enrichment). Transcript owns playback consumption. Shared matching lives in `lib/data/subtitle` so tests stay UI-free. Player only gains a karaoke bucket constant; engines unchanged.

## Complexity Tracking

> None. No constitution violations.
