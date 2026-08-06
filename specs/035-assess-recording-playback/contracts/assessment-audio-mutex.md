# Contract: Assessment Result Audio Mutex

**Goal**: At most one audible stream among full take, word clip, and model pronunciation while the assessment result is open (FR-008, SC-004).

## Engines involved

| Stream | Engine | Owner |
|--------|--------|-------|
| Full take / word clip | `RecordingPreviewPlayer` (`media_kit` preview) | `recordingPreviewPlayerProvider` |
| Model pronounce | `PronouncePlaybackController` (`audioplayers`) | `pronouncePlaybackControllerProvider` |

These engines do **not** automatically stop each other today. The assessment result surface **MUST** enforce the rules below.

## Rules

| Trigger | Actions |
|---------|---------|
| Start full take | `PronouncePlaybackController.stop()` then preview play from start |
| Start word clip | `PronouncePlaybackController.stop()` then preview `playClip` |
| Start model pronounce | Stop preview (full/clip) then existing pronounce `play` |
| Select different word chip | Stop preview if in full-take or clip mode; stop pronounce (existing) |
| Stop control / natural end | Clear the active engine’s playing state; karaoke index cleared if full-take ended |
| Dismiss / dispose result | Stop preview **and** pronounce |

## Invariants

1. Never leave preview and pronounce both `playing == true` after a user action settles.
2. Starting any of the three actions is idempotent w.r.t. overlap: previous stream is stopped before the new one becomes audible.
3. Lookup / flashcard pronounce surfaces are unchanged unless a shared “stop preview before pronounce” helper is extracted; if extracted, it MUST be opt-in from assessment (or a documented global policy). Prefer assessment-local coordination in v1.

## Verification

- Widget or integration-style tests: mock/fake both notifiers; assert stop ordering on play transitions.
- Manual: play model → play clip → play full take → dismiss; never two voices.
