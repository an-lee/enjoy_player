# Contract: Alignment API

**Feature**: `037-alignment-engine`  
**Package**: `packages/forced_alignment`  
**Types**: [data-model.md](../data-model.md)

## `align` (whole clip)

**In**: 16 kHz mono Float32 PCM, transcript string, BCP-47 language, optional granularity / timeout / cancel.

**Out**: `AlignmentResult` or `AlignmentFailure`.

**Caps**:
- PCM duration `< 1.0` s → `tooShort`
- PCM duration `> 90` s → `wholeClipTooLong` (use `alignSegments`)
- Default timeout 2 minutes → `timedOut`
- Default granularity `medium` (words + phones)

Transcript string on success equals the request text (byte-for-byte after the caller’s own trim policy; the engine does not rewrite wording).

## `alignSegments` (per cue)

**In**: same PCM + language + list of `{text, startTime, endTime}` windows (seconds on that PCM).

**Out**: `AlignmentResult` whose `timeline` has one `segment` entry per successful cue (failed cues omitted). Whole-request failures (`unsupportedLanguage`, `audioUnavailable`, `cancelled`, `timedOut`) abort the batch. If **every** cue fails locally (e.g. all `tooShort`), return that typed failure — never a successful empty `wordTimeline`.

**Per cue**:
- Window `< 1.0` s → skip that cue (`tooShort` for the cue only)
- Align fragment locally, then add `startTime` to all child times
- Word times must fall in `[startTime - 0.050, endTime + 0.050]`
- Must not mutate caller cue line start/end (engine does not own cues)

Multi-minute PCM is **valid** for `alignSegments`. It is **invalid** for `align`.

## Isolation and cancel

DSP runs off the UI isolate. Cancel completes with `cancelled` and must not leave a runaway job that blocks later calls. Logging via `package:logging` (app uses `logNamed` at the wrapper; package may use `Logger('forced_alignment')` — never `print`).

## Non-goals

- FFmpeg / file paths inside the package
- Drift writes
- `media_kit` `Player`
- Flutter web
