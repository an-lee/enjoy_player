# Implementation Plan: Spoken Alignment Reference

**Branch**: `038-alignment-spoken-reference` | **Date**: 2026-08-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/038-alignment-spoken-reference/spec.md`

**Note**: `/speckit-clarify` was skipped; defaults locked in [research.md](./research.md) (eSpeak-NG `espeak_Synth` FFI in `packages/forced_alignment`, fail-closed when the voice is missing, no second path package, product still unused).

## Summary

Slice 2b of issue #540: upgrade the unused on-device aligner so a **production success** compares extractable 16 kHz source PCM to a same-language **spoken** rendering of the known text (waveform + word/phone events), then remaps those events onto the source timeline via the existing MFCC + windowed DTW path. Even stretch, tone stand-ins, and letter-split phones MUST NOT be a production success. Missing voice → distinct `spokenReferenceUnavailable`. **No product flow calls the engine.** Learners hear no reference voice. Implementation stays in `packages/forced_alignment` plus ADR-0072 — no Drift, no Settings, no Craft pipeline change.

## Technical Context

**Language/Version**: Dart 3.x / Flutter (stable channel per repo)

**Primary Dependencies**: Existing path package `packages/forced_alignment` (`mcfcc_nsn`, isolate, DTW). New: `dart:ffi` wrap of vendored eSpeak-NG (`espeak_Synth` + synth callback). **Not** pub.dev `espeak` (phonemize-only). **Not** Azure TTS (playback only). FFmpeg / `TranscriptLine` stay out of the package.

**Storage**: None. No Drift schema, no `timeline_json` writes, no settings key. Native artifacts are package files (`native/<os>/` + trimmed `espeak-ng-data`), not user data.

**Testing**: `flutter test packages/forced_alignment/test` (fail-closed, caps, flatten, injected-double DTW) + existing `test/features/alignment` inert imports. Real-voice goldens skip if FFI/data missing. `flutter analyze`; `bash .github/scripts/validate_ci_gates.sh --fix`. No Riverpod/Drift codegen expected.

**Target Platform**: Android, iOS, macOS, Windows, Linux (no web)

**Project Type**: Cross-platform Flutter app + UI-free path package

**Performance Goals**: Typical ≤60 s clip at `medium`, **including** spoken-reference synth, completes in **<10 s** on a current mid-range device without blocking playback (synth + DSP on the alignment isolate). Whole-clip **>90 s** refused. Per-cue jobs for long media. Document if a given platform is slower (SC-008).

**Constraints**: Offline; no extra credits; no `print()`; no new `media_kit` `Player`; no Flutter web; no YouTube demux; do not play the reference; do not rewrite caller transcript text; do not change `cueIdFor` / Craft save. Cancel must abort in-flight synth (callback return `1`). GPL eSpeak-NG into AGPL app recorded in ADR-0072 + packaging note.

**Scale/Scope**: Synth/FFI + fail-closed wiring inside the existing package; one new failure reason; ADR-0072; transcript unused-engine note; packaging note. No Worker, Craft, ASR builder, panel chrome, or new path package.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Plan response |
|-----------|--------|---------------|
| I. Architecture | Pass (existing path package) | Stay in `packages/forced_alignment`. No new `lib/features/` module. App flows must not call the engine. Drift DAOs untouched. |
| II. Testing | Pass | Fail-closed + unsupported-language tests always; quality goldens skippable; inert-import pins; existing Craft/transcript tests stay green |
| III. UX consistency | Pass | No new tappable chrome, ARB, or Settings. Learners never hear the reference |
| IV. Performance | Pass | Synth + DTW on existing isolate; 90 s cap; per-cue for long media; <10 s goal includes synth; cancel/timeout |
| V. Documentation | Pass | ADR-0072 (spoken reference + FFI + license + packaging); ADR-0071 left intact; `docs/features/transcript.md` + `docs/packaging.md` notes; ADR-0029 follow-up text |
| Flutter Quality Gates | Pass | format + analyze + test; no new path dep; no web; no new `Player()`; no codegen expected; five OS natives documented |

**Post-design re-check**: Pass — contracts add the spoken-reference seam and `spokenReferenceUnavailable` without changing result meaning, flatten, or inert product. Native binaries are complexity inside an already-justified path package (see Complexity Tracking), not a fourth repo or a feature-module violation.

## Project Structure

### Documentation (this feature)

```text
specs/038-alignment-spoken-reference/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── README.md
│   ├── align-api.md
│   ├── alignment-failures.md
│   ├── spoken-reference.md
│   └── inert-product.md
└── tasks.md             # /speckit-tasks (not this command)
```

### Source Code (repository root)

```text
packages/forced_alignment/
  lib/forced_alignment.dart
  lib/src/
    failures.dart                      # + spokenReferenceUnavailable
    alignment_pipeline.dart            # spoken ReferenceAudio; no duration stretch
    alignment_service.dart             # production synth; optional test double
    alignment_isolate.dart             # init eSpeak once per isolate
    language_map.dart                  # unchanged voice ids
    synth/
      spoken_reference.dart            # SpokenReferenceSynthesizer + ReferenceAudio
      espeak_ng_synthesizer.dart       # dart:ffi espeak_Synth + events
      resample.dart                    # native rate → 16 kHz Float32
  native/<os>/                         # vendored libespeak-ng
  native/espeak-ng-data/               # trimmed focus voices
  test/                                # fail-closed, goldens (skip), caps
test/features/alignment/               # existing inert-import pins
docs/decisions/0072-spoken-alignment-reference.md
docs/features/transcript.md            # unused engine: spoken reference required
docs/packaging.md                      # native lib + data + GPL note
```

**Structure Decision**: Keep the slice 2 path package. Add synth/FFI and native artifacts beside the existing DTW core. No `lib/features/alignment` product module. No second path package.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Vendored eSpeak-NG binaries + voice data inside `packages/forced_alignment` | Production success requires spoken PCM + pronunciation events on five OS targets (FR-002 / FR-004) | pub.dev `espeak` is phonemize-only; duration-model tones are forbidden as production success; cloud TTS spends credits and is not offline; compiling from source on every `flutter test` was rejected in slice 2 |
| `dart:ffi` wrap (not a Flutter plugin) | Alignment isolate must call `espeak_Synth` synchronously and abort via callback | A method-channel plugin would hop back to the platform thread and tempt UI-isolate use; Azure-style plugin is the wrong shape for PCM-in/PCM-out |

These are **not** a new feature module or a new path dependency. ADR-0029 already lists `packages/forced_alignment`.
