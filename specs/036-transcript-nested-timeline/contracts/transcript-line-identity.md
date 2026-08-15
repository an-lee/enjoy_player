# Contract: Transcript line identity

**Feature**: `036-transcript-nested-timeline`

Practice features must keep treating a cue as the **same line** when nested spans are added, removed, or incomplete.

## Line identity (MUST ignore nested spans)

| Consumer | Identity input |
|----------|----------------|
| Blur / tap-reveal | `cueIdFor(line)` → `startMs`, `endMs`, FNV hash of plain `line.text` |
| Auto-translate overlay | `sourceKey` from normalized **line** text + language pair (ADR-0039) |
| Current-line highlight | `line.startMs` / `line.endSeconds` vs playback position |
| Echo region | Line index and/or line start/end on the session |
| Tap-to-seek | `line.startMs` |
| Dictionary lookup selection | Plain text from `line.text` markup |

`cueIdFor` MUST NOT read `timeline` or `phones`.

## Value equality (MUST include nested spans)

`TranscriptLine.==` / `hashCode` include `timeline` and `confidence` (null-equivalent to empty).

This lets `transcriptLinesForMediaProvider`’s `distinctBy(listEquals)` re-emit when a later slice enriches a cue, without changing `cueIdFor`.

## Required tests

1. Two line-only cues with identical line fields are `==` (existing).
2. Same line fields, different `timeline` → not `==`.
3. Same line fields, `timeline: null` vs parsed empty list → `==` (both null after normalize).
4. `cueIdFor(line)` == `cueIdFor(lineWithWords)` when text/start/duration match.
5. `sourceKey` is unchanged by the presence of `timeline`.

## Non-goals

- Changing echo session schema
- Changing `cueIdFor` hash algorithm
- Using word times for current-line tracking in this slice
