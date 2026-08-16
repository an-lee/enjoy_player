# Quickstart: Spoken Alignment Reference

**Feature**: `038-alignment-spoken-reference`  
**Contracts**: [contracts/README.md](./contracts/README.md) · **Model**: [data-model.md](./data-model.md)

## Prerequisites

- Flutter toolchain per repo README
- Slice 2 package `packages/forced_alignment` on the branch (already on `main` after PR #554)
- Vendored eSpeak-NG lib + trimmed data are **optional** for most CI tests; fail-closed tests must pass without them

## Automated checks

```bash
flutter test packages/forced_alignment/test
flutter test test/features/alignment
flutter analyze
bash .github/scripts/validate_ci_gates.sh --fix
```

Expected:

- Production `align` with the spoken voice disabled → `spokenReferenceUnavailable` (never a duration-model success)
- Unmapped language → `unsupportedLanguage` (no silent voice swap)
- Caps, cancel, timeout, flatten, and cue-pad tests still pass
- Inert-import test: Craft/transcript/player/ASR/lookup do not import `forced_alignment`
- Existing Craft save / transcript panel tests still pass (line-only)
- Real-voice golden (`hello world`, en-US): every expected word in order; each start within **50 ms** of **that run’s** spoken-reference word events; default quality phones are not a letter-split of “hello” — or the test **skips** if FFI/data cannot load

## Manual validation (E2E)

This slice has **no new UI**. Confirm:

### A. Product unchanged (P1)

1. Open import, YouTube captions, ASR, and Craft items.
2. Play a Craft item.
3. **Expect**: Same lines/times/interactions as before; no Settings row for timeline enrichment or “reference voice”; playback is the existing audio, not a synthetic reference.

### B. Optional engine smoke (debug only)

1. If a debug harness exists **and** eSpeak-NG loads, run `align` on a short **spoken** English fixture + known text.
2. **Expect**: Word list in order; phones at `medium` from the voice; a second run keeps count/order within 50 ms.
3. Force the voice off (missing data path or test harness) and **expect** `spokenReferenceUnavailable`.

Do not ship a learner-facing way to run alignment in this slice.

## Done when

- [ ] Automated checks above pass
- [ ] Manual A passes on at least one desktop target
- [ ] ADR-0072 recorded and indexed; ADR-0071 not rewritten
- [ ] `docs/features/transcript.md` notes that production alignment requires a spoken reference
- [ ] `docs/packaging.md` notes vendored lib + data + GPL
