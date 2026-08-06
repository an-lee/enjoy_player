# Data Model: Assessment Recording Playback

**Feature**: `035-assess-recording-playback` | **Date**: 2026-08-06

No new Drift tables. This feature interprets existing assessment + recording entities for playback.

## Entities

### Recording take (existing)

| Field | Role |
|-------|------|
| `id` | Stable take identity for assessment controller |
| `localPath` | Absolute path to learner WAV (full take + clips) |
| `assessmentJson` | Persisted Azure SDK JSON (PascalCase `Words[].Offset` / `Duration` in ticks) |
| `pronunciationScore` | Aggregate score badge (unchanged) |
| `duration` | Take length in **ms** (row metadata; not word timing) |
| `language` | Used for pronounce locale resolution (unchanged) |

**Validation**: Play controls require non-empty `localPath` and file exists. Missing file → disable take/clip; scores still show.

### Assessment result (existing)

| Field | Role |
|-------|------|
| `AzurePronunciationAssessmentResult` | Parsed detail for UI |
| `nBest.first.words` | `List<AzureWordAssessment>` for chips / karaoke / clips |
| Aggregate scores | Ring + bars (unchanged) |

### Timed assessed word (view of `AzureWordAssessment`)

| Field | Source | Notes |
|-------|--------|-------|
| `word` | `word` | Display + model pronounce text |
| `offsetTicks` | `offset` | Azure ticks |
| `durationTicks` | `duration` | Azure ticks |
| `startMs` | derived | `(offsetTicks / 10000).round()` |
| `endMs` | derived | `startMs + (durationTicks / 10000).round()` |
| `errorType` | nested pronunciation assessment | Omission → clip unavailable |
| `accuracyScore` | nested | Existing chip colors |
| `clipUsable` | derived | `durationTicks > 0` && not omission && take path playable |

### Word clip (ephemeral)

| Field | Notes |
|-------|-------|
| `path` | Same as take `localPath` |
| `start` | `Duration(milliseconds: startMs)` |
| `end` | `Duration(milliseconds: endMs)` |

No persistence; played via preview player.

### Karaoke playback position (ephemeral UI state)

| Field | Notes |
|-------|-------|
| `mode` | `idle` \| `fullTake` \| `wordClip` |
| `positionMs` | From preview `position` stream while `fullTake` |
| `activeWordIndex` | Index into words list, or null |
| `selectedWord` | Chip selection (existing) |

**Transitions**:

```text
idle --play full--> fullTake --stop/end/dismiss/chip select--> idle
idle --play clip--> wordClip --stop/end/dismiss/word change--> idle
fullTake --play clip / model--> stop fullTake then other stream
any --start model pronounce--> stop preview first
```

## Relationships

```text
RecordingRow.localPath ──plays──► RecordingPreviewPlayer
RecordingRow.assessmentJson ──parse──► AzurePronunciationAssessmentResult
       └── words[] ──timing──► karaoke index + Word clip bounds
Selected word ──model──► PronouncePlaybackController (existing)
Selected word ──clip──► RecordingPreviewPlayer.playClip
```

## Invariants

1. At most one audible stream among {full take, word clip, model pronounce} on the result surface.
2. Karaoke `activeWordIndex` is set only while `mode == fullTake` and playing.
3. Word clip interval equals that word’s assessment timing; never invent intervals for omissions.
4. Dismissing the result clears preview playback and model pronounce from this surface.
