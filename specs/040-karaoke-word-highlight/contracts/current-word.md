# Contract: Current word

Pure logic (no widgets). Inputs: one `TranscriptLine`, media position in milliseconds.

## Time window

A word at index `i` is a candidate when all of:

- `word.text` is non-empty
- `word.durationMs > 0`
- The interval `[line.startMs + word.startMs, line.startMs + word.startMs + word.durationMs)` intersects `[line.startMs, line.startMs + line.durationMs]`
- Media position `p` satisfies  
  `line.startMs + word.startMs ≤ p < line.startMs + word.startMs + word.durationMs`

If several candidates match, pick the **last** in `timeline` order. If none match, current word is absent (gap, punctuation, untimed words).

Words whose entire window lies outside the parent line are never current (FR-009). Line start/duration are never rewritten.

## Text range

Given `plain = transcriptPlainForSelection(line.text)` and word index `i`, locate each word’s `text` with a sequential forward substring search. Return the `[start, end)` of word `i` in `plain`, or null if it cannot be found.

## Provider

`karaokeWordIndexProvider(mediaId) → int?`

- `null` when karaoke is off, there is no current cue, or `currentWordIndex` is null
- Position stream: `quantizedPositionStream(rawEnginePosition, bucketMs: kPositionBucketKaraokeMs)` with `kPositionBucketKaraokeMs = 50`
- Cue index: existing echo-aware `transcriptPlaybackHighlightProvider` (400 ms display bucket unchanged)
- Widgets that are not the active cue MUST NOT watch this provider

## Tests

- Three timed words: sample `p` in each window → expected index; 0 samples return two indices
- Overlap → last matching index
- Line-only / empty timeline / zero duration / out-of-window → null
- Sequential substring: `Hello world` + words Hello, world → ranges `[0,5)` and `[6,11)` (or equivalent after markup strip)
- Missing substring for word `i` → null range
