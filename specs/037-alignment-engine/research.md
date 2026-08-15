# Research: Alignment Engine

**Feature**: `037-alignment-engine` | **Date**: 2026-08-15

## Decisions

### 1. Path package `packages/forced_alignment` (PCM in, timings out)

**Decision**: Ship the engine as a first-party path package `packages/forced_alignment`, same pattern as `packages/azure_speech`. Public API is `align` / `alignSegments`. Input is **16 kHz mono Float32 PCM** plus transcript text and BCP-47 language. The package does **not** call FFmpeg, Drift, Craft, or widgets.

Adding the path dep requires updating `ALLOWLIST` in `.github/scripts/check_no_new_path_deps.sh` and the table in [ADR-0029](../../docs/decisions/0029-supply-chain-risk.md) in the same PR.

**Rationale**: Native synthesis + heavy DSP must stay UI-free and testable without `AppDatabase`. Constitution I’s `lib/features/` layout is for product flows; this slice has no product flow. Issue #540 already named this package. Slice 3 can decode files with existing extractors and pass PCM in.

**Alternatives considered**:
- `lib/features/alignment/` only — pulls FFI and DTW into the app graph; harder to keep Craft/transcript from importing it; rejected.
- Second path package `packages/enjoy_espeak` — extra allowlist row; extend/wrap pub.dev `espeak` from `forced_alignment` instead.

### 2. Echogarden *result interface*, not bit-identical timestamps

**Decision**: `AlignmentResult` / `TimelineEntry` match Echogarden’s public shape: recursive `type` + `text` + `startTime`/`endTime` (seconds, **source** audio) + nested `timeline`; plus `wordTimeline`, `transcript`, `language`. Algorithm family is eSpeak reference → MFCC → windowed DTW. Fixture bar is **±50 ms** on word starts vs the engine’s own reference (and optional later Echogarden CLI cross-check). Not bit-exact floats.

**Rationale**: Issue #540 and slice 1 research: stored cues stay enjoy-web `TranscriptWord`/`PhoneTiming`; the engine may be a richer tree. Interface parity lets slice 3 map without inventing a third timeline dialect.

**Alternatives considered**:
- Return only enjoy-web `WordTiming[]` like `@enjoy/alignment` — simpler, but loses segment/token structure `alignSegments` needs; flatten is a **pure adapter**, not the engine result.
- Store Echogarden trees in `timeline_json` — rejected in slice 1 / ADR-0070.

### 3. File decode stays in existing extractors; package slices by sample index

**Decision**: `alignSegments` takes full-clip 16 kHz PCM plus cue windows (`text`, `startTime`, `endTime` in seconds). It slices samples (`startSample = startTime * 16000`) and offsets child times back onto the source timeline. App-side file→PCM (slice 3) reuses `AsrAudioExtractor` / FFmpeg `pcm_s16le -ar 16000 -ac 1` and echo-style cancel tokens. This slice’s tests use **in-memory PCM fixtures**, not library files.

**Rationale**: Keeps the package free of `path_provider` / FFmpeg / YouTube. Per-cue alignment does not need a second FFmpeg implementation.

**Alternatives considered**:
- Package shells out to FFmpeg — duplicates ASR/echo extractors and fails on runners without the binary; rejected.
- Require callers to pre-slice PCM per cue — extra copies; index math in the package is cheaper.

### 4. Isolate for DTW; cancel + timeout are first-class

**Decision**: `align` / `alignSegments` run the DSP body in `Isolate.run` (same pattern as `echo_region_pitch_analyzer.dart`). Default whole-clip timeout **2 minutes**; per-cue timeout **30 s**. `CancelToken` / `AbortSignal`-equivalent stops work. Failures are a typed `AlignmentFailure` (not thrown past the public API as untyped errors).

**Rationale**: FR-008 / SC-008. A 60 s medium DTW must not block playback. Constitution IV: heavy audio off the main isolate.

**Alternatives considered**:
- Compute on the UI isolate “because tests are short” — fails SC-008 on real Craft audio; rejected.
- Fire-and-forget compute isolate without cancel — leaks work when the caller goes away; rejected.

### 5. Reference synthesis: wrap/extend pub.dev `espeak`; MFCC via `mcfcc_nsn`

**Decision**: Reference audio + phone events come from eSpeak-NG (extend `espeak` FFI: synthesize PCM + event stream). MFCC uses `mcfcc_nsn` with Echogarden hop/window/coef presets (`low` / `medium` / `high`). If `espeak` upstream is phonemize-only, keep a thin FFI wrapper inside `forced_alignment` (or a documented fork) rather than a second path package in v1.

