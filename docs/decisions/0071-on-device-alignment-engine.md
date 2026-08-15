# ADR-0071: On-device alignment engine (unused by product flows)

## Status

Accepted

## Context

Issue #540 needs word- and phone-level timings for later Craft enrichment, karaoke, and IPA. Slice 1 (ADR-0070) already stores optional nested spans on cues. Slice 2 must **produce** those timings from known text and extractable audio without changing what learners see.

Enjoy web uses Echogarden’s `align` / `alignSegments` result shape, then flattens to `@enjoy/alignment` `WordTiming` / `PhoneTiming`. Flutter must expose the same *interface* (recursive `type` + seconds on source audio) so slice 3 can map onto ADR-0070 cues without a third dialect.

Native synthesis + DTW does not belong in `lib/features/` (no UI, heavy DSP, FFI). Path packages are gated by ADR-0029.

## Decision

1. **Path package `packages/forced_alignment`** — 16 kHz mono Float32 PCM in; `align` / `alignSegments` out. No FFmpeg, Drift, Craft, widgets, or `TranscriptLine` imports. Allowlisted in ADR-0029.
2. **Echogarden result interface, not bit-exact timestamps** — recursive `TimelineEntry` plus `flattenToWordPhoneTimings`. Word-start bar is ±50 ms vs the engine’s own reference.
3. **Isolate + typed failures** — DSP runs off the UI isolate; cancel and timeout kill the worker. Failures are `AlignmentFailure`, never an empty successful word list, and never write `transcripts` rows.
4. **Reference audio** — v1 uses a deterministic duration-model waveform plus built-in G2P (English fixtures + letter fallback). pub.dev `espeak` is phonemize-only; a thin eSpeak-NG `espeak_Synth` FFI wrap stays in this package when a host library is present. Goldens skip if FFI is missing.
5. **Caps** — min 1.0 s audio; whole-clip max 90 s; per-cue pad 50 ms; languages = focus catalog; default granularity `medium` (words + phones).
6. **Unused by product in this slice** — Craft, transcript panel, player, ASR, lookup, and Settings must not import the package. No `transcript.timelineEnrichment` key. YouTube WebView and learner recordings stay out of scope.

## Consequences

- Slice 3 can decode files with existing extractors and call `align` / `alignSegments` behind an opt-in setting.
- Timing quality on real speech is limited until eSpeak waveform synthesis is wired; the DTW/flatten/failure contracts are testable without native FFI.
- GPL eSpeak-NG linked into this AGPL app is acceptable when the FFI wrap lands; record any extra native binaries in packaging notes.
