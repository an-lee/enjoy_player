# ADR-0065: Enjoy modals use the root navigator by default

## Status

Accepted

## Context

ADR-0057 mounts a permanent `PlayerSurfaceHost` as a sibling **above** the
shell UI stack inside `RootShell`. Flutter dialogs and modal bottom sheets that
use the nearest (shell) navigator therefore paint **under** the YouTube /
media_kit platform view. That repeatedly covered player-context UI
(dictionary lookup, practice poster, pronunciation assessment results, subtitle
picker, playback rate sheet).

Call-site opt-in (`useRootNavigator: true`) fixed individual sheets but
regressed whenever a new Enjoy modal opened from the player without the flag.

## Decision

1. [`showEnjoySheet`](../../lib/core/theme/widgets/enjoy_modal.dart),
   `showEnjoyDialog`, `showEnjoyAlertDialog`, and `showEnjoyAdaptiveSheet`
   default `useRootNavigator` to **`true`** so Enjoy modals clear the permanent
   surface host.
2. Pass `useRootNavigator: false` only for intentional shell-scoped
   presentation (rare).
3. Prefer Enjoy modal helpers over raw `showDialog` /
   `showModalBottomSheet` on player paths so the default applies.
4. Keep distinct patterns for non-modal chrome:
   - In-stage controls → `PlayerSurfaceTarget.overlayBuilder`
   - Competing WebView route → `PlayerSurfaceHost(forcePark: …)`

## Consequences

- New Enjoy modals stay above YouTube without per-call flags.
- Escape dismissal already checks shell then root
  ([hotkeys.md](../features/hotkeys.md)); root-presented modals remain
  dismissible.
- Supplements [ADR-0057](0057-permanent-player-surface-host.md).

## Related

- [ADR-0057](0057-permanent-player-surface-host.md)
- [player.md](../features/player.md)
- [architecture.md](../architecture.md)
