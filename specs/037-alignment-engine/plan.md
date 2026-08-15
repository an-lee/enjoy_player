# Implementation Plan: Alignment Engine

**Branch**: `037-alignment-engine` | **Date**: 2026-08-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/037-alignment-engine/spec.md`

**Note**: `/speckit-clarify` was skipped; defaults locked in [research.md](./research.md) (path package, Echogarden result interface, PCM-in, isolate + typed failures, no Craft/panel/Settings).

## Summary

Slice 2 of issue #540: ship an **on-device alignment capability** that maps known text + 16 kHz mono PCM to word- and phone-level timings. Public result shape matches Echogarden (`align` / `alignSegments`); a pure flatten adapter yields enjoy-web `WordTiming` / `PhoneTiming` for slice 3. **No product flow calls the engine.** Learners see no new UI. Implementation is `packages/forced_alignment` plus pinning tests and ADR-0071 — no Drift migration, no Settings, no Craft pipeline change.

## Technical Context

**Language/Version**: Dart 3.x / Flutter (stable channel per repo)

**Primary Dependencies**: New path package `packages/forced_alignment`; pub.dev `espeak` (FFI wrap/extend); `mcfcc_nsn` (MFCC); existing FFmpeg extractors **not** imported by the package (slice 3). Slice 1 `TranscriptLine` is **not** imported by the package.

**Storage**: None. No Drift schema, no `timeline_json` writes, no settings key.

**Testing**: `flutter test` in `packages/forced_alignment/test` (DTW, flatten, failures, caps) + `test/features/alignment` (inert imports). eSpeak goldens skip if FFI missing. `flutter analyze`; `bash .github/scripts/validate_ci_gates.sh --fix`. Path-dep allowlist update. No Riverpod/Drift codegen expected.

**Target Platform**: Android, iOS, macOS, Windows, Linux (no web)

**Project Type**: Cross-platform Flutter app + UI-free path package

**Performance Goals**: Typical ≤60 s clip at `medium` completes in **<10 s** on a current mid-range device without blocking playback (DSP in `Isolate.run`). Whole-clip **>90 s** refused. Per-cue jobs for long media. Memory: 60 s `medium` DTW should stay well under 50 MB heap (issue #540); pin with a debug-only assertion or documented manual check if CI cannot measure heap.

**Constraints**: Offline; no extra credits; no `print()`; no new `media_kit` `Player`; no Flutter web; no YouTube demux; do not rewrite caller transcript text; do not change `cueIdFor` / Craft save. Cancel + timeout required. GPL eSpeak-NG into AGPL app must be recorded in ADR-0071.

**Scale/Scope**: One path package + tests + ADR-0071 + transcript feature note + ADR-0029 allowlist. No Worker, Craft, ASR builder, or panel chrome.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Plan response |
|-----------|--------|---------------|
| I. Architecture | Pass (justified path package) | Engine is a UI-free path package like `azure_speech`, not a feature screen. App `lib/features/*` must not call it this slice. Persistence unchanged (Drift DAOs untouched). |
| II. Testing | Pass | DTW/flatten/failure unit tests always; native golden skippable; inert-import test; existing Craft/transcript tests stay green |
| III. UX consistency | Pass | No new tappable chrome, ARB, or Settings. Feature doc records unused engine |
| IV. Performance | Pass | `Isolate.run`; 90 s whole-clip cap; per-cue for long media; <10 s goal for 60 s clips; cancel/timeout |
| V. Documentation | Pass | ADR-0071 (engine contract + license + exclusions); ADR-0029 allowlist row; `docs/features/transcript.md` note |
| Flutter Quality Gates | Pass | format + analyze + test; path-dep script allowlist; no web; no new `Player()`; no codegen expected; Linux is a first-class target for the package |

**Post-design re-check**: Pass — contracts bound API, failures, flatten, and inert product. No Drift, no Craft wiring, no Settings. Path package + allowlist is the same supply-chain pattern as existing native plugins, not a fourth ad-hoc repo.

## Project Structure

### Documentation (this feature)

```text
specs/037-alignment-engine/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── README.md
│   ├── align-api.md
│   ├── alignment-failures.md
│   ├── flatten-to-web-timings.md
│   └── inert-product.md
└── tasks.md             # /speckit-tasks (not this command)
```

### Source Code (repository root)

```text
packages/forced_alignment/
  lib/forced_alignment.dart            # barrel: align, alignSegments, types, flatten, failures
  lib/src/
    types.dart                         # TimelineEntry, AlignmentResult, granularity
    alignment_service.dart             # align / alignSegments + isolate + caps
    flatten.dart                       # flattenToWordPhoneTimings
    failures.dart                      # AlignmentFailure
    dtw/                               # windowed DTW + path mapping
    mfcc/                              # mcfcc_nsn presets
    synth/                             # eSpeak reference PCM + events
  test/                                # DTW, flatten, failures, caps; optional eSpeak golden
  pubspec.yaml

lib/                                  # no production imports of forced_alignment this slice

test/features/alignment/
  forced_alignment_inert_import_test.dart

docs/decisions/
  0071-on-device-alignment-engine.md   # new ADR
  0029-supply-chain-risk.md            # allowlist row
  README.md
docs/features/
  transcript.md                        # unused-engine note

.github/scripts/check_no_new_path_deps.sh   # ALLOWLIST += packages/forced_alignment
pubspec.yaml                                 # path: packages/forced_alignment
```

**Structure Decision**: Native DSP lives in `packages/forced_alignment` (PCM in / timings out). Do not add `lib/features/alignment` production code until slice 3 needs FFmpeg decode + Craft mapping. Tests under `test/features/alignment` only pin inert imports.

## Complexity Tracking

> Path package instead of `lib/features/alignment`: required for FFI/DSP isolation and to match `azure_speech` / issue #540. A feature module this slice would still have no UI and would be easier to import from Craft by mistake.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| New `path:` dep | Native alignment engine, UI-free | Putting DTW/FFI under `lib/features` couples the app graph and still needs ADR-0029 if extracted later |
