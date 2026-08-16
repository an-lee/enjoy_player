# Data Model: Spoken Alignment Reference

**Feature**: `038-alignment-spoken-reference` | **Date**: 2026-08-16

No Drift tables. Slice 1 nested cues remain the **storage** model. Slice 2’s `AlignmentRequest` / `AlignmentResult` / flatten view keep the same meaning. This slice adds the **spoken reference** the engine must build before DTW, and one new failure reason.

## Entities

### SpokenReferenceSynthesizer (new)

Package seam. Production implementation is eSpeak-NG. Tests may inject a double.

| Method | In | Out |
|--------|----|-----|
| `synthesize` | `text`, `language` (BCP-47 already mapped) | `ReferenceAudio` **or** a failure the pipeline maps to `spokenReferenceUnavailable` |

**Must not** take source-clip `durationSeconds` as a stretch target. Reference duration is whatever the voice produced.

### ReferenceAudio (existing shape, new invariants)

| Field | Required | Notes |
|-------|----------|-------|
| `pcm` | yes | Mono Float32 at **16 kHz** (resampled in-package if the engine’s native rate differs). |
| `words` | yes | In transcript order. Empty only when there are no alignable words. |
| `durationSeconds` | yes | `pcm.length / 16000`. MAY differ from the source clip. |

Times on `words` / phones are on the **reference** timeline. The pipeline remaps them onto the source timeline.

### ReferenceWord / ReferencePhone

| Entity | Fields | Invariants |
|--------|--------|------------|
| `ReferenceWord` | `text`, `startTime`, `endTime`, `phones` | `endTime >= startTime`; `text` is a recognized word, not rewritten transcript prose |
| `ReferencePhone` | `phone`, `startTime`, `endTime`, `wordIndex` | `wordIndex` in range; `phone` is a pronunciation unit from the spoken reference — **not** one letter per character of the spelling |

At `low` granularity the pipeline MAY drop phones after synth. Production `medium` / `high` MUST keep reference phones when the voice emitted them.

### AlignmentRequest / AlignmentSegment / TimelineEntry / AlignmentResult

Same as [037 data-model](../037-alignment-engine/data-model.md). Additions:

| Field / rule | This slice |
|--------------|------------|
| Optional test-only `synthesizer` | Injected double; omitted → production eSpeak-NG |
| Success times | Still **source** seconds after DTW remap |
| `transcript` / `language` on success | Still echoed unchanged |
| Production success | Forbidden unless `ReferenceAudio` came from a spoken synthesizer (not duration-model / letter G2P) |

### AlignmentFailure

Slice 2 reasons unchanged, plus:

| Reason | When |
|--------|------|
| `spokenReferenceUnavailable` | Language is mapped, but the spoken voice cannot be produced (lib/data missing, `SetVoiceByName` fails, synth returns no PCM, initialize fails). Distinct from `unsupportedLanguage` and from `internal`. |
| `unsupportedLanguage` | Tag not in `kEspeakVoiceByLanguageTag`. Do not attempt another language’s voice. |
| `internal` | DTW/MFCC/remap (or unexpected FFI) **after** a spoken reference existed — not “voice missing.” |

Public API still returns success **or** `AlignmentFailure`. Failures never write transcript rows.

## State transitions

```text
align / alignSegments
  ├── validate PCM / text / caps / language
  │     ├── blank / tooShort / wholeClipTooLong / unsupportedLanguage / audioUnavailable
  │     └── punctuation-only → success (zero words; no synth required)
  ├── synthesize spoken reference (per job: whole clip or one cue)
  │     ├── cancel / timeout → cancelled / timedOut (including in-flight synth)
  │     └── cannot speak → spokenReferenceUnavailable
  ├── MFCC + windowed DTW (reference length may ≠ source length)
  └── remap reference events → source TimelineEntry tree
```

`DurationModelSynthesizer` is **not** a state on the production path.

## Validation

| Rule | Behavior |
|------|----------|
| Unmapped language | `unsupportedLanguage` before synth |
| Mapped language, voice/lib/data missing | `spokenReferenceUnavailable` |
| Production path uses tone/letter stand-in | Forbidden (test must fail) |
| Reference duration ≠ source duration | Allowed; times still source-relative |
| Phone without parent word | Invalid in production result; drop on flatten |
| Letter-split of “hello” as production phones | Forbidden |
| Blank / too-short / missing audio | Same as slice 2; no spoken reference required to classify |
| Cue window pad | Word times in `[startTime − 0.050, endTime + 0.050]` |

## Identity vs storage

| Mechanism | This slice |
|-----------|------------|
| Drift / `timeline_json` | Untouched |
| `cueIdFor` / `sourceKey` | Untouched |
| Engine result equality | Word count/order; starts within 50 ms of **this run’s** spoken-reference word events |

## Persistence

None. No DAO, no settings key, no cache of reference PCM.
