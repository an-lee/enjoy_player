# Contract: Craft save enrichment

**Caller**: `CraftController.saveToLibrary`  
**Engine**: `alignSegments` from `package:forced_alignment` (production synthesizer; no duration-model)

## Preconditions (all required)

1. Enrichment setting is on.
2. `buildCraftPrimaryTimelineJson` returned non-null (solid synthesis lines).
3. This save is a real write (`importCraftedFromText` or `updateCraftedFromText`), not a dedupe hit.
4. `previewAudioBytes` can be decoded to 16 kHz mono Float32.

If any precondition fails, persist the spec 030 `timelineJson` (or `null`) unchanged.

## Call

```text
alignSegments(
  sourcePcm16k: extracted,
  language: synthLanguage,
  segments: [
    for (i, line) AlignmentSegment(
      text: line.text,
      startTime: line.startSeconds,
      endTime: line.endSeconds,
      id: i,
    )
  ],
  granularity: AlignmentGranularity.medium,
)
```

Do not call `align()` whole-clip for this path. Do not synthesize a spoken reference of the entire multi-line script as one utterance when line windows exist.

## Persist

- Success → `jsonEncode` of `attachAlignmentToLines` output (same line count/order).
- Failure → original spec 030 JSON.
- Partial → nested spans only on lines that received a tagged successful segment.

## Non-goals

- Playing the spoken reference.
- Writing nested spans onto import / YouTube / ASR tracks.
- Changing `sourceFlag`, dedupe key, or audio bytes.
