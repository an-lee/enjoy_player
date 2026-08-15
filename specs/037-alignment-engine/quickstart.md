# Quickstart: Alignment Engine

**Feature**: `037-alignment-engine`  
**Contracts**: [contracts/README.md](./contracts/README.md) · **Model**: [data-model.md](./data-model.md)

## Prerequisites

- Flutter toolchain per repo README
- After adding the path package: update ADR-0029 allowlist + `check_no_new_path_deps.sh`
- Native eSpeak is **optional** for CI; DTW tests must pass without it

## Automated checks

```bash
flutter test packages/forced_alignment/test
flutter test test/features/alignment
flutter analyze
bash .github/scripts/validate_ci_gates.sh --fix
```

Expected:

- DTW / flatten / failure-enum tests pass without native FFI
- `align` rejects `> 90` s PCM and `< 1` s PCM with typed failures
- `alignSegments` offsets word times into parent windows (±50 ms pad)
- `flattenToWordPhoneTimings` sets `wordIndex` in range; `low` has no phones
- Inert-import test: Craft/transcript/player/ASR do not import `forced_alignment`
- Existing Craft save / transcript panel tests still pass (line-only)
- eSpeak golden (`hello world`, en-US, ±50 ms) runs or **skips** if FFI missing

## Manual validation (E2E)

This slice has **no new UI**. Confirm:

### A. Product unchanged (P1)

1. Open import, YouTube captions, ASR, and Craft items.
2. **Expect**: Same lines/times/interactions as before; no Settings row for timeline enrichment.

### B. Optional engine smoke (debug only)

1. If a debug harness exists, run `align` on a short local WAV + known text.
2. **Expect**: Word list in order; phones at `medium`; cancel stops the job.

Do not ship a learner-facing way to run alignment in this slice.

## Done when

- [ ] Automated checks above pass
- [ ] Manual A passes on at least one desktop target
- [ ] ADR-0071 recorded and indexed
- [ ] `docs/features/transcript.md` notes the unused engine
