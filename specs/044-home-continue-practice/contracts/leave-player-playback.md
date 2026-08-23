# Contract: Leave-player playback

**Date**: 2026-08-23  
**Feature**: [spec.md](./spec.md) | [research.md](../research.md)

Lifecycle contract for FR-007, FR-008, FR-009, FR-015.

## Player route (`/player/:mediaId`)

- `RootShell` may mount `GlobalTransportBar` as `Scaffold.bottomNavigationBar` when a live session exists (unchanged).
- Narrow packing (ADR-0035 C1–C6) still applies **on this route only**.
- Collapse chevron / back still leave the player route.

## Non-player routes (Home, Discover, Library, Profile, Settings, Vocabulary hub, …)

- **Must not** mount a collapsed / mini `GlobalTransportBar`.
- **Must not** keep audible/visible playback from the previous player visit.
- Snack/inset math must not reserve `kRootShellTransportSnackClearance` for a bar that is gone (bottom nav clearance unchanged).

## Leave `/player/`

1. Flush `PlaybackSessionPersister` for the current media (existing `clear()` flush).
2. `PlayerController.clear()` — engine `teardownAfterClear`, echo/blur deactivated, `PlaybackSession` null.
3. Then (or as a result of) pop/go to the previous shell route.

**Exception**: if `practiceOwnsVideoStage` is true, skip `clear()` so vocabulary clip practice keeps the engine. Still do not show a mini bar.

**Call sites**:

- `collapseExpandedPlayer` — clear before `context.pop()` when the exception does not apply.
- `RootShell` (or a dedicated listener) — if `session != null && !path.startsWith('/player/') && !practiceOwnsVideoStage`, clear. Covers system back.

## Hotkeys

After leave-player, `playerControllerProvider` is null, so play/pause/seek/expand-from-mini must not control a hidden session. `player.toggleExpand` no longer “expands mini chrome”; off-player resume is the Continue card or opening library media. In-player collapse hotkey unchanged.

## Surfaces that stay

- `PlayerSurfaceHost` (ADR-0057) — park/teardown as `clear()` already does; do not remove the host.
- Immersive review chrome hiding (spec 033) — unchanged; mini-bar suppress tests become “still no transport bar.”

## Removed mini-only affordances (spec 007 / ADR-0035 E1–E7)

- Swipe-down dismiss on a mini bar.
- Neutral-area tap-to-expand.
- Expand icon in the narrow budget (lowest-priority droppable) — only meaningful for mini chrome.
