# Data Model: Craft Shadow-Friendly Transcript Cues

**Feature**: `032-craft-shadow-cues` | **Date**: 2026-07-30

This feature touches **no database schema and no persistent format change**. The data model below documents the in-memory entities the segmenter and plugin produce/consume, the values derived from research (R7), and the validation rules mapped to the spec's FRs.

---

## 1. Persistent entities (unchanged)

### `transcripts.timelineJson` — wire format (unchanged, FR-013)

| Field | Type | Source | Notes |
|---|---|---|---|
| `text` | `String` | joined `CraftWordBoundary.text` of the segment | Non-empty; never starts with punctuation-only chars. |
| `start` | `int` (ms) | first boundary's `audioOffsetMs` | FR-008. |
| `duration` | `int` (ms) | `(lastBoundary.audioOffsetMs + lastBoundary.durationMs) − start` | FR-008. Spans only the spoken words of this line. |

Serialized as `jsonEncode([{'text': ..., 'start': ..., 'duration': ...}, ...])`. `sourceKey` is never emitted by the Craft path. Decoded defensively by `TranscriptLine.fromJson` (`?? ''`, `?? 0`).

**No Drift table, column, or DAO change.** `primaryTimelineJson: String?` is already nullable on both `importCraftedFromText` and `updateCraftedFromText`.

---

## 2. In-memory entities (segmenter)

### `CraftWordBoundary` (unchanged shape — R9.2)

```
CraftWordBoundary { String text; int audioOffsetMs; int durationMs; }
```

Adapter-1:1 with `AzureWordBoundary`. Keep 3 fields — no `boundaryType` (the ObjC enum is defective, R8 gotcha 2; classification is by text).

### `TranscriptSegment` (unchanged shape — keep, enrich construction)

```
TranscriptSegment { String text; int startMs; int durationMs; }
```

Construction rules change (see §3); the type itself is unchanged.

### New: `ShadowLineBudget` (segmenter config — pure values, R7)

A small const bundle holding the research-derived duration thresholds so they are tunable in one place and testable in isolation:

| Field | Value | Source / FR |
|---|---|---|
| `minLineMs` | `1200` (1.2 s absolute floor) | R7, FR-003 |
| `targetMinMs` | `1500` (practical target floor) | R7 |
| `softMaxMs` | `6000` (preferred split point) | R7, FR-003 |
| `hardMaxMs` | `7000` (no line may exceed) | R7, FR-003 |
| `pauseGapMs` | `250` (inter-word silence counted as a "natural pause") | R5; below this a gap is not a meaningful breath break |

These are the only "magic numbers"; they are the output of research and are the values SC-002 measures against.

### New: `BreakPriority` (enum, internal to segmenter)

Order in which a split point is preferred when a line would otherwise exceed `softMaxMs` (FR-004):

1. `sentenceEnd` — `.。！？!?`
2. `clauseMark` — `,;:—、，；：` (FR-005)
3. `silenceGap` — largest inter-word gap ≥ `pauseGapMs` (FR-004)
4. `hardCap` — forced at `hardMaxMs` when nothing better is available (Edge Case: long unpunctuated sentence)

Word count is **not** a break trigger; it is at most a last-resort tiebreaker inside `hardCap`.

---

## 3. Segmentation algorithm (state transitions)

Input: `List<CraftWordBoundary>` + `String language` (for CJK detection, FR-006).

```
raw boundaries
   │
   ▼
[mergePunctuationTokens]      # unchanged (FR-007): standalone punct → prior word,
   │                          # extend timing to later end; drop leading punct
   ▼
words (punctuation-merged)
   │
   ▼
[detect script]               # primaryLanguageSubtag(language) ∈ {zh,ja,ko} → isCJK
   │
   ▼
[partition into sentences]    # split at sentence-end boundaries (.。！？!?)
   │
   ▼ per sentence:
[shadow-split]                # accumulate words while spoken span < softMaxMs
   │                          #   when span would exceed softMaxMs:
   │                          #     choose break = best priority candidate in window
   │                          #     (sentenceEnd already handled above; here:
   │                          #      clauseMark > largest silenceGap > hardCap)
   │                          #   CJK path: ignore word count entirely (FR-006);
   │                          #   Latin path: word count only as hardCap tiebreaker
   ▼
candidate lines
   │
   ▼
[mergeShortFragments]         # any standalone line < minLineMs merges into neighbor
   │                          # (FR-003: no orphan single-word/too-short lines)
   ▼
List<TranscriptSegment>
   │
   ▼ per segment:
   text  = join(words.text, isCJK ? '' : ' ')   # spaceless join for CJK
   start = first.audioOffsetMs                   # FR-008
   dur   = (last.audioOffsetMs + last.durationMs) − start   # FR-008
   │
   ▼
segmentsToTimelineJson         # unchanged wire encoder
```

### Validation rules (map to FRs)

| Rule | FR | Enforcement |
|---|---|---|
| Empty boundaries → `[]` / `null` | FR-011 | `mergePunctuationTokens` returns `[]`; `segmentWordBoundaries` returns `[]`; `buildCraftPrimaryTimelineJson` returns `null`. |
| Punctuation-only input → `null` | FR-011 | After merge, no words remain → `[]` → `null`. |
| No line starts with punctuation-only text | FR-007 | `mergePunctuationTokens` guarantees this before segmentation. |
| Line duration ≤ `hardMaxMs` | FR-003 | `shadow-split` forces a break at `hardMaxMs`. |
| No standalone line < `minLineMs` | FR-003 | `mergeShortFragments` absorbs into a neighbor. |
| Break priority order | FR-004 | `BreakPriority` enum drives candidate selection. |
| Clause punctuation honored | FR-005 | `clauseMark` set includes `,;:—、，；：`. |
| CJK: no word-count rule | FR-006 | `isCJK` branch skips word-count; uses punctuation + duration + gaps. |
| Timing = first onset → last release | FR-008 | Segment text/timing construction. |
| Wordcount = crafted text (no STT) | FR-010 | Segmenter consumes only `CraftWordBoundary` derived from synthesis; never calls ASR. |
| Solid gate unchanged | FR-011 | Non-empty boundaries **and** ≥1 segment → save; else blank (ADR-0063). |
| Wire format unchanged | FR-013 | `segmentsToTimelineJson` emits `[{text,start,duration}]`. |

---

## 4. Native plugin entity (Swift → JSON)

No new persistent entity. The iOS/macOS `performSynthesis` changes from returning `{audio, wordBoundaries: []}` to returning `{audio, wordBoundaries: [{text, audioOffset, duration}, ...]}` where:

| JSON key | Swift source | Unit |
|---|---|---|
| `text` | `eventArgs.text` | String |
| `audioOffset` | `eventArgs.audioOffset` | ticks (100-ns) — emit verbatim |
| `duration` | `Int(eventArgs.duration * 10_000_000)` | ticks — **converted from seconds** (R8 gotcha 1) |

`boundaryType` is **not** emitted (defective enum + unused by Dart parser). Punctuation boundaries fire with the punctuation as `text` and are forwarded verbatim; the Dart `mergePunctuationTokens` classifies them.

---

## 5. Entities NOT introduced (explicit non-changes)

- No new Drift table, column, or migration.
- No change to `CraftWordBoundary` / `TranscriptSegment` / `AzureWordBoundary` field sets.
- No change to `CraftSynthesisResult`.
- No change to `TranscriptLine.fromJson` / `toJson`.
- No `boundaryType` field on any model.
- No new transcript `source` value (stays `'ai'`).
- No change to Craft audio storage identity (`provider` / `source` flags) or badge behavior.
