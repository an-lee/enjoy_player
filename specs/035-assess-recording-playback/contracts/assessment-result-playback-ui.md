# Contract: Assessment Result Playback UI

**Surface**: `showAssessmentResultDialog` / `AssessmentResultDialog` / `AssessmentResultSheet`  
**Entry**: `triggerRecordingAssessment` in `recording_assessment_flow.dart`

## Inputs

| Param | Required | Notes |
|-------|----------|-------|
| `assessment` | yes | Existing Azure result |
| `localeTag` | yes (resolved) | Model pronounce locale |
| `recordingPath` | optional | Absolute take path; null/missing file → take & clip controls unavailable |

Call sites that open a result for a `RecordingRow` **MUST** pass `row.localPath`.

## Controls

### Full-take play (result chrome)

- Placement: near overall score / header of the result — always visible without selecting a word.
- States: disabled (no path) · idle · playing.
- Idle tap → start full take from beginning + karaoke mode.
- Playing tap → stop; clear karaoke current word.
- Distinct label/tooltip from model pronounce (localized “my recording” / play-stop variants).

### Karaoke word list

- While full-take playing: emphasize the chip whose timing contains current `positionMs`.
- Visual: additional “current” treatment on `_WordChip` (beyond score colors + selection).
- Stop/end/dismiss/chip-select: clear live current highlight.
- Words without usable timing never become current.

### Selected-word panel

| Control | Behavior |
|---------|----------|
| Model pronounce | Existing `PronounceIconButton` (standard pronunciation) |
| My clip | Play word interval from `recordingPath`; disabled when timing unusable or path missing |
| Labels | Distinct tooltips/a11y: standard vs my recording |

Chip tap:

1. Updates selection / detail (existing).
2. Stops full-take playback (spec assumption).
3. Stops previous clip; stops model pronounce (existing stop on chip change).

### Lifecycle

| Event | Must |
|-------|------|
| Dispose / dismiss dialog or sheet | Stop preview + model pronounce |
| Missing path | Scores and chips still usable |

## Timing helper (domain)

Pure functions (suggested module `assessment_word_timing.dart`):

- `azureTicksToMs(int ticks) → int`
- `isWordClipUsable(AzureWordAssessment) → bool`
- `activeWordIndex(words, positionMs) → int?`

UI MUST NOT hardcode tick math in widgets beyond calling these helpers.

## Non-goals

- Seek full take by tapping a chip during karaoke
- Per-chip play buttons on every chip
- Playing the lesson cue from the result surface
