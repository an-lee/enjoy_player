# Implementation Plan: Nested Transcript Timeline

**Branch**: `036-transcript-nested-timeline` | **Date**: 2026-08-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/036-transcript-nested-timeline/spec.md`

**Note**: `/speckit-clarify` was skipped; defaults locked in [research.md](./research.md) (enjoy-web `timeline`/`phones` in `timeline_json`; line identity unchanged; no UI / no settings / no Drift migration).

## Summary

Slice 1 of issue #540: extend the stored transcript cue with **optional word and phone spans** so later alignment, Craft enrichment, karaoke, and IPA work have a place to persist data. Existing line-only transcripts keep working unchanged. The transcript panel does **not** consume nested data yet. Implementation is an additive JSON + Dart model change in `TranscriptLine`, plus tests and docs — no new producers, no new settings, no schema migration.

## Technical Context

**Language/Version**: Dart 3.x / Flutter (stable channel per repo)

**Primary Dependencies**: Existing `TranscriptLine` JSON in `lib/data/subtitle/transcript_line.dart`; `castJsonObjectOrNull` / `intFromJson` (`lib/core/json/json_cast.dart`); Drift `transcripts.timeline_json` (opaque TEXT); `cueIdFor` in `lib/features/transcript/domain/transcript_blur.dart`

**Storage**: No Drift schema changes. Nested spans are optional keys inside existing `timeline_json` cue objects (same additive pattern as ADR-0039 `sourceKey`)

**Testing**: `flutter test` (pure JSON round-trip, malformed nested degrade, `==` vs `cueIdFor`, existing provider dedupe, inert tile render); `flutter analyze`; `bash .github/scripts/validate_ci_gates.sh --fix`. No codegen (`@Riverpod` / Drift annotations unchanged)

**Target Platform**: Android, iOS, macOS, Windows, Linux (no web)

**Project Type**: Cross-platform Flutter desktop/mobile app

**Performance Goals**: Flat (line-only) `fromJson` stays a single extra map lookup per cue with no nested allocations; a typical ~200-line caption track must not add user-visible load delay. Nested parse walks `timeline`/`phones` once at load, not in `build`. No new isolate work this slice (payloads stay small; production rows remain flat)

**Constraints**: Additive fields only — do not rename/remove `text`/`start`/`duration`/`sourceKey`. Producers stay line-only. No karaoke/IPA/settings. No `print()`. No new `media_kit` `Player`. No Flutter web. Nested times do not rewrite line times. `cueIdFor` and auto-translate `sourceKey` ignore nested spans

**Scale/Scope**: One data-layer model file + unit/widget tests + ADR-0070 + `docs/features/transcript.md`. No Worker API, Craft pipeline, ASR builder, or panel chrome changes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Plan response |
|-----------|--------|---------------|
| I. Architecture | Pass | Nested types live with `TranscriptLine` in `lib/data/subtitle` (UI-free). Persistence stays Drift `timeline_json` via existing DAOs. No feature↔feature imports; panel keeps reading `line.text` |
| II. Testing | Pass | Unit tests for JSON/equality/identity/malformed input; extend `cueIdFor` coverage; widget test that the tile ignores nested spans; existing transcript tests must stay green |
| III. UX consistency | Pass | No new tappable chrome, ARB strings, or Settings. Feature doc records storage-only nested spans so UX does not silently change |
| IV. Performance | Pass | Optional parse; omit empty keys; no nested work in `build` or list item builders; production writers still emit flat cues |
| V. Documentation | Pass | ADR-0070 for the stored JSON contract + line-identity rule; update `docs/features/transcript.md` and `docs/decisions/README.md` |
| Flutter Quality Gates | Pass | `dart format` + `flutter analyze` + `flutter test`; no web; no new `Player()`; no codegen expected |

**Post-design re-check**: Pass — contracts bound JSON shape, identity vs equality, and inert render only. No unjustified schema, Worker, Craft, or UI changes. Empty-list normalize and defensive `fromJson` keep historical rows loadable.

## Project Structure

### Documentation (this feature)

```text
specs/036-transcript-nested-timeline/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── README.md
│   ├── transcript-line-json.md
│   ├── transcript-line-identity.md
│   └── inert-nested-render.md
└── tasks.md             # /speckit-tasks (not this command)
```

### Source Code (repository root)

```text
lib/data/subtitle/
  transcript_line.dart                 # + TranscriptWord, TranscriptPhone, optional timeline

lib/features/transcript/domain/
  transcript_blur.dart                 # cueIdFor unchanged (pin with tests)

lib/features/transcript/presentation/
  transcript_line_tile.dart            # no display change; widget test proves inert

docs/decisions/
  0070-nested-transcript-timeline.md   # new ADR
  README.md                            # index row
docs/features/
  transcript.md                        # storage-only nested spans note

test/data/subtitle/
  transcript_line_test.dart            # new: JSON, normalize, malformed, ==
test/features/
  domain_gaps_coverage_test.dart       # extend cueIdFor: timeline words do not change id
  transcript/transcript_lines_provider_dedupe_test.dart  # nested == case
  transcript/presentation/             # inert tile test (new or extend existing)
```

**Structure Decision**: Keep nested types in the existing subtitle data model (`lib/data/subtitle`), not a new feature package. Alignment/Echogarden types belong to slice 2 (`packages/forced_alignment`) and must not leak into stored cues this slice. No Riverpod/Drift codegen.

## Complexity Tracking

> No constitution violations requiring justification. Additive optional JSON on the existing cue is simpler than a new table, a recursive stored tree, or wiring alignment in the same change.
