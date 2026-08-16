# Contract: Alignment API (spoken-reference upgrade)

**Feature**: `038-alignment-spoken-reference`  
**Package**: `packages/forced_alignment`  
**Types**: [data-model.md](../data-model.md)  
**Base**: [037 align-api](../../037-alignment-engine/contracts/align-api.md)

Public `align` / `alignSegments` keep slice 2 inputs, caps, isolate, cancel, timeout, and Echogarden-shaped results. This slice changes **how a success is earned**.

## Production success

A production call (no test double) MUST:

1. Build a same-language **spoken** `ReferenceAudio` (waveform + word events; phones at default quality).
2. Compare that reference to the caller’s 16 kHz source PCM (MFCC + windowed DTW).
3. Return word/phone times on the **source** timeline.
4. Echo the caller’s transcript string unchanged.

It MUST NOT succeed by stretching words evenly across the clip, comparing only to non-speech tones, or letter-splitting spellings into phones.

## Test double

`align` / `alignSegments` MAY accept an optional `@visibleForTesting` `SpokenReferenceSynthesizer`. Injected doubles are for automated tests only. Omitting the parameter MUST use the production eSpeak-NG synthesizer and MUST fail closed if that synthesizer cannot run.

## Caps (unchanged)

- PCM `< 1.0` s → `tooShort`
- `align` PCM `> 90` s → `wholeClipTooLong`
- Cue pad 50 ms; line start/duration not rewritten
- Default granularity `medium`
- Default timeout 2 minutes whole-clip / 30 s per cue
- Spoken reference is built **per job** (whole clip or one cue’s text)

## Isolation and cancel

Synth + DSP run on the alignment isolate. Cancel completes with `cancelled` and MUST abort in-flight `espeak_Synth` (callback return `1`). Logging via `Logger('forced_alignment')` — never `print`.

## Non-goals

- FFmpeg / file paths inside the package
- Drift writes
- Playing reference PCM
- `media_kit` `Player`
- Flutter web
