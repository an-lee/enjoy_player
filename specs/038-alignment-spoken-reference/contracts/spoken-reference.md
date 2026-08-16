# Contract: Spoken reference

**Feature**: `038-alignment-spoken-reference`  
**Package**: `packages/forced_alignment`

The spoken reference is an **internal** alignment input. It is never the learner’s playback audio.

## Interface

```text
SpokenReferenceSynthesizer
  synthesize(text, language) → ReferenceAudio
```

- `language` is already a mapped focus tag (`kEspeakVoiceByLanguageTag`).
- Output PCM is 16 kHz mono Float32.
- Word/phone times are on the **reference** timeline (`audio_position` from the voice).
- No source-clip duration argument. Do not time-stretch the voice to the clip.

## Production implementation (eSpeak-NG)

| Step | API |
|------|-----|
| Init once per alignment isolate | `espeak_Initialize(AUDIO_OUTPUT_SYNCHRONOUS, …, dataPath, PHONEME_EVENTS \| PHONEME_IPA \| DONT_EXIT)` |
| Voice | `espeak_SetVoiceByName` for that tag only |
| Callback | `espeak_SetSynthCallback` — collect `int16` wav + `espeak_EVENT` |
| Speak | `espeak_Synth` UTF-8 |
| Events | `WORD` and `PHONEME`; `audio_position` in ms; attach phones via `text_position` / `length` |
| Resample | Native rate (often 22050) → 16 kHz in-package; no FFmpeg |
| Cancel | Callback returns `1` when the job is cancelled |

`DynamicLibrary.open` is lazy. Missing lib, data path, or voice → the **caller** sees `spokenReferenceUnavailable`, not a tone stand-in.

## Test doubles

Allowed in automated tests. A double MAY emit speech-like or synthetic PCM. It does **not** authorize `DurationModelSynthesizer` as the omitted-parameter production default.

Quality goldens (SC-003 / SC-004) MUST use the real production synthesizer or `skip` if FFI/data cannot load. They MUST NOT pass by feeding duration-model tones labeled as eSpeak.

## Must remain true

1. Learners never hear this PCM (no `Player()`, no Craft substitution).
2. Reference length MAY differ from the source clip.
3. Phone labels are pronunciation units from the voice, not a letter-split of “hello”.
4. No network / credits.
5. No second path package; no pub.dev `espeak` production dependency.
