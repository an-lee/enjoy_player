# ADR-0085: Audio expanded chrome is a floating frosted collapse control

## Status
Accepted (supersedes the audio clause of ADR-0077; video rules unchanged)

## Context
ADR-0077 replaced audio's blank `AppBar` with a reserved in-body collapse strip (`SafeArea` + `kToolbarHeight` + plain chevron `IconButton`). The audio screen is transcript-only — title and playback chrome live in the global transport bar — so that 56px strip is a mostly-empty band above the transcript. In review it still read as a blank navbar with dead spacing, just slimmer.

Meanwhile the video stage already ships the right primitive: `PlayerFrostedBackButton`, a 38×38 frosted-glass chevron that floats over content. The concern that drove ADR-0077 (chrome sitting on the first transcript cue) is much weaker for a small glass circle: the transcript's active cue rests at `kTranscriptScrollAlignment` (0.42 of the viewport), so at rest only dimmed already-played cues pass near the top, and scrolled content blurs under the `BackdropFilter` instead of being hidden behind opaque chrome.

## Decision
- **Audio** has **no** Scaffold `AppBar` and **no** reserved collapse strip. Collapse is the shared [`PlayerFrostedBackButton`](../../lib/features/player/presentation/widgets/player_frosted_back_button.dart) floating top-left over the transcript column in [`AudioPlayerLayout`](../../lib/features/player/presentation/layouts/audio_player_layout.dart) (same control, size, and placement rhythm as the video stage). Transcript cues scroll under its blur. Title stays in the global transport bar.
- Transcript column keeps the centered `contentMaxWidth` cap with `space12` side insets and `space16` bottom inset. Desktop windows have no status-bar inset, so the column gets a roomier `space32` top inset for optical balance (`isDesktop`).
- Ambient tint still wraps the whole Scaffold so the floating control and transcript share one backdrop.

## Consequences
- The blank navbar band is gone; audio and video now share one collapse affordance.
- Transcript content can pass under the frosted control while scrolling — deliberate glass depth, not occlusion (active cue never rests there).
- Play/pause still toggles no chrome (inherited from ADR-0077).
- `AudioPlayerLayout` tests assert the floating control, the absence of a `kToolbarHeight` strip, and the desktop/mobile top insets.