**Rationale**: Offline, no credits, ~100 voices, same family as Echogarden and `@enjoy/alignment`. `mcfcc_nsn` is AGPL-3.0 (matches the app). GPL eSpeak-NG linked into AGPL is acceptable; record that in ADR-0071.

**Alternatives considered**:
- Cloud ASR word timings — costs credits, no phones, not offline; rejected.
- Azure `wordBoundaries` as the engine result — no phones, cloud; remains Craft’s *current* line builder (slice 3 may deprecate it as a stored timeline source).
- Port `@enjoy/alignment` WASM eSpeak — web-shaped; Flutter needs native FFI on five OS’s.

### 6. Flatten adapter in the package; do not write Drift

**Decision**: Export a pure `flattenToWordPhoneTimings(AlignmentResult)` → enjoy-web `WordTiming[]` + `PhoneTiming[]` (`startTime`/`endTime` seconds, `phone`/`text`/`wordIndex`). Do **not** import `TranscriptLine` into the package (avoids app↔package cycles). Slice 3 maps those timings onto `TranscriptLine.timeline` / `TranscriptWord.phones` (word ms relative to the parent line).

**Rationale**: FR-007 is testable in slice 2 without touching DAOs. Stored-cue mapping needs line start/duration from Craft/ASR, which this slice does not own.

**Alternatives considered**:
- Adapter in `lib/data/subtitle` this slice — would tempt Craft to call it; defer to slice 3.
- Package depends on `enjoy_player` for `TranscriptLine` — illegal cycle; rejected.

### 7. Caps, quality, languages

**Decision**:
- Sample rate **16000** Hz mono.
- Minimum audio **1.0 s** (`tooShort`).
- Whole-clip max **90 s**; longer whole-clip at any quality → `wholeClipTooLong` (caller must use `alignSegments`).
- Cue pad **50 ms** for SC-005.
- Granularity: `low` = words only; `medium` (default) = words + phones; `high` = words + phones, finer hop.
- v1 language bar = `kSupportedFocusLanguageTags`. Unknown / unmapped eSpeak voice → `unsupportedLanguage` (never silently swap language).
- Punctuation-only success with zero words is allowed; a **failure** must not be encoded as empty success.

**Rationale**: Spec assumptions + SC-006. 90 s covers typical Craft items; multi-minute local media must be per-cue.

### 8. Product stays inert; docs are ADR + a transcript note

**Decision**: No imports from Craft, transcript panel, player, ASR, YouTube, or Settings into `forced_alignment` consumers in `lib/`. Pin with a test that those libraries do not import the package. Add **ADR-0071** (engine contract, Echogarden interface, path package, license, YouTube/user-recording exclusion). Add a short “Alignment engine (unused)” note to `docs/features/transcript.md`. No ARB, no Settings key.

**Rationale**: FR-001 / FR-011 / SC-001–002. Same documentation pattern as ADR-0070.

**Alternatives considered**:
- Settings toggle now — nothing to opt into; slice 3 owns `transcript.timelineEnrichment`.
- Wire Craft behind a hidden flag — still a product-flow change; out of spec.

### 9. Tests: math always; native goldens skippable

**Decision**: DTW path tests (synthetic MFCC, known warp) always run in CI. Flatten + failure-enum tests always run. eSpeak “hello world” ±50 ms golden runs when FFI loads; otherwise `skip` with a reason (do not fail Linux CI if the native lib is absent on a runner). No widget tests required (no UI).

**Rationale**: Constitution II. Native availability differs by runner; math contract must still be green.

## Resolved unknowns

| Topic | Resolution |
|-------|------------|
| Package vs `lib/features` | Path package `forced_alignment` + ADR-0029 allowlist |
| Result shape | Echogarden recursive; flatten adapter to web `WordTiming`/`PhoneTiming` |
| PCM / FFmpeg | Package is PCM-only; slice 3 uses existing extractors |
| Isolate | `Isolate.run` + cancel/timeout |
| Synthesis / MFCC | eSpeak-NG FFI + `mcfcc_nsn` |
| Persistence | None this slice |
| Whole-clip cap | 90 s |
| Languages | Focus catalog; else `unsupportedLanguage` |

## Open risks (implementation / QA, not blockers)

1. **eSpeak FFI gap**: pub.dev `espeak` may still be phonemize-only. Budget a small FFI wrap in this package; do not block the DTW core on upstream review.
2. **MFCC preset drift**: `mcfcc_nsn` defaults may not match Echogarden hops; wrap with explicit window/hop/coef from issue #540 §9.
3. **CI without native eSpeak**: skip goldens; keep DTW tests mandatory.
4. **Path-dep CI**: forgetting the allowlist fails `check_no_new_path_deps.sh` immediately.
