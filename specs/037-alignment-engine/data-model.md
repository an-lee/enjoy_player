# Data Model: Alignment Engine

**Feature**: `037-alignment-engine` | **Date**: 2026-08-15

No Drift tables. The engine does not read or write `transcripts.timeline_json`. Slice 1 nested cues remain the **storage** model; this slice’s model is the **engine result** plus a flatten view.

## Entities

### AlignmentRequest

| Field | Required | Notes |
|-------|----------|-------|
| `sourcePcm16k` | yes | Mono Float32 at 16 kHz. Empty → `tooShort` / `audioUnavailable`. |
| `transcript` | yes | Known text. Blank/whitespace → `blankText`. Not rewritten on success. |
| `language` | yes | BCP-47. Unmapped → `unsupportedLanguage`. |
| `granularity` | no | `low` \| `medium` (default) \| `high`. |
| `timeout` | no | Default 2 min whole-clip / 30 s per cue. |
| `cancel` | no | Cooperative cancel token. |

Whole-clip duration = `sourcePcm16k.length / 16000`. If `> 90` s → `wholeClipTooLong`.

### AlignmentSegment (per-cue)

| Field | Required | Notes |
|-------|----------|-------|
| `text` | yes | Cue line text (display source of truth for later slices). |
| `startTime` | yes | Seconds on the source audio. |
| `endTime` | yes | Seconds; must be `> startTime`. |
| `id` | no | Caller cue index; echoed on that segment’s result. |

Window duration `< 1.0` s → that cue fails `tooShort`; siblings still run.

### TimelineEntry (Echogarden-shaped)

| Field | Required | Notes |
|-------|----------|-------|
| `type` | yes | `segment` \| `sentence` \| `word` \| `token` \| `phone` (v1 uses these). |
| `text` | yes | Entry text; empty entries are dropped. |
| `startTime` | yes | Seconds, source audio. |
| `endTime` | yes | Seconds, `>= startTime`. |
| `timeline` | no | Children; omitted at leaves. |
| `confidence` | no | Unused this slice; reserved. |
| `id` | no | Echo of [AlignmentSegment.id] on successful `segment` entries. |

**Invariants**: Times are source-relative. `alignSegments` adds the cue `startTime` offset after local alignment. Recursive depth is finite (segment → word → phone is enough for flatten).

### AlignmentResult

| Field | Required | Notes |
|-------|----------|-------|
| `timeline` | yes | Root entries (usually one segment). |
| `wordTimeline` | yes | Flattened word entries (may be empty only for punctuation-only text). |
| `transcript` | yes | Echo of request text (unchanged). |
| `language` | yes | Echo of request language. |
| `durationSeconds` | yes | `pcm.length / 16000`. |

Success with `wordTimeline.isEmpty` is **only** valid when the transcript has no alignable words. Typed failures never use this object.

### WordTiming / PhoneTiming (flatten view, enjoy web)

Same meaning as `@enjoy/alignment` / slice 1 phones:

| WordTiming | PhoneTiming |
|------------|-------------|
| `text`, `startTime`, `endTime` (seconds) | `phone`, `text`, `startTime`, `endTime`, optional `wordIndex` |

`flattenToWordPhoneTimings` walks `type==word` / `type==phone`. Phones without a parent word are dropped. `low` granularity yields phones = empty/absent.

### AlignmentFailure

| Reason | When |
|--------|------|
| `audioUnavailable` | PCM missing/null; YouTube/non-extractable (callers map to this). |
| `tooShort` | Duration `< 1.0` s (whole clip or a single cue). |
| `blankText` | Transcript empty after trim. |
| `unsupportedLanguage` | No eSpeak voice mapping for the tag. |
| `wholeClipTooLong` | Whole-clip `> 90` s. |
| `cancelled` | Cancel token fired. |
| `timedOut` | Timeout elapsed. |
| `internal` | Synth/DTW/FFI error; message for logs only (`Logger('forced_alignment')`, never `print`). |

Public API returns `Result`-style success **or** `AlignmentFailure` (no transcript I/O).

## Relationships

```text
AlignmentRequest
  ├── sourcePcm16k + transcript + language
  └── optional List<AlignmentSegment>
        └── alignSegments → AlignmentResult.timeline[] (one segment per cue)

AlignmentResult
  ├── timeline: List<TimelineEntry>          # recursive
  ├── wordTimeline: List<TimelineEntry>      # words
  └── flattenToWordPhoneTimings
        ├── List<WordTiming>
        └── List<PhoneTiming>  # wordIndex → WordTiming index
```

Slice 3 (out of scope) maps flatten output onto `TranscriptLine.timeline` / `TranscriptWord.phones` without changing line `text`/`start`/`duration`.

## Validation

| Rule | Behavior |
|------|----------|
| Blank text | `blankText`; no DTW |
| PCM length `< 16000` | `tooShort` |
| Whole-clip `> 90` s | `wholeClipTooLong` |
| Per-cue window `< 1` s | That cue `tooShort`; others continue |
| Unmapped language | `unsupportedLanguage` |
| Cancel | `cancelled`; isolate work dropped |
| Timeout | `timedOut` |
| `low` granularity | Words only; phones absent |
| Phone without `wordIndex` | Drop on flatten |
| Unknown `TimelineEntry.type` | Ignore on flatten; keep in recursive tree |

## Identity vs storage

| Mechanism | This slice |
|-----------|------------|
| Drift / `timeline_json` | Untouched |
| `cueIdFor` / `sourceKey` | Untouched |
| Engine result equality | Tests compare word count/order; times within 50 ms |

## Persistence

None. No DAO, no settings key, no cache table.
