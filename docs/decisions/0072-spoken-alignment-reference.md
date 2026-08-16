# ADR-0072: Spoken alignment reference (eSpeak-NG waveform)

## Status

Accepted

## Context

ADR-0071 shipped `packages/forced_alignment` with MFCC, windowed DTW, flatten,
and typed failures. Its production `align()` path still built the reference
with a duration-model tone stand-in. pub.dev `espeak` is phonemize-only (no
`espeak_Synth` PCM, no word/phone `audio_position` events). Slice 3 cannot
trust those times. Issue #540 slice 2b requires a **spoken** same-language
reference before a production success.

This ADR supplements ADR-0071. It does **not** rewrite that document.

## Decision

1. **Production success requires a spoken reference** — eSpeak-NG
   `espeak_Synth` plus WORD/PHONEME events, compared to 16 kHz source PCM via
   the existing DTW path. Even stretch, tone stand-ins, and letter-split
   phones are not a production success.
2. **Stay in `packages/forced_alignment`** — thin `dart:ffi` wrap. No second
   path package. No pub.dev `espeak` production dependency. No Azure TTS as
   the alignment reference (Azure remains Craft playback).
3. **Vendored native + trimmed data** — `packages/forced_alignment/native/<os>/`
   plus `espeak-ng-data` for focus voices. Lazy `DynamicLibrary.open`. Do not
   compile eSpeak-NG on every `flutter test`.
4. **Fail closed** — missing lib/data/voice → `spokenReferenceUnavailable`,
   not `internal`, not a successful word list. Unmapped tags stay
   `unsupportedLanguage` with no silent language swap.
5. **Test doubles** — `align` / `alignSegments` accept an optional synthesizer
   for tests. Omitting it uses eSpeak-NG on a dedicated serial isolate
   (`EspeakSynthHost`). DTW isolates receive a finished `ReferenceAudio`
   only — they never call process-global eSpeak APIs.
6. **Still unused by product** — no Craft, panel, Settings, or playback of
   the reference. Learners never hear this PCM.
7. **License** — eSpeak-NG is GPL-3.0. Linking into this AGPL-3.0 app is
   accepted; record binaries in [packaging.md](../packaging.md).

## Consequences

- Quality goldens may skip when FFI/data is missing. Fail-closed tests always
  run.
- Slice 3 can treat `spokenReferenceUnavailable` as “keep today’s Craft
  transcript.”
- Platform binaries may land incrementally; a runner without a lib stays
  fail-closed.
