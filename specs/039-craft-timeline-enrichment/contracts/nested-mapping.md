# Contract: Alignment result → stored cue

**Function**: `attachAlignmentToLines(lines, result) → lines'`  
**Layer**: `lib/data/subtitle` (no Flutter widgets, no Drift)

## Rules

1. Output length and order equal input `lines`.
2. Each output line keeps `text`, `startMs`, `durationMs`, `sourceKey`, `confidence`.
3. Match engine `timeline` entries with `type == segment` and `id == lineIndex` first. Fallback: words whose `startTime` lies in the line window (last line includes `endTime`).
4. For each matched word:  
   `startMs = max(0, round((word.startTime − line.startSeconds) × 1000))`  
   `durationMs = max(0, round((word.endTime − word.startTime) × 1000))`
5. Child phones become `TranscriptPhone` with media-timeline seconds; `wordIndex` is the index in **that line’s** word list (rebased, not the flatten-global index).
6. Empty `timeline` is omitted (`null`), not `[]`.
7. Words with empty text are dropped. Phones without a parent word on that line are dropped.
8. Do not rewrite the caller’s line text to match alignment word concatenation.

## Tests

- Two-line fixture: each line’s words stay inside its window ±50 ms pad; line starts unchanged.
- Phone `wordIndex` in range for that line.
- Failed/missing segment → that line remains line-only; siblings may be nested.
- Round-trip `TranscriptLine.toJson` / `fromJson` preserves nested fields (slice 1 tests still apply).
