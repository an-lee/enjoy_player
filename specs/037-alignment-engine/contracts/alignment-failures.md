# Contract: Alignment failures

**Feature**: `037-alignment-engine`

Public `align` / `alignSegments` never throw an untyped error for expected problems. They return `AlignmentFailure` with exactly one `reason`.

| Reason | Caller mapping |
|--------|----------------|
| `audioUnavailable` | No PCM; YouTube WebView / remote-only sources |
| `tooShort` | `< 1.0` s of audio (clip or cue) |
| `blankText` | Empty/whitespace transcript |
| `unsupportedLanguage` | Tag not mapped to an eSpeak voice |
| `wholeClipTooLong` | `align` with duration `> 90` s |
| `cancelled` | Cancel token |
| `timedOut` | Wall-clock budget |
| `internal` | FFI/synth/DTW; log details, no PII dump |

**Must remain true**:

1. A failure is not `AlignmentResult(wordTimeline: [])`.
2. Failures do not insert/update `transcripts` rows (no DAO in this package; app tests pin zero writes).
3. `unsupportedLanguage` does not fall back to `en-US` timings.
4. Learners see no new UI chrome for these failures in this slice (no product caller).

## Tests

Unit tests for each reason with synthetic PCM/text. Cancel test: start `align` on a long synthetic buffer, cancel, expect `cancelled` without hanging the test isolate.
