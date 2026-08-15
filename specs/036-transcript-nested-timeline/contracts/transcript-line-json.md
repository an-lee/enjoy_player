# Contract: Transcript line JSON (nested spans)

**Feature**: `036-transcript-nested-timeline`  
**Storage**: `transcripts.timeline_json` — JSON array of cue objects  
**Types**: `TranscriptLine`, `TranscriptWord`, `TranscriptPhone` in `lib/data/subtitle/transcript_line.dart`  
**Parity**: enjoy web `apps/web/src/types/db/transcript.ts` (Spec 027)

## Line-only cue (unchanged, still the only producer output this slice)

```json
{
  "text": "Hello world.",
  "start": 0,
  "duration": 1200
}
```

Optional existing key: `sourceKey` (non-empty string only). Optional web key: `confidence` (0–1).

## Nested cue (enjoy web)

```json
{
  "text": "hello world",
  "start": 0,
  "duration": 2000,
  "timeline": [
    {
      "text": "hello",
      "start": 0,
      "duration": 1000,
      "phones": [
        {
          "phone": "h",
          "text": "h",
          "startTime": 0,
          "endTime": 0.5,
          "wordIndex": 0
        }
      ]
    },
    {
      "text": "world",
      "start": 1000,
      "duration": 1000
    }
  ]
}
```

Word `start` / `duration` are milliseconds **relative to the parent line**. Phone `startTime` / `endTime` are **seconds** (`PhoneTiming`).

## Write rules (`toJson`)

1. Always write `text`, `start`, `duration` (integers, milliseconds) on the line.
2. Write `sourceKey` only when non-empty (existing rule).
3. Write `confidence` only when set.
4. Write `timeline` only when the in-memory word list is non-empty.
5. For each word: always `text`, `start`, `duration`. Write `phones` only when non-empty.
6. For each phone: always `phone`, `text`, `startTime`, `endTime`. Write `wordIndex` only when set.
7. Do not write `timeline: []` or `phones: []`. Do not write a second nested vocabulary (`words`, `phonemes`, `ipa`).

## Read rules (`fromJson`)

1. Parse `text` / `start` / `duration` / `sourceKey` exactly as today.
2. Nested words from `timeline` only. A `words` key is unknown and ignored.
3. If `timeline` is missing, null, or not a list → no nested words.
4. Skip non-object elements and words with empty `text`.
5. Word phones from `phones` only. Nested `timeline` or `phonemes` on a word are unknown and ignored.
6. Phone fields are `phone`, `text`, `startTime`, `endTime`, optional `wordIndex`. Skip a phone with empty `phone`.
7. Never throw for nested malformations; never rewrite line `text` / `start` / `duration` from nested times.

## Round-trip

`fromJson(toJson(line))` equals `line` for line-only cues, web-shaped nested cues, and empty nested lists (both sides `timeline == null`).

## Non-goals

- Storing Echogarden `type` / recursive `startTime` trees on the cue
- Requiring `timeline` on any producer in this slice
