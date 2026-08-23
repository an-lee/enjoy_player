# Contract: Localization (Continue practicing)

**Date**: 2026-08-23  
**Feature**: [spec.md](./spec.md)

User-visible strings MUST be ARB keys under `lib/l10n/` (en + zh), then `flutter gen-l10n`.

## New keys (proposed names)

| Key | EN | ZH (intent) | Used on |
|---|---|---|---|
| `homeContinuePracticing` | Continue practicing | 继续练习 | Card title |
| `homeContinueProgressSemantics` | `{percent} percent complete` (or equivalent) | matching | Semantics when progress known |
| `homeContinueOpenSemantics` | Continue practicing, {title} | matching | Card activation |

Reuse existing keys where they already exist:

- `echoMode` — Echo badge
- YouTube / Craft provider badges on recents
- `focusLanguageLabel` catalog for language tags

Do **not** add a “Continue learning” string. Do not leave English hardcoded in widgets.

## Existing keys that may become unused

Mini-player chrome strings (e.g. expand / swipe-dismiss semantics on the collapsed bar) can be removed only if no remaining widget references them. Recents still uses `miniPlayerMediaVideo` / `miniPlayerMediaAudio` — do not delete those as part of this feature unless recents copy is changed (out of scope).
