# Research: Spoken Alignment Reference

**Feature**: `038-alignment-spoken-reference` | **Date**: 2026-08-16

Slice 2 (`packages/forced_alignment`) already ships MFCC, windowed DTW, flatten, isolate, and typed failures. Its production `align()` path still builds the reference with `DurationModelSynthesizer` (tone bursts stretched to the clip length + English fixture G2P / letter fallback). `espeakFfiIsAvailable()` is always false. This research locks how slice 2b replaces that stand-in.

## Decisions

### 1. Stay in `packages/forced_alignment`; do not add a second path package

**Decision**: Implement spoken-reference synthesis inside the existing path package (`lib/src/synth/`). Do **not** add `packages/enjoy_espeak`. Do **not** add a pub.dev `espeak` production dependency.

**Rationale**: ADR-0029 already allowlists `forced_alignment`. A second path package is another supply-chain row for the same native library. pub.dev `espeak` 0.1.x is phonemize-only (no `espeak_Synth` PCM, no word/phone `audio_position` events). Depending on it would not satisfy FR-002 / FR-004.

**Alternatives considered**:
- `packages/enjoy_espeak` — extra allowlist + two packages sharing one GPL binary; rejected.
- Wait for upstream `espeak` to grow synth — review latency; slice 3 cannot trust timings until this lands.
- Cloud / Azure TTS as the alignment reference — credits, not offline, and the spec forbids replacing Craft playback audio; Azure stays **playback** only.

### 2. Production synthesizer is eSpeak-NG `espeak_Synth` + event callback

**Decision**: Production `SpokenReferenceSynthesizer` is a thin `dart:ffi` wrap of eSpeak-NG:

1. `espeak_Initialize(AUDIO_OUTPUT_SYNCHRONOUS, …, dataPath, espeakINITIALIZE_PHONEME_EVENTS | espeakINITIALIZE_PHONEME_IPA | espeakINITIALIZE_DONT_EXIT)`
2. `espeak_SetVoiceByName` from existing `kEspeakVoiceByLanguageTag` (no silent language swap)
3. `espeak_SetSynthCallback` — collect `int16` PCM chunks and `espeak_EVENT` (`WORD`, `PHONEME`)
4. `espeak_Synth` with `espeakCHARS_UTF8`
5. Convert PCM to 16 kHz mono Float32 (linear resample if native rate is 22050)
6. Map events onto `ReferenceWord` / `ReferencePhone` using `audio_position` (ms) and `text_position` / `length`

Initialize **once per alignment isolate**. eSpeak-NG is not treated as UI-isolate-safe. `AUDIO_OUTPUT_SYNCHRONOUS` so `espeak_Synth` finishes before the worker returns. Synth callback returns `1` when the job’s cancel token fires.

**Rationale**: Same family as Echogarden / `@enjoy/alignment`. Offline, no credits, word + IPA-ish phone events on a real spoken waveform. FR-002 / FR-004 / SC-003–004.

**Alternatives considered**:
- Phonemize-only + duration-model tones — already shipped; spec forbids it as production success.
- `flutter_tts` / OS TTS — no portable phone events, not deterministic, may need network.
- Shell out to `espeak-ng` CLI — not present on mobile / all desktop runners.
- Request 16 kHz from eSpeak if a given build allows it — still require an in-package resample fallback; do not call FFmpeg from this package.

### 3. Vendor native lib + trimmed voice data; load lazily

**Decision**: Ship prebuilt `libespeak-ng` (or equivalent) for Android, iOS, macOS, Windows, and Linux under `packages/forced_alignment/native/<os>/`, plus a **trimmed** `espeak-ng-data` tree covering the eight focus voices only. Resolve the data directory and pass it as `espeak_Initialize`’s `path`. Load with `DynamicLibrary.open` only when the production synthesizer is constructed.

Do **not** compile eSpeak-NG from source on every `flutter test` via native-assets hooks. That was the slice 2 reason to avoid a compile-every-test native asset.

If the library or data directory cannot be opened, `espeakFfiIsAvailable()` is false and production `align()` / `alignSegments()` return `spokenReferenceUnavailable` — they must **not** fall back to `DurationModelSynthesizer`.

Record binaries, data subset, and GPL-3.0 → AGPL linkage in **ADR-0072** and a short `docs/packaging.md` note.

**Rationale**: Five OS targets need a known binary + data path. Lazy open keeps DTW/flatten CI green without a host `libespeak-ng`. Constitution V: packaging/license must be written down.

**Alternatives considered**:
- Native-assets compile-from-source on every test — slow, fragile on Windows CI; rejected for v1.
- System-installed `libespeak-ng` only — missing on iOS/Android and most CI images.
- Full upstream `espeak-ng-data` — larger than needed for eight focus tags.

### 4. `SpokenReferenceSynthesizer` seam; production default is fail-closed

**Decision**: Introduce a package-internal (export if tests need it) interface:

```text
SpokenReferenceSynthesizer.synthesize(text, language) → ReferenceAudio
```

`ReferenceAudio` is PCM at 16 kHz plus word/phone events on the **reference** timeline. It has **no** `durationSeconds` input that stretches the voice to the source clip.

- Production default: `EspeakNgSynthesizer`. Missing lib/data/voice → `spokenReferenceUnavailable`.
- Tests MAY inject a double (including a speech-like or tone fixture) via an optional `@visibleForTesting` parameter on `align` / `alignSegments`.
- `DurationModelSynthesizer` MUST leave the production factory. It may remain as a test helper under `test/` (or `@visibleForTesting`) and MUST NOT be wired when the caller omits the test double.

