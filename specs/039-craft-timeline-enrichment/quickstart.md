# Quickstart: Craft Timeline Enrichment

**Feature**: `039-craft-timeline-enrichment`  
**Contracts**: [contracts/README.md](./contracts/README.md) · **Model**: [data-model.md](./data-model.md)

## Prerequisites

- Flutter toolchain per repo README
- Slice 2b (`038-alignment-spoken-reference` / ADR-0072) on the branch — production `alignSegments` requires a spoken reference
- After Riverpod / ARB edits: `dart run build_runner build` and `flutter gen-l10n`; commit generated files

## Automated checks

```bash
flutter test test/features/craft test/features/alignment test/features/settings test/data/subtitle
flutter test packages/forced_alignment/test
flutter analyze
bash .github/scripts/validate_ci_gates.sh --fix
```

Expected:

- Mapper: two-line attach keeps line text/start/duration; word ms relative to line; phone seconds + in-range `wordIndex`
- Setting defaults off; persist true/false; Settings registry includes Transcript / `timelineEnrichment`
- Craft save with setting **off** → line-only JSON (existing spec 030 tests stay green)
- Craft save with setting **on** + injected/forced alignment failure → same line-only JSON; save succeeds
- Craft save with setting **on** + successful `alignSegments` (test double or FFI) → nested spans on lines; audio bytes unchanged
- Blank 030 path still `primaryTimelineJson: null`
- Dedupe path does not rewrite the existing item
- Inert pins: transcript/player/ASR/lookup/Settings/l10n do not import `forced_alignment`; Craft may
- Import / YouTube / ASR still write line-only cues
- Existing Craft / transcript panel tests still pass (line-level chrome)

## Manual validation (E2E)

### A. Default off (P1)

1. Fresh profile (or leave the new switch off).
2. Craft a short paragraph with Enjoy TTS; save; open in the player.
3. **Expect**: Same line breaks/times as before this slice; no word highlight / IPA / per-word chips.
4. Open Settings → Transcript.
5. **Expect**: Enrichment switch is off.

### B. Opt-in save (P1)

1. Turn enrichment **on**. Do not restart.
2. Craft a two-sentence English item; save; reopen.
3. **Expect**: Same visible lines. (Optional debug: stored `timeline_json` has `timeline` + `phones` on cues.)
4. Play the item.
5. **Expect**: Hear Craft TTS audio, not a synthetic reference voice.

### C. Fallback (P1)

1. Leave enrichment on. Save a Craft item on a path with no extractable audio or an unsupported alignment language (or disable native eSpeak in a debug build).
2. **Expect**: Save succeeds; transcript matches today’s line-only or blank result; no blocking error.

### D. Library unchanged (P1)

1. Open a pre-existing import, YouTube, ASR, and old Craft item.
2. **Expect**: Cues unchanged until a Craft **re-save** with the setting on.
