# Contract: Inert consumers (this slice)

Nested spans may exist on **new/re-saved Craft** items. Nothing else changes.

## Must stay line-only writers

- Caption import
- YouTube captions
- Speech-to-text / ASR grouping
- Auto-translate overlay tracks
- Craft save with enrichment **off**
- Craft save with enrichment on but fallback

## Must stay line-level readers

- Transcript panel render (no karaoke, IPA, word chips)
- Current-line tracking, tap-to-seek line
- Echo region, blur practice, dictionary lookup
- Auto-translate fingerprint / `cueIdFor` (line text + line times)

## Import pins

| Root | `package:forced_alignment/` |
|------|-----------------------------|
| `lib/features/craft` | **allowed** (save enricher only) |
| `lib/data/subtitle`, `lib/data/audio` | allowed for mapper / PCM helper |
| `lib/features/transcript` | forbidden |
| `lib/features/player` | forbidden |
| `lib/features/asr` | forbidden |
| `lib/features/lookup` | forbidden |
| `lib/features/settings` | forbidden |
| `lib/l10n` | forbidden |

## Playback

Learner hears Craft `previewAudioBytes` / saved WAV. Never the spoken reference.
