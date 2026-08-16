# Implementation Plan: Craft Timeline Enrichment

**Branch**: `039-craft-timeline-enrichment` | **Date**: 2026-08-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/039-craft-timeline-enrichment/spec.md`

**Note**: `/speckit-clarify` was skipped; defaults locked in [research.md](./research.md) (enrich on Craft save only, spec 030 still builds lines, quiet fail-closed fallback, new Settings Transcript section, mapping in `lib/data/subtitle`).

## Summary

Slice 3 of issue #540: first **product caller** of `packages/forced_alignment`. A default-**off** Settings toggle (`transcript.timelineEnrichment`) lets Craft save attach nested word/phone spans onto the existing synthesis-timing lines via `alignSegments` (spoken reference from slice 2b). Off, blank, dedupe, extract failure, or alignment failure → today’s spec 030 transcript. The panel stays line-level (no karaoke). Learners still hear Craft audio. ADR-0073; docs for craft + transcript.

## Technical Context

**Language/Version**: Dart 3.x / Flutter (stable channel per repo)

**Primary Dependencies**: `packages/forced_alignment` (`alignSegments`, flatten/types, fail-closed spoken reference). Existing Craft line builder (`buildCraftPrimaryTimelineJson`). Drift `SettingsDao` + Settings hub registry (spec 004). FFmpeg only as a PCM fallback via a new `lib/data/audio` helper — **not** `AsrAudioExtractor`. Riverpod notifiers; ARB / `flutter gen-l10n`.

**Storage**: No new Drift table. Nested spans in existing `transcripts.timeline_json`. One SettingsDao key `transcript.timelineEnrichment` (`'true'`/`'false'`, missing = off).

**Testing**: Unit tests for mapper, setting provider, Craft save branches (off / fail / success / blank / dedupe). Retarget `test/features/alignment` inert pins. Settings registry widget coverage. `flutter analyze`; `dart run build_runner build` after `@Riverpod`; `bash .github/scripts/validate_ci_gates.sh --fix`.

**Target Platform**: Android, iOS, macOS, Windows, Linux (no web)

**Project Type**: Cross-platform Flutter app (product flow) + existing UI-free path package

**Performance Goals**: Typical ≤60 s Craft clip: extract + spoken-reference `alignSegments` completes in **<10 s** on a current mid-range device without blocking playback/UI (DSP already off the UI isolate). If it cannot, save still finishes via line-only fallback (SC-008). Per-cue jobs, not one whole-file align.

**Constraints**: Offline alignment; no extra credits; no `print()`; no new `media_kit` `Player`; no Flutter web; no YouTube demux; do not play the reference; do not change `cueIdFor` / spec 030 line breaks; feature↔feature: Craft must not import ASR. Quiet fallback — no blocking save error. Stack on slice 2b if #556 is unmerged.

**Scale/Scope**: One Settings section/row, one Craft save hook, one mapper, one PCM helper, ADR-0073, two feature-doc updates. No Worker, no panel chrome, no library backfill.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Plan response |
|-----------|--------|---------------|
| I. Architecture | Pass | Mapping + PCM in `lib/data`. Setting provider + Craft enricher in application layers. Persistence via `SettingsDao` / existing transcript DAO. No Craft→ASR import. Package stays UI-free. |
| II. Testing | Pass | Mapper, setting, Craft save matrix, retargeted inert pins, Settings registry. Existing 030 / panel tests stay green. |
| III. UX consistency | Pass | `SettingsRow` + `Switch.adaptive` (diagnostics pattern). ARB strings. No new tappable panel chrome. `EnjoyPage` not required (hub section). |
| IV. Performance | Pass | Extract + align off UI isolate; <10 s or fallback; per-cue; cancel/timeout from package. |
| V. Documentation | Pass | ADR-0073; `docs/features/craft.md` + `transcript.md`; ADR-0070–0072 left intact. |
| Flutter Quality Gates | Pass | format + codegen + analyze + test; no web; no new `Player()`; `build_runner` for the setting notifier; `flutter gen-l10n` |

**Post-design re-check**: Pass — contracts keep line identity, fail closed, and inert panel/import/ASR/YouTube. New Settings section is required discoverability (spec US4), not a second settings system. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/039-craft-timeline-enrichment/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── README.md
│   ├── settings-toggle.md
│   ├── craft-save-enrichment.md
│   ├── nested-mapping.md
│   ├── fallback.md
│   └── inert-consumers.md
└── tasks.md             # /speckit-tasks (not this command)
```

### Source Code (repository root)

```text
lib/data/db/settings_keys.dart              # + transcriptTimelineEnrichment
lib/data/subtitle/attach_alignment_to_lines.dart
lib/data/audio/pcm16k_mono.dart             # Craft WAV/bytes → Float32 16 kHz
lib/features/craft/application/
  craft_controller.dart                     # hook after buildCraftPrimaryTimelineJson
  craft_timeline_enricher.dart              # extract + alignSegments + attach
lib/features/settings/
  application/timeline_enrichment_settings.dart   # @Riverpod SettingsDao bool
  domain/settings_search_entry.dart         # Transcript section + row
  presentation/…                            # section body, both layouts, visuals
lib/l10n/*.arb                              # settingsTranscript* strings
test/data/subtitle/attach_alignment_to_lines_test.dart
test/features/craft/…                       # save off/fail/success/blank/dedupe
test/features/alignment/                    # retarget inert + key-exists pins
test/features/settings/                     # registry + default off
docs/decisions/0073-craft-timeline-enrichment.md
docs/features/craft.md
docs/features/transcript.md
```

**Structure Decision**: Do not add `lib/features/alignment`. Craft is the only product caller; shared mapping/PCM live in `lib/data`. Settings owns the switch chrome and the persisted bool. `packages/forced_alignment` is unchanged except as an imported API.

## Complexity Tracking

> None. No constitution violations.
