# Contract: Flatten to enjoy-web timings

**Feature**: `037-alignment-engine`  
**Parity**: `@enjoy/alignment` `WordTiming` / `PhoneTiming`; slice 1 `TranscriptPhone` fields

## Function

`flattenToWordPhoneTimings(AlignmentResult) → { words: WordTiming[], phones: PhoneTiming[] }`

## Rules

1. Walk recursive `timeline` (and/or `wordTimeline`) for `type == word` in order.
2. Each word: `text`, `startTime`, `endTime` (seconds, source audio). Drop empty `text`.
3. Child `type == phone` (or phones listed under that word): `phone` (IPA label), `text` (same as phone if missing), `startTime`, `endTime`, `wordIndex` = index in the flattened word list.
4. `granularity == low`: `phones` empty/omitted.
5. Phone without a resolvable parent word: skip.
6. Do not convert to milliseconds here. Slice 3 subtracts parent line start and writes cue JSON `start`/`duration` (ms relative to line) and keeps phone seconds.

## Round-trip intent (slice 3, not this slice)

```text
AlignmentResult
  → flattenToWordPhoneTimings
  → (slice 3) group words into existing TranscriptLine windows
  → TranscriptWord { text, startMs, durationMs, phones: TranscriptPhone[] }
```

This slice only tests flatten: word order, phone `wordIndex` in range, times in seconds, `low` omits phones.

## Non-goals

- Importing `package:enjoy_player/data/subtitle/transcript_line.dart` from the alignment package
- Writing `timeline_json`