Unmapped language still fails as `unsupportedLanguage` **before** synth. Mapped language + failed/missing voice fails as `spokenReferenceUnavailable`, never as another language’s voice.

**Rationale**: Spec allows test doubles and forbids a non-speech stand-in as **production** success (FR-005, FR-006, SC-005).

**Alternatives considered**:
- Keep duration-model as silent fallback — would write bad times in slice 3; rejected.
- Encode missing voice as `internal` — spec requires a distinct reason (US3).

### 5. New failure reason; keep slice 2 caps

**Decision**: Add `AlignmentFailureReason.spokenReferenceUnavailable`. Keep `audioUnavailable`, `tooShort`, `blankText`, `unsupportedLanguage`, `wholeClipTooLong`, `cancelled`, `timedOut`, `internal`.

`internal` is only for errors **after** a spoken reference was built (DTW/MFCC/remap), or for unexpected FFI faults that are not “voice missing.” Prefer `spokenReferenceUnavailable` when initialize / set-voice / synth / empty-PCM fails.

Caps unchanged: 1.0 s min, 90 s whole-clip, 50 ms cue pad, cancel, timeouts (2 min whole-clip / 30 s per cue). Spoken reference is built **per job** (whole clip or one cue’s text), not as one utterance over a multi-minute file.

**Rationale**: FR-006 / FR-007 / US3–US4.

### 6. DTW pipeline: compare unequal-length spoken PCM; remap onto source

**Decision**: Keep `runAlignPipeline`’s MFCC + windowed DTW + `mapTime`. Change only the reference source:

1. Build spoken `ReferenceAudio` (duration may be shorter or longer than the source).
2. MFCC both sides at the existing granularity preset.
3. Windowed DTW maps reference frames → source frames.
4. Remap each reference word/phone `audio_position` onto the **source** timeline (plus cue `timeOffset` for `alignSegments`).

Do not stretch or pad the reference to the source duration. Do not rewrite the caller’s transcript string. Punctuation-only text still succeeds with zero words and does not require synth.

**Rationale**: Spec edge case “reference length ≠ clip length.” Stretching was the stand-in that made DTW look like identity in slice 2 tests.

**Alternatives considered**:
- Time-scale the reference to the clip first — reintroduces even stretch; rejected.
- Return times on the reference timeline — would break slice 1 / enjoy-web mapping.

### 7. Product stays inert; ADR-0072 supplements ADR-0071

**Decision**: No Craft, panel, player, ASR, lookup, Settings, or ARB imports. Pin the existing inert-import tests. Do not play reference PCM through `media_kit` or any other player.

Add **ADR-0072** (spoken-reference requirement, FFI wrap, vendored native + data, GPL note, fail-closed). Update ADR-0071’s “duration-model v1” consequence only by superseding that clause — do not rewrite the merged ADR. Refresh the unused-engine note in `docs/features/transcript.md`. Update ADR-0029 follow-up text for `forced_alignment` (eSpeak wrap landing).

**Rationale**: FR-001 / FR-008 / FR-010. Constitution V.

### 8. Tests: fail-closed always; quality goldens skippable

**Decision**:

| Always on CI | Skippable |
|--------------|-----------|
| Unavailable harness → `spokenReferenceUnavailable` (never duration-model success) | Real eSpeak “hello world” ±50 ms vs **that run’s** word events |
| Unmapped language → `unsupportedLanguage` | Multi-language voice smoke |
| Caps, cancel, timeout, flatten, inert imports | Heap / wall-clock of a 60 s clip on device |

Goldens that need a real voice `skip` with a reason when FFI/data cannot load. They MUST NOT skip by synthesizing tones and calling that eSpeak. Injected doubles for DTW math are allowed; they do not count as SC-003/004.

**Rationale**: Constitution II + spec assumption on CI voice availability.

## Resolved unknowns

| Topic | Resolution |
|-------|------------|
| Which speech engine | eSpeak-NG `espeak_Synth` + WORD/PHONEME callback |
| pub.dev `espeak` | Not used for production synth |
| Second path package | No |
| Missing voice | `spokenReferenceUnavailable`, not `internal`, not stand-in success |
| Sample rate | Synth native rate → in-package resample to 16 kHz; no FFmpeg in package |
| Native packaging | Vendored per-OS lib + trimmed `espeak-ng-data`; lazy `DynamicLibrary.open` |
| Isolate | Synth + DTW on the existing alignment isolate; init once per isolate |
| Product wiring | Still none |
| ADR | 0072 (supplement 0071); packaging.md note |

## Open risks (implementation / QA, not blockers)

1. **Prebuilt size / codesign**: iOS/macOS dylibs and Android `.so` need the same signing/packaging care as other native bits; document in packaging.md.
2. **Voice id drift**: `es-419` / `fr-ca` must exist in the trimmed data set or those tags fail closed (correct) until data is added.
3. **Phoneme IPA strings**: eSpeak IPA labels may not match `@enjoy/alignment` spellings; slice 2b requires pronunciation units + parent word, not letter-split. Slice 3 / #527 may normalize labels later.
4. **CI without binaries**: goldens skip; fail-closed tests must still prove production `align()` does not use the duration model.
5. **eSpeak thread rules**: never call synth from the UI isolate; cancel via callback return `1`.
