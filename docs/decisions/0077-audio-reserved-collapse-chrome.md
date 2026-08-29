# ADR-0077: Audio expanded chrome is a reserved collapse strip

## Status
Superseded by [ADR-0085](0085-audio-floating-collapse-chrome.md) (audio chrome; video rules unaffected)

## Context
Video expanded chrome overlays the 16:9 stage (no reserved `AppBar` slot) so play/pause does not jump stage geometry. Audio reused the same overlay pattern: a transparent `AppBar` with `extendBodyBehindAppBar` when paused. Without a video stage, that chrome sat on the first transcript cue — often the same sentence as the media title — and looked broken. Hiding the AppBar while playing and wrapping the body in `SafeArea` caused a second layout jump. A title-less Material `AppBar` (chevron only) still read as a blank toolbar on mobile.

## Decision
- **Video** keeps in-stage overlay title chrome (unchanged; ADR-0059 layout rules still apply).
- **Audio** has **no** Scaffold `AppBar`. Collapse is a compact top-left chevron row inside [`AudioPlayerLayout`](../../lib/features/player/presentation/layouts/audio_player_layout.dart) (SafeArea + `kToolbarHeight`), so transcript never sits under floating chrome and there is no empty full-width toolbar. Title stays in the global transport bar.
- Ambient tint wraps the whole Scaffold so collapse chrome and transcript share one backdrop.

## Consequences
- Audio play/pause no longer toggles AppBar / SafeArea.
- Transcript cues stay top-aligned under the compact collapse row (same density padding as video columns).
- Docs that still described audio AppBar-with-title or HeroArtwork in the expanded player are updated.
