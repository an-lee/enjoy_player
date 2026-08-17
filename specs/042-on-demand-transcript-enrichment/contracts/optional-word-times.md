# Contract: Optional word times

Slice 1 allowed omitted clocks; this slice makes that the **YouTube write** shape.

## Write

| Kind | Word JSON | Phone JSON |
|------|-----------|------------|
| Timed alignment success | `start` + `duration` (ms relative to line) | `startTime` + `endTime` (seconds) when the engine has them |
| IPA-only phonemize | **omit** `start` and `duration` | **omit** `startTime` and `endTime`; keep `phone` / `text` / `wordIndex` |

Do not persist `duration: 0` as a stand-in for “untimed” on new YouTube writes.

## Read

- Missing word clocks or `durationMs <= 0` → untimed (`currentWordIndex` / `wordMediaWindowMs` already skip).
- Missing phone clocks → still feed `wordIpaSpelling` from labels.
- Explicit numeric zeros from historical rows stay valid and remain untimed for karaoke.

## Consumers

| Consumer | Untimed word |
|----------|----------------|
| Karaoke highlight | No paint |
| Tap IPA to play | No seek |
| IPA overlay | Show labels if phones exist |
| Line seek / echo / lookup / blur | Unchanged (line fields) |
