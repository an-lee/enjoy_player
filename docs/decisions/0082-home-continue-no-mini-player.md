# ADR-0082: Home Continue practicing, no global mini player

## Status
Accepted

## Context
The collapsed `GlobalTransportBar` (mini player) let playback continue while browsing Home, Discover, and Library. That is a music-app pattern. Enjoy Player’s value is transcript practice on the player route. The mini bar could not host Echo, lookup, or assessment; it stacked with the floating tab bar; and it forced dual-mode packing (ADR-0035 expand recovery).

Home also lacked a first-class resume surface. Recents are “recently updated library rows,” not last practiced.

## Decision

1. **No mini player.** `GlobalTransportBar` mounts only on `/player/:id`.
2. **Leave player = leave playback.** Collapse, system back, or any navigation off `/player/` flushes `PlaybackSessionPersister` then `PlayerController.clear()`, except when vocabulary clip practice owns the video stage.
3. **Resume from Home.** A **Continue practicing** hero reads the latest `echo_sessions` row joined to still-present library media (position, Echo, languages, progress). Recents stay a browse grid.
4. **ADR-0035** in-player narrow packing (always-on play / echo / blur / CC / speed) remains. Collapsed-expand recovery (E1–E7) is **superseded**.
5. **`PlayerSurfaceHost` (ADR-0057) is unchanged.**

## Consequences
- Desktop “collapse and keep listening” is gone; learners reopen the player (Continue card or library item).
- Shell inset math no longer reserves mini-bar height.
- `player.toggleExpand` off-player no longer expands mini chrome (no live session after leave).
- Spec 007 mini-bar stories no longer apply.
