# Contract: Enrichment setting

**Key**: `transcript.timelineEnrichment` (`SettingsKeys.transcriptTimelineEnrichment`)  
**Store**: `SettingsDao` string `'true'` / `'false'`; missing ≡ `false`  
**Default**: off

## Behavior

1. Fresh profile and wiped DB read **off**.
2. `setEnabled` persists immediately. The next `saveToLibrary` honors the new value without an app restart.
3. Settings hub shows a **Transcript** section with one switch row (title + subtitle from ARB). The row is in the section registry (spec 004): `sectionId = transcript`, `rowId = timelineEnrichment`.
4. Search matches localized title and keywords (e.g. “enrichment”, “alignment”, “timeline”).
5. Settings Dart sources MUST NOT import `package:forced_alignment/`. They only read/write the bool.

## Tests

- Key is allowlisted in `SettingsKeys.isKnown`.
- Provider defaults false; `setEnabled(true)` round-trips.
- Registry / layout include the new section and row.
- Inert-import pin no longer forbids the key; it asserts the key exists.
