# Contract: Writers and alignment (unchanged)

This slice is a reader. It MUST NOT start writing nested spans, running alignment, or generating IPA for line-only cues.

## Must stay line-only writers

- Caption import
- YouTube captions
- Speech-to-text / ASR grouping
- Auto-translate overlay tracks
- Craft save (still slice 3: enrichment setting + fail-closed `alignSegments`)

## Must not run at play / open / tap / overlay toggle

- `align` / `alignSegments`
- PCM extract for alignment
- Library backfill
- Spoken-reference synthesis for display
- G2P / ipa-dict / Worker phonemizer / LLM IPA batch (#527 remainder)

## Import pins

| Root | `package:forced_alignment/` |
|------|-----------------------------|
| `lib/features/craft` | allowed (slice 3 save enricher) |
| `lib/data/subtitle`, `lib/data/audio` | allowed (mapper / PCM; IPA helper has **no** package import) |
| `lib/features/transcript` | **forbidden** |
| `lib/features/player` | forbidden (loop enforcer seeks the existing engine only) |
| `lib/features/asr` | forbidden |
| `lib/features/lookup` | forbidden |
| `lib/features/settings` | forbidden |
| `lib/l10n` | forbidden |

## Playback audio

Learner still hears lesson / Craft audio. Overlay, loop, and inspect do not play a spoken alignment reference. No new `media_kit` `Player()`.

## Tests

- Existing Craft / import / YouTube / ASR line-only writer tests stay green
- Inert-import test still forbids transcript/settings/player/l10n from importing `forced_alignment`
- Opening an enriched item with overlay or practice on does not call alignment
- Overlay on a line-only cue does not add IPA
