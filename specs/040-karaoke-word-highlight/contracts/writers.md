# Contract: Writers and alignment (unchanged)

This slice is a reader. It MUST NOT start writing nested spans or running alignment.

## Must stay line-only writers

- Caption import
- YouTube captions
- Speech-to-text / ASR grouping
- Auto-translate overlay tracks
- Craft save (still slice 3: enrichment setting + fail-closed `alignSegments`)

## Must not run at play / open

- `align` / `alignSegments`
- PCM extract for alignment
- Library backfill
- Spoken-reference synthesis for display

## Import pins

| Root | `package:forced_alignment/` |
|------|-----------------------------|
| `lib/features/craft` | allowed (slice 3 save enricher) |
| `lib/data/subtitle`, `lib/data/audio` | allowed (mapper / PCM; matcher has **no** package import) |
| `lib/features/transcript` | **forbidden** |
| `lib/features/player` | forbidden (bucket constant only; no engine change) |
| `lib/features/asr` | forbidden |
| `lib/features/lookup` | forbidden |
| `lib/features/settings` | forbidden |
| `lib/l10n` | forbidden |

## Playback audio

Learner still hears lesson / Craft audio. Karaoke does not play a spoken alignment reference.

## Tests

- Existing Craft / import / YouTube / ASR line-only writer tests stay green
- Inert-import test still forbids transcript/settings from importing `forced_alignment`
- Opening an enriched item with karaoke on does not call alignment (no new enricher invocations in player/transcript)
