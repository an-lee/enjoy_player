# Contract: Continue practicing card (Home)

**Date**: 2026-08-23  
**Feature**: [spec.md](./spec.md) | [data-model.md](../data-model.md)

UI contract for the Home hero that replaces the global mini player as the resume surface.

## Placement

- Screen: Home (`/`), inside the existing `EnjoyPage` browse body.
- Order: Editorial header → insight strip (Today’s Goal / Community) → **Continue card** (if present) → Recents label + grid (or existing empty state).
- The card is in the first screenful on phone and desktop (spec SC-006). Horizontal padding is page gutter; width follows browse layout (no new max-width).

## Visibility

| Condition | Card |
|---|---|
| `PracticeResume` stream emits a value | Shown |
| Stream emits `null` (never practiced, empty library, or last sessions’ media gone) | Hidden |
| Recents loading skeleton | Hidden or a single hero skeleton — must not show a fake title |

## Content

| Slot | Required | Copy / data |
|---|---|---|
| Section / card title | Yes | Localized **Continue practicing** (not “Continue learning”) |
| Artwork | Yes | Existing thumbnail file / network URL / generative cover (`coverSeed`); 16:9 hero |
| Media title | Yes | `Media.title` |
| Source | When known | Provider badge (YouTube / Craft) and/or `Media.source` |
| Echo | When `echoActive` | Localized Echo label |
| Language pair | When at least one side known | Content · native (see research) |
| Progress | When `progress != null` | Determinate bar; not color-only (keep a fill + track) |

## Interaction

- Whole card is one tappable surface (`EnjoyTappableSurface` or equivalent primitive).
- On activate: `openPlayerRoute(context, media.id)` (same open path as recents). Existing relocate / missing-file errors apply; Home must not crash.
- Haptics: light feedback consistent with other cards.
- Semantics: button/role with name including Continue practicing + media title; progress as a value when known.

## Visual distinction from recents

- Hero 16:9 (prototype intent), not a `MediaCardTile` poster in the grid.
- Recents grid is unchanged (browse). Duplicate title in both is allowed.

## Non-goals

- Play/pause on the card.
- Seek from Home.
- Queue / “up next.”
- Greeting/avatar redesign.
