# Contract: IPA overlay and word-practice settings

**Keys**:

| Constant | Storage key | Registry `rowId` |
|----------|-------------|------------------|
| `SettingsKeys.transcriptIpaOverlay` | `transcript.ipaOverlay` | `ipaOverlay` |
| `SettingsKeys.transcriptWordPractice` | `transcript.wordPractice` | `wordPractice` |

**Store**: Device-global `SettingsDao` string `'true'` / `'false'`; missing ≡ `false`  
**Default**: both off

## Behavior

1. Fresh profile and wiped DB read **off** for both.
2. `setEnabled` persists immediately. The next play honors the new value without an app restart. A still-loading Settings read MUST NOT be treated as off if the persisted value is `'true'` (await the notifier future). Isolated widget tests that must not open SettingsDao override each notifier with an off implementation (same class of fix as karaoke).
3. Settings hub **Transcript** section row order: enrichment (slice 3), karaoke (slice 4), **IPA overlay**, **word-level practice**. Registry: `sectionId = transcript`.
4. Search matches localized titles and keywords (e.g. “IPA”, “pronunciation”, “word tap”, “word loop”).
5. Independent of each other, of `transcript.karaokeHighlight`, and of `transcript.timelineEnrichment`. Enrichment off + already-enriched cue + overlay on → still show stored IPA.
6. `transcript_panel` hydrates both providers during skeleton load.
7. Settings Dart sources MUST NOT import `package:forced_alignment/`.

## Tests

- Both keys allowlisted in `SettingsKeys.isKnown`.
- Each provider defaults false; `setEnabled(true)` round-trips.
- Registry / layout include both new rows after karaoke.
- Delayed persisted `'true'` still enables overlay / practice (loading ≠ off).
