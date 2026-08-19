# Research: On-Demand Transcript Enrichment

**Feature**: `042-on-demand-transcript-enrichment` | **Date**: 2026-08-17

`/speckit-clarify` was skipped. Defaults below resolve every planning unknown.

## 1. YouTube IPA without extractable audio

**Decision**: Add a text-only `phonemize` path on `packages/forced_alignment` that reuses `EspeakSynthHost` / `EspeakNgSynthesizer.synthesize`. Discard reference PCM. Persist ordered words + phone **labels** with **omitted** media times.

**Rationale**: Spec feasibility is already confirmed. IPA overlay (`wordIpaSpelling`) concatenates `TranscriptPhone.phone` and ignores clocks. Karaoke (`currentWordIndex`) and tap-IPA (`wordMediaWindowMs`) already skip `durationMs <= 0`. eSpeak WORD/PHONEME events already attach IPA labels to tokens. No YouTube demux, no second G2P catalog.

**Alternatives considered**:

| Option | Rejected because |
|--------|------------------|
| Cloud / Worker phonemizer (#527 remainder) | Extra credits, network, new stack; spec forbids it this slice |
| Evenly split line duration as fake word times | Would karaoke against the wrong speech (FR-008) |
| Call `alignSegments` with silence / synthetic audio as “source” | Invents clocks; karaoke would look enabled |
| pub.dev `espeak` phonemize-only | ADR-0072 already rejected it for production; we have FFI `espeak_Synth` |

## 2. Owned-media timed enrich

**Decision**: Player-side enrich of local/Craft files **and** owned cloud `mediaUrl` calls existing `alignSegments` + `attachAlignmentToLines`. Extract 16 kHz mono PCM in `lib/data/audio` from a **file path** (FFmpeg), not via `AsrAudioExtractor`. HTTP(S) cloud URLs are downloaded with Dart HTTP first so FFmpegKit (Android/iOS/macOS) and CLI ffmpeg (Windows/Linux) never speak TLS. Transcript MUST NOT import Craft’s `CraftTimelineEnricher`.

**Rationale**: Same nested mapping as Craft save (ADR-0073/0076). Feature↔feature: transcript must not import `lib/features/craft` or `lib/features/asr`. Slice 2 already forbids YouTube as “audio unavailable.”

**Alternatives considered**:

| Option | Rejected because |
|--------|------------------|
| Reuse `CraftTimelineEnricher` from the picker | Feature import; Craft API is bytes-in for save, not library paths |
| Import `AsrAudioExtractor` | Pulls ASR failure types / Azure WAV contract into transcript |
| Whole-file `align()` on multi-minute media | Slice 2 / spec: per-cue jobs, not one unbounded pass |

**Long local files**: If the last cue ends after ~90 s, extract **per-line windows** (`-ss` / `-t` + pad) and `align()` each cue; otherwise one `decodeFileToPcm16kMono` + `alignSegments` (Craft-length path). Cancel between cues. Partial attach is allowed (FR-011).

## 3. Optional word / phone times in JSON

**Decision**: Make `TranscriptWord.startMs` / `durationMs` and `TranscriptPhone.startTime` / `endTime` **nullable**. `toJson` **omits** null clocks. `fromJson`: missing → null (untimed); explicit `0` duration still untimed for karaoke. Timed Craft/alignment writes keep emitting numeric clocks.

**Rationale**: Spec: new YouTube writes SHOULD omit times rather than persist placeholder `0`s that look like alignment. Slice 1 already allowed omitted times; writers currently always emit `0`. Karaoke already treats non-positive duration as not a target.

**Alternatives considered**:

| Option | Rejected because |
|--------|------------------|
| Always write `start: 0, duration: 0` | Spec asks to omit; `0` can be misread as “starts at line origin” |
| Sentinel negative times | Breaks enjoy-web JSON interchange |

## 4. Switch gating vs persisted preference

**Decision**: Karaoke/IPA **preferences stay global** (`transcript.karaokeHighlight`, `transcript.ipaOverlay`). The CC-sheet switch is **interactive** only when this primary track + media type can support the feature. Switch **value** is `preference && capability` so a line-only or YouTube item looks off/disabled without wiping the stored preference. Paint/overlay also require capability (YouTube + karaoke preference on → 0 word highlights).

**Rationale**: FR-017. Today karaoke can be toggled on line-only tracks (no-op). IPA is already `onChanged: null` without phones, with no generate path.

**Capability**:

| Control | Enable when |
|---------|-------------|
| Karaoke | ≥1 nested word with a usable media window **and** media is owned (not YouTube) |
| IPA | ≥1 nested word with stored phone labels (times not required) |
| Enrich | Primary track has lines and enrichment is incomplete (owned: missing timed words or phones; YouTube: no nested words yet) |

Empty / no-track: switches disabled; enrich hidden (empty-state import/ASR stays).

## 5. Enrich UI placement and copy

**Decision**: One `TranscriptBusyListTile` in `TranscriptDisplaySettingsSection` (same CC sheet card as the switches), not Settings hub, not empty-state. Owned vs YouTube use **different ARB title/subtitle** (YouTube honest: pronunciation, not karaoke). In-flight: tile spinner (existing busy tile). Failure: retryable inline status on that tile; no blocking modal. Cancel: same tile while running.

**Rationale**: FR-001 / FR-004. Matches Extract / Generate density. Spec: quiet-enough failure, playback stays usable.

## 6. Persistence

**Decision**: `TranscriptRepository.replaceTimeline(id, lines)` upserts the **same** primary row (`timelineJson` + `updatedAt`), preserves source/label/language/id, invalidates the lines cache. No new track, no source change.

**Rationale**: FR-010. Same in-place pattern as ASR re-generate, without changing `source`.

## 7. Language mapping

**Decision**: Lift `alignmentLanguageForCraft` to `lib/data/subtitle/alignment_language.dart` (rename to `alignmentLanguageForTranscript`). Craft calls the shared helper. Unsupported language → typed enrich failure, no English swap.

**Rationale**: Transcript must not import Craft. Same fail-closed catalog as slice 3.

## 8. Architecture / isolate

**Decision**: `phonemize` jobs go through existing `EspeakSynthHost` (one eSpeak isolate). DTW stays on alignment isolates. Transcript **application** may import `package:forced_alignment/`; presentation, settings, l10n MUST NOT. No new `media_kit` `Player()`.

**Rationale**: eSpeak is process-global (ADR-0072). Constitution: feature-first, no print, no web.

## 9. ADR / docs

**Decision**: ADR-0078 records gated switches, explicit enrich, YouTube IPA-only untimed words, optional clocks. It **supplements** 0070 (optional times now product-visible) and **supersedes** 0076’s “IPA disabled until phones exist, no generate path” and “no G2P for line-only captions” **only** for this on-device eSpeak path. ADR-0073/0076 Craft save always-on is unchanged.

## Resolved clarifications

No remaining NEEDS CLARIFICATION. Locked defaults: explicit button, in-place primary write, omit untimed clocks, no fake YouTube karaoke, IPA tap inert when untimed, no first-play / library backfill.
