# ADR-0066: Park player surface while transient overlays are visible

## Status

Accepted

## Context

ADR-0057 mounts a permanent `PlayerSurfaceHost` above the shell UI. ADR-0065
routes Enjoy dialogs/sheets through the **root** navigator so Flutter chrome
can paint above the host in the widget tree.

On Windows, YouTube’s WebView2 (and similarly media_kit’s platform view) is a
native child window whose z-order is **not** fully controlled by Flutter’s
overlay stack. SnackBars, modal bottom sheets, and dialogs can therefore still
appear **under** the video surface even when they use the root navigator.

Competing WebView routes already use `PlayerSurfaceHost(forcePark: …)` (e.g.
`/youtube/login`). The same park mechanism is the reliable cross-platform fix
for all transient overlays.

## Decision

1. Introduce [`PlayerSurfaceOverlayCoordinator`](../../lib/core/player/player_surface_overlay_coordinator.dart):
   a ref-counted set of overlay tokens. While any token is held, the surface
   parks off-screen. (Amended by issue #663: the token set is watched inside
   `PlayerSurfaceHost` rather than `RootShell` — the original shell-level watch
   rebuilt the whole shell, nav and sidebar included, on every dialog / sheet /
   notice token change. `forcePark` remains the explicit shell-route flag, e.g.
   `/youtube/login`.)
2. Attach [`PlayerSurfaceOverlayNavigatorObserver`](../../lib/core/player/player_surface_overlay_navigator_observer.dart)
   to **both** the root and shell navigators so every `PopupRoute` (dialog,
   modal bottom sheet, menu) acquires/releases a token automatically — including
   raw `showDialog` / `showModalBottomSheet` call sites.
3. [`AppNotice`](../../lib/core/notices/app_notice.dart) acquires a token for the
   lifetime of each SnackBar (`SnackBarClosedReason` via `controller.closed`)
   because snackbars are not `PopupRoute`s.
4. Keep ADR-0065 root-navigator defaults for Enjoy modals (Flutter stacking +
   escape dismissal). Parking supplements that; it does not replace it.
5. In-stage player chrome continues to use `PlayerSurfaceTarget.overlayBuilder`
   (drawn inside the host) and must **not** acquire overlay tokens.

## Consequences

- Success/error notices and modals stay visible over YouTube on Windows.
- The WebView/media_kit surface stays mounted (parked off-corner); no engine
  teardown on overlay show/hide.
- New popup routes are covered without per-call-site flags as long as they go
  through a navigator observed by the coordinator.
- SnackBars must go through `AppNotice` (or acquire/release manually) to park.

## Related

- [ADR-0057](0057-permanent-player-surface-host.md)
- [ADR-0065](0065-enjoy-modals-root-navigator.md)
- [player.md](../features/player.md)
- [architecture.md](../architecture.md)
