# Research: Craft Timeline Enrichment

**Feature**: `039-craft-timeline-enrichment` | **Date**: 2026-08-16

Slices 1–2b already persist optional nested cues, expose `align` / `alignSegments`, and require a spoken reference for production success. This research locks how Craft becomes the first product caller without changing default save/playback.

## Decisions

### 1. Enrich on Craft save / re-save only

**Decision**: When `transcript.timelineEnrichment` is on, run alignment inside `CraftController.saveToLibrary` **after** `buildCraftPrimaryTimelineJson` succeeds and **before** `importCraftedFromText` / `updateCraftedFromText`. Deduped creates that skip synthesis skip enrichment (no silent rewrite). Already-saved library items are not backfilled. First-play alignment is out of scope.

**Rationale**: Spec US4 / FR-010. Save is the only moment we already have in-memory `previewAudioBytes`, known line windows, and a language. First-play would delay opening old items (rejected in the spec).

**Alternatives considered**:
- First-play for ≤60 s (issue #540 open question) — surprises playback; harder to test independently; rejected for this slice.
- Library-wide backfill job — rewrite risk; out of scope.

### 2. Spec 030 still builds lines; alignment only attaches nested spans

**Decision**: Keep `buildCraftPrimaryTimelineJson` as the line source (wording, breaks, solid-timings-or-blank). On success, decode those lines, call `alignSegments` with each line’s text + `[startSeconds, endSeconds]`, then attach `TranscriptWord` / `TranscriptPhone` onto the **same** lines. On any hard failure, persist the original line-only JSON unchanged.

Do **not** use `align()` whole-clip to invent a transcript when spec 030 returns `null`.

**Rationale**: FR-003 / FR-008 / SC-007. Line identity and shadow-friendly breaks stay ADR-0063 / spec 030.

**Alternatives considered**:
- Replace line builder with alignment segments — would change breaks and violate spec 030.
- Whole-clip `align` then re-segment — extra mapping dialect; rejected.

### 3. Fail closed to today’s Craft transcript (quiet)

**Decision**: `AlignmentFailed` for `spokenReferenceUnavailable`, `unsupportedLanguage`, `audioUnavailable`, `tooShort`, `cancelled`, `timedOut`, or `internal` → save the spec 030 JSON as-is. Partial cue success (some lines aligned) MAY attach nested spans only on successful lines; failed lines stay line-only. Log the reason with `logNamed`; no blocking Craft error chrome or required toast.

**Rationale**: FR-007 / SC-004. Slice 2b already made fake success impossible. Quiet fallback keeps Craft save no more fragile than today.

**Alternatives considered**:
- Block save on alignment failure — violates “save always works.”
- Diagnostic toast — not required; can wait for a later polish slice.

### 4. Mapping lives in `lib/data/subtitle`; Craft owns the call

**Decision**: Pure function (no `BuildContext`, no Drift):

```text
attachAlignmentToLines(
  lines: List<TranscriptLine>,
  result: AlignmentResult,
) → List<TranscriptLine>
```

Rules (ADR-0070 / 037 flatten contract):

1. Prefer `TimelineEntry.id` matching the line index (pass `AlignmentSegment.id = lineIndex`).
2. Else assign words whose start falls in `[line.startSeconds, line.endSeconds)` (last line inclusive at end).
3. Word `startMs` / `durationMs` = round((sourceSeconds − line.startSeconds) × 1000), duration ≥ 0.
4. Phones copy `phone` / `text` / `startTime` / `endTime` (seconds on the **media** timeline) and `wordIndex` **within that line’s word list**.
5. Never change line `text` / `startMs` / `durationMs` / `sourceKey`.
6. Empty word list → omit `timeline` (line-only).

`flattenToWordPhoneTimings` remains available for tests; production mapping should walk tagged segment entries so phones stay per-line.

**Rationale**: Constitution I — lift shared mapping out of features. Craft is the only caller this slice.

**Alternatives considered**:
- Import `TranscriptLine` into `packages/forced_alignment` — rejected in 037 (cycle / package purity).
- New `lib/features/alignment` product module — unnecessary third home; Settings + Craft already exist.

### 5. PCM from Craft preview bytes; do not import ASR from Craft

**Decision**: Add a UI-free helper under `lib/data/audio/` that turns Craft `previewAudioBytes` (WAV) into 16 kHz mono `Float32List`. Prefer a small WAV decode + existing package resample when the file is already PCM; otherwise write a temp file and FFmpeg `pcm_s16le -ar 16000 -ac 1` (same family as ASR / assessment), then convert int16 → float32 in `[-1, 1]`. Do **not** have `lib/features/craft` import `AsrAudioExtractor`.

**Rationale**: Feature↔feature ban. Craft audio is local and extractable. Extract + `alignSegments` must stay off the UI isolate (FFmpeg already isolates on Windows; alignment already uses a worker + serial synth host).

**Alternatives considered**:
- Call `AsrAudioExtractor` from Craft — feature shortcut; rejected.
- Decode only in the alignment package — package is PCM-in by design (037).

### 6. Settings key + new Transcript section

**Decision**:

- `SettingsKeys.transcriptTimelineEnrichment = 'transcript.timelineEnrichment'` (string `'true'` / `'false'`, missing = off). Add to `_staticKeys`.
- Keep-alive Riverpod notifier (same shape as `DiagnosticsVerbose`) reading `SettingsDao`.
- New Settings hub section `SettingsSectionIds.transcript` with one `SettingsRow` + `Switch.adaptive` (same pattern as diagnostic logging). Register the section/row in the 004 registry, both layouts, visuals, localizer, and search keywords.
- ARB strings via `flutter gen-l10n`. Toggle honored on the next save without restart.

**Rationale**: Spec US4 / FR-001. Issue #540 named the key. A dedicated Transcript section is discoverable without overloading About or Appearance.

**Alternatives considered**:
- Hide the toggle under Developer — not learner-facing.
- Profile/cloud setting — this is a device preference like diagnostics; local `SettingsDao` is enough for v1.

### 7. Retarget inert pins; panel stays inert

**Decision**: Update `forced_alignment_inert_import_test.dart`:

- **Allow** `lib/features/craft` (and the new `lib/data/audio` / `lib/data/subtitle` mapper) to import `package:forced_alignment/`.
- **Keep forbidding** transcript panel, player, ASR, lookup, Settings, and l10n from importing the package (Settings talks to the bool provider only).
- **Invert** the “no `transcript.timelineEnrichment` key” pin: the key MUST exist and default off.
- Add pins: import / YouTube / ASR builders still emit line-only cues; Craft save with setting off emits line-only; panel tests still ignore `timeline` for chrome.

**Rationale**: Slice 2b’s unused-engine pins would otherwise fail the first legitimate caller.

### 8. ADR-0073; docs; no karaoke

**Decision**: New ADR-0073 (first product caller, default-off setting, fail-closed save, mapping rules, no panel chrome). Do not rewrite ADR-0070–0072. Update `docs/features/craft.md` and `docs/features/transcript.md`. No new `media_kit` `Player`. No playback of the spoken reference.

**Rationale**: Constitution V. Slice 4 owns karaoke.

## Open items resolved (no spec change)

| Topic | Resolution |
|-------|------------|
| When to run | Craft save / re-save only |
| Blank 030 transcript | Skip alignment; stay blank |
| Deduped create | Skip enrichment |
| Partial line success | Nested on winners; line-only on losers |
| Failure UX | Quiet fallback + log |
| Settings IA | New Transcript section, one switch |
| PCM | `lib/data/audio` helper; no Craft→ASR import |
| Mapping | `lib/data/subtitle`; segment `id` = line index |

## Dependencies

- Slice 2b (`038`, ADR-0072) must be on the branch (spoken reference + `EspeakSynthHost`). Stack on `038-alignment-spoken-reference` if #556 is not merged.
- Slice 1 nested JSON (ADR-0070) and spec 030 line builder (ADR-0063).
- Settings hub registry (spec 004 / ADR-style section list).
