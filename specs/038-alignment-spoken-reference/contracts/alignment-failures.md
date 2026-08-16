# Contract: Alignment failures (spoken-reference upgrade)

**Feature**: `038-alignment-spoken-reference`  
**Base**: [037 alignment-failures](../../037-alignment-engine/contracts/alignment-failures.md)

Public `align` / `alignSegments` still never throw an untyped error for expected problems. They return `AlignmentFailure` with exactly one `reason`.

| Reason | Caller mapping |
|--------|----------------|
| `audioUnavailable` | No PCM; YouTube WebView / remote-only sources |
| `tooShort` | `< 1.0` s of audio (clip or cue) |
| `blankText` | Empty/whitespace transcript |
| `unsupportedLanguage` | Tag not mapped to a spoken-reference voice |
| `spokenReferenceUnavailable` | **New.** Tag is mapped, but the spoken voice cannot be produced on this run |
| `wholeClipTooLong` | `align` with duration `> 90` s |
| `cancelled` | Cancel token (including during synth) |
| `timedOut` | Wall-clock budget (including during synth) |
| `internal` | DTW/remap/unexpected FFI **after** a spoken reference existed; log details, no PII |

**Must remain true**:

1. A failure is not `AlignmentResult(wordTimeline: [])`.
2. Failures do not insert/update `transcripts` rows.
3. `unsupportedLanguage` does not fall back to `en-US` (or any other) timings.
4. `spokenReferenceUnavailable` is not encoded as `internal` only, and is not a successful word list.
5. Production `align` / `alignSegments` MUST NOT return success from `DurationModelSynthesizer` or letter-split G2P when the spoken voice is missing.
6. Learners see no new UI chrome for these failures in this slice (no product caller).

## Tests (always on CI)

1. Harness that disables the spoken voice (injected unavailable synthesizer **or** production path with FFI forced off) → `spokenReferenceUnavailable`; 0 successful word lists.
2. Unmapped language → `unsupportedLanguage`.
3. Blank / too-short / too-long / cancel / timeout still match slice 2.
4. Assert the production factory is not `DurationModelSynthesizer`.
