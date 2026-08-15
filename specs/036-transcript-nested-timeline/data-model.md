# Data Model: Nested Transcript Timeline

**Feature**: `036-transcript-nested-timeline` | **Date**: 2026-08-12

No new Drift tables. Nested spans live inside the existing opaque `transcripts.timeline_json` array (same additive pattern as `sourceKey`).

**Parity**: enjoy web `apps/web/src/types/db/transcript.ts` (Spec 027) + `@enjoy/alignment` `PhoneTiming`.

## Entities

### TranscriptLine (existing, extended)

| Field | Required | Notes |
|-------|----------|-------|
| `text` | yes | Line display text (markup allowed). Unchanged. |
| `startMs` | yes | Cue start on the media timeline (ms). JSON key `start`. |
| `durationMs` | yes | Cue duration (ms). JSON key `duration`. |
| `sourceKey` | no | Auto-translate fingerprint (ADR-0039). Flutter-only; unchanged. |
| `confidence` | no | Optional 0–1 (enjoy web). JSON `confidence`. |
| `timeline` | no | Ordered word spans (`TranscriptWord[]`). `null` when absent or empty. JSON `timeline`. |

**Invariants**:
- Line fields remain the only required cue data.
- `timeline == null` ⇔ line-only cue.
- Adding or omitting `timeline` MUST NOT change `text`, `startMs`, `durationMs`, or `sourceKey`.
- `cueIdFor(line)` depends only on `startMs`, `endMs`, and plain `text` — never on `timeline`.

### TranscriptWord (new)

| Field | Required | Notes |
|-------|----------|-------|
| `text` | yes | Word substring. Empty text is not persisted (skipped on parse). |
| `startMs` | yes on write | Milliseconds **relative to the parent line**. JSON `start`. Defaults to 0 when omitted. |
| `durationMs` | yes on write | Duration (ms). JSON `duration`. Defaults to 0 when omitted. |
| `phones` | no | Ordered `PhoneTiming` spans. `null` when absent or empty. |

### TranscriptPhone (new)

Matches `@enjoy/alignment` `PhoneTiming`.

| Field | Required | Notes |
|-------|----------|-------|
| `phone` | yes | IPA / phone label. Empty label is skipped on parse. |
| `text` | yes | Display text; often the same as `phone`. |
| `startTime` | yes | Start in **seconds** (media timeline). |
| `endTime` | yes | End in **seconds**. |
| `wordIndex` | no | Index of the parent word in the line `timeline`. |

## Relationships

```text
TranscriptRow.timelineJson
  └── List<TranscriptLine>          # existing parse path
        ├── text / startMs / durationMs / sourceKey? / confidence?
        └── timeline? → List<TranscriptWord>
              ├── text / startMs / durationMs   # ms relative to parent line
              └── phones? → List<TranscriptPhone>
                    └── phone / text / startTime / endTime / wordIndex?
                        # seconds (PhoneTiming)
```

Existing producers (import, YouTube captions, ASR line grouping, Craft synthesis timings, auto-translate skeleton) emit **line-only** cues (`timeline` omitted).

## Validation

| Rule | Behavior |
|------|----------|
| Missing `timeline` / `phones` | Treat as absent |
| Empty list | Normalize to absent; omit on write |
| `timeline` not a JSON list | Ignore nested data; keep line |
| Word element not an object | Skip that element |
| Word `text` empty | Skip that word |
| Phone `phone` empty or missing | Skip that phone |
| Nested times missing | Word times default 0; phone times default 0 |
| Nested times outside cue window | Load as-is; do not rewrite line times |
| Unknown JSON keys | Ignore |

## Identity vs equality

| Mechanism | Uses nested data? |
|-----------|-------------------|
| `TranscriptLine.==` / `hashCode` | Yes (`timeline`, `confidence`) |
| `listEquals` on the lines stream | Yes (via `==`) |
| `cueIdFor` (blur / tap-reveal) | No |
| Auto-translate `sourceKey` | No |
| Current-line / echo window / tap-to-seek | No (line times / index) |
| `TranscriptLineTile` body text | No (`line.text` only) |

## State transitions

None. Nested data is inert storage. Later slices may populate `timeline` without changing this schema.

```text
line-only cue  --(later enrichment, out of scope)--> nested cue
nested cue     --(malformed nested parse)--> line-only cue (timeline dropped)
```

## Persistence

- Column: `transcripts.timeline_json` (TEXT, JSON array).
- No Drift migration.
- Historical rows without `timeline` remain valid (line-only cues, same as web).
- Read and write enjoy web keys only (`timeline`, `phones`).
