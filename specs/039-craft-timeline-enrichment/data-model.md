# Data Model: Craft Timeline Enrichment

**Feature**: `039-craft-timeline-enrichment` | **Date**: 2026-08-16

No Drift schema change. Nested spans stay inside existing `transcripts.timeline_json` (ADR-0070). The new persisted fact is one SettingsDao row.

## Entities

### Enrichment setting

| Field | Type | Rules |
|-------|------|--------|
| key | `transcript.timelineEnrichment` | `SettingsKeys` static allowlist |
| value | `'true'` \| `'false'` \| missing | Missing ≡ off |
| default | off | Fresh profile / wiped DB |

Riverpod notifier exposes `AsyncValue<bool>`. `setEnabled` writes immediately; next Craft save reads the current value (no restart).

### Synthesis-timing transcript (unchanged)

Output of `buildCraftPrimaryTimelineJson`: JSON array of line-only cues `{text, start, duration}` (ms). `null` means blank primary transcript (spec 030).

### Enriched Craft cue

A `TranscriptLine` that still has required line fields plus optional `timeline`:

| Field | Storage | Rules |
|-------|---------|--------|
| text, start, duration | line ms | Unchanged from spec 030 |
| timeline[] | `TranscriptWord` | Omitted when empty |
| timeline[].text | string | From alignment word text |
| timeline[].start / duration | ms **relative to line** | `round((srcSec − lineStartSec) × 1000)` |
| timeline[].phones[] | `TranscriptPhone` | Omitted when empty / `low` |
| phones[].phone, text | string | Pronunciation label |
| phones[].startTime, endTime | seconds on **media** | Not relative to the line |
| phones[].wordIndex | int? | Index in **this line’s** `timeline` |

### Alignment request (Craft save)

| Input | Source |
|-------|--------|
| source PCM | 16 kHz mono Float32 from Craft `previewAudioBytes` |
| language | `state.synthLanguage` (must be a focus / alignment tag) |
| segments | one `AlignmentSegment` per line: `text`, `startTime`/`endTime` seconds, `id` = line index |
| granularity | `medium` (words + phones) |
| timeout | package per-cue default; overall save must still finish (fallback if exceeded) |

### Enrichment outcome (internal)

| Variant | Persist |
|---------|---------|
| skipped (setting off, blank 030 JSON, dedupe) | original `timelineJson` |
| success (all or some lines) | JSON of lines with nested spans on winners |
| failed (typed alignment failure or extract failure) | original line-only `timelineJson` |

## Validation

- Line `text` / `start` / `duration` MUST equal the pre-enrichment synthesis cue.
- Word starts MUST fall inside the parent window except a 50 ms pad.
- Negative duration after rounding → 0.
- Phone without a parent word on that line → drop the phone.
- Unmapped language or missing spoken reference → failed outcome, not a swapped voice.
- Deduped create → skipped (existing row untouched).

## State transitions

```text
Craft preview (audio + wordBoundaries)
        │
        ▼
buildCraftPrimaryTimelineJson
        │
   ┌────┴────┐
   │ null    │ non-null lines
   ▼         ▼
 blank     setting off? ──yes──► persist line-only
   save              │
                     no
                     ▼
              extract PCM
                     │
                fail? ──yes──► persist line-only
                     no
                     ▼
              alignSegments
                     │
         fail / timeout ──► persist line-only
                     │
                  success
                     ▼
         attachAlignmentToLines
                     ▼
         persist enriched JSON
```

## Relationships

- Enrichment setting → gates the Craft save branch only.
- Enriched cue → stored on the Craft item’s primary `source: 'ai'` transcript row.
- Secondary / translation tracks are not enriched this slice.
- Panel / echo / lookup continue to key off line fields only.
