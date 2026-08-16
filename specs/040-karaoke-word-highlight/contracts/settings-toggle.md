# Contract: Karaoke setting

**Key**: `transcript.karaokeHighlight` (`SettingsKeys.transcriptKaraokeHighlight`)  
**Store**: Device-global `SettingsDao` string `'true'` / `'false'`; missing ≡ `false`  
**Default**: off

## Behavior

1. Fresh profile and wiped DB read **off**.
2. `setEnabled` persists immediately. The next play honors the new value without an app restart. A still-loading Settings read MUST NOT be treated as off if the persisted value is `'true'` (await the notifier future / `resolveEnabled`).
3. Settings hub **Transcript** section has two rows: enrichment (slice 3) then karaoke. Registry: `sectionId = transcript`, `rowId = karaokeHighlight`.
4. Search matches localized title and keywords (e.g. “karaoke”, “word highlight”, “timings”).
5. Independent of `transcript.timelineEnrichment`. Enrichment off + already-enriched cue + karaoke on → still highlight.
6. Settings Dart sources MUST NOT import `package:forced_alignment/`.

## Tests

- Key is allowlisted in `SettingsKeys.isKnown`.
- Provider defaults false; `setEnabled(true)` round-trips.
- Registry / layout include the new row.
- Delayed `true` still enables highlight (same class of bug as slice 3 settings load).
