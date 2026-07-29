# Contract: Pronounce Control UI

## Shared widget

One control (e.g. `PronounceIconButton`) with:

| Prop | Meaning |
|------|---------|
| `text` | Target phrase |
| `localeTag` | Surface language tag |
| `enabled` | Parent may force-disable |
| `compact` | Flashcard/assessment density vs lookup 44×44 |

### Visual states

| State | Icon intent | A11y / tooltip |
|-------|-------------|----------------|
| Idle (ready) | Speaker / volume-up style | Play pronunciation |
| Loading | Progress in icon button | Loading pronunciation |
| Playing | Stop (or speaker-off) | Stop pronunciation |
| Disabled | Dimmed speaker | Unavailable reason (empty / unsupported language / signed-out optional) |

Tap target ≥ existing tonal icon buttons (~44 logical px on lookup header).

Use `EnjoyTappableIcon` / established icon-button chrome; haptics on successful tap; ARB strings only.

## Placement

| Surface | Location | Target text / locale |
|---------|----------|----------------------|
| Lookup | Header action row: pronounce before or after bookmark, with copy/close | `request` selection / source language |
| Flashcard front | Row with headword (not overlapping flip hint) | Headword / learning or card language |
| Flashcard back | Header next to headword above tabs | Same as front |
| Assessment | Selected-word panel header only | Selected chip word / assessment language |

### Must not

- Put pronounce inside flashcard Context `_MediaAction` chip row.
- Put pronounce on every assessment chip.
- Replay user assessment recording from this control.

## Cancel hooks

| Event | Action |
|-------|--------|
| Lookup sheet dispose | `stop()` |
| Flashcard flip or rate / next card | `stop()` |
| Assessment chip change or dialog dispose | `stop()` |
