# Implementation Plan: On-Demand Transcript Enrichment

**Branch**: `042-on-demand-transcript-enrichment` | **Date**: 2026-08-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/042-on-demand-transcript-enrichment/spec.md`

**Note**: `/speckit-clarify` was skipped; defaults locked in [research.md](./research.md) (explicit CC-sheet enrich, in-place primary write, eSpeak `phonemize` for YouTube IPA-only untimed words, `alignSegments` for owned media, omit JSON clocks when untimed, preferences stay global while switches gate per item).

## Summary

Slice 6 of issue #540: karaoke and IPA switches on the CC subtitle sheet follow **this** primary transcript’s nested data (and whether word times can be trusted). Line-only tracks disable both switches and show an **enrich** tile. Owned local/Craft media runs `alignSegments` and stores **timed** words + phones. YouTube / non-extractable media runs text-only eSpeak **phonemize** (no demux) and stores **untimed** words + IPA labels — IPA can turn on; karaoke stays off. ADR-0078; update `docs/features/transcript.md`. Craft save always-on enrichment is unchanged.

## Technical Context

**Language/Version**: Dart 3.x / Flutter (stable channel per repo)

**Primary Dependencies**: `packages/forced_alignment` (`align` / `alignSegments`, new `phonemize` via `EspeakSynthHost`). Existing `attachAlignmentToLines`, `currentWordIndex`, `wordMediaWindowMs`, `wordIpaSpelling`. Riverpod transcript + karaoke/IPA settings. FFmpeg file-path PCM in `lib/data/audio` (not ASR). ARB / `flutter gen-l10n`. **Not** a new `media_kit` `Player()`. **Not** Worker phonemizer.

**Storage**: No new Drift table. Nested spans in `transcripts.timeline_json` with optional word/phone clocks. Existing SettingsDao keys `transcript.karaokeHighlight` and `transcript.ipaOverlay`. Enrich run state is session-ephemeral.

**Testing**: Unit: JSON omit/parse clocks; display readiness; phonemize → untimed mapper; YouTube path never calls PCM extract. Widget: CC sheet gating + enrich tile; karaoke paint off on YouTube with preference on; IPA overlay on untimed words without seek. Repository `replaceTimeline` identity. Craft save pins unchanged. `flutter analyze`; `dart run build_runner build` after `@Riverpod`; `flutter gen-l10n`; `bash .github/scripts/validate_ci_gates.sh --fix`.

**Target Platform**: Android, iOS, macOS, Windows, Linux (no web)

**Project Type**: Cross-platform Flutter app + existing UI-free `forced_alignment` path package

**Performance Goals**: Owned ≤60 s: extract + `alignSegments` without blocking transport (same isolate split as Craft; fallback rather than hang). YouTube IPA-only ≤100 lines: **< 15 s** on a current mid-range device (SC-008) via eSpeak host isolate, cancel between lines. Karaoke still uses the 50 ms position bucket only when karaoke capability is on.

**Constraints**: No `print()`; no new `Player()`; no Flutter web; no YouTube download/demux; no fake word clocks; no first-play enrich; no library backfill; no `cueIdFor` change; presentation/settings/l10n MUST NOT import `forced_alignment`; transcript MUST NOT import Craft or ASR. Fail closed. Offline eSpeak; no extra credits.

**Scale/Scope**: Gating helpers + optional JSON clocks, `phonemize` API, file PCM helper, transcript enricher notifier, CC-sheet tile + ARB, `replaceTimeline`, ADR-0078, transcript.md. No Worker, no Settings hub row, no Craft save rewrite.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Plan response |
|-----------|--------|---------------|
| I. Architecture | Pass | Optional clocks + mappers + language helper + file PCM in `lib/data`. Enrich orchestration in transcript **application**. Presentation only talks to notifiers. Package stays UI-free. No transcript→Craft/ASR. Persistence via existing `TranscriptDao` / `SettingsDao`. |
| II. Testing | Pass | JSON/readiness/phonemize/gating unit tests; picker widget tests; karaoke YouTube pin; overlay untimed + no seek; repository in-place write; Craft pins stay green. |
| III. UX consistency | Pass | Switches stay `SubtitleToggleTile`; enrich is `TranscriptBusyListTile` in the same card. ARB for owned vs YouTube copy. No new Settings hub. `Haptics` not required on generate. Retry inline, not a blocking modal. |
| IV. Performance | Pass | eSpeak + DTW off UI isolate; per-line cancel; long local files per-cue extract not unbounded whole-file align; SC-008 15 s YouTube budget. |
| V. Documentation | Pass | ADR-0078; `docs/features/transcript.md`. ADR-0070–0076 left intact except 0076’s “no generate path / IPA until phones exist” is superseded for this button. |
| Flutter Quality Gates | Pass | format + codegen + analyze + test; no web; no new `Player()`; `build_runner` for enricher notifier; `flutter gen-l10n` |

**Post-design re-check**: Pass — contracts keep line identity, YouTube without demux, optional clocks, global prefs with per-item capability, Craft save unchanged. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/042-on-demand-transcript-enrichment/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── README.md
│   ├── display-gating.md
│   ├── enrich-control.md
│   ├── owned-media-align.md
│   ├── youtube-ipa-only.md
│   ├── optional-word-times.md
│   └── writers.md
└── tasks.md             # /speckit-tasks (not this command)
```

### Source Code (repository root)

```text
packages/forced_alignment/lib/
  forced_alignment.dart                 # export phonemize
  src/phonemize.dart                    # EspeakSynthHost → words + IPA labels, no source PCM
lib/data/subtitle/
  transcript_line.dart                  # nullable clocks; omit on write
  current_transcript_word.dart          # treat null duration as untimed (already ≤0)
  attach_phonemes_to_lines.dart         # phonemize result → untimed TranscriptWord
  alignment_language.dart               # lifted from Craft
  transcript_display_readiness.dart     # pure gating flags
lib/data/audio/pcm16k_mono.dart         # + decodeFileToPcm16kMono / windowed extract
lib/features/craft/application/craft_timeline_enricher.dart  # call shared language helper
lib/features/transcript/data/transcript_repository.dart      # replaceTimeline
lib/features/transcript/application/
  transcript_enrichment_controller.dart # @Riverpod run/cancel; owned vs YouTube
  karaoke_word_index_provider.dart      # also require canTrustWordTimes
lib/features/transcript/presentation/
  transcript_display_settings_sheet.dart  # gate switches + enrich tile
  subtitle_track_picker_sheet.dart        # pass readiness, not only hasPhones
lib/l10n/*.arb
test/data/subtitle/…
test/features/transcript/…
packages/forced_alignment/test/phonemize_test.dart
docs/decisions/0078-on-demand-transcript-enrichment.md
docs/features/transcript.md
docs/decisions/README.md
```

**Structure Decision**: Do not add a new feature module. Transcript owns the learner-facing producer (application + CC sheet). Shared JSON/gating/PCM stay in `lib/data`. Phonemize lives next to eSpeak in `packages/forced_alignment` so DTW is not required for YouTube.

## Complexity Tracking

> None. No constitution violations.
