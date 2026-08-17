# Quickstart: On-Demand Transcript Enrichment

**Feature**: `042-on-demand-transcript-enrichment`  
**Contracts**: [contracts/README.md](./contracts/README.md) · **Model**: [data-model.md](./data-model.md)

## Prerequisites

- Flutter toolchain per repo README
- Nested cue model (ADR-0070), `packages/forced_alignment` + eSpeak (ADR-0071/0072), Craft save attach (ADR-0073/0076), karaoke + IPA overlay (ADR-0074/0076)
- After Riverpod / ARB edits: `dart run build_runner build` and `flutter gen-l10n`; commit generated files
- Implement on git branch `042-on-demand-transcript-enrichment`

## Automated checks

```bash
flutter test test/data/subtitle test/features/transcript test/features/craft test/packages/forced_alignment packages/forced_alignment/test
flutter analyze
bash .github/scripts/validate_ci_gates.sh --fix
```

Expected:

- Word/phone JSON: omit null clocks; missing clocks parse as untimed; timed Craft fixtures still round-trip numbers
- Readiness: line-only → both switches off + enrich shown; timed+phones+owned → karaoke+IPA on, no enrich; untimed+phones+YouTube → IPA on, karaoke off, no enrich
- Karaoke paint null on YouTube even if preference is true
- IPA overlay shows labels on untimed words; `wordMediaWindowMs` null → no seek
- YouTube phonemize mapper: words + labels, no usable windows; PCM/FFmpeg not called
- Owned attach still uses `attachAlignmentToLines` (line identity unchanged)
- `replaceTimeline` keeps row id/source/label
- Craft save tests unchanged (always-on enrich still fail-closed)
- Presentation/settings/l10n do not import `forced_alignment`

## Manual validation (E2E)

### A. Gating without enrich (P1)

1. Open a line-only local import and a line-only YouTube item. Open CC → display card.
2. **Expect**: Karaoke and IPA disabled; enrich tile visible. Panel stays line-level.
3. Open an already-enriched Craft item.
4. **Expect**: Karaoke and IPA enabled (if phones exist); enrich hidden.

### B. Owned enrich (P1)

1. Short local file with line-only captions, supported learning language. Tap enrich. Do not restart.
2. **Expect**: Lines unchanged; nested timed words + IPA; karaoke and IPA switches enable.
3. Karaoke on, play at 1×; IPA on; tap IPA on a timed word.
4. **Expect**: Highlight follows stored windows; tap plays that word.
5. Cancel or force failure (unsupported language).
6. **Expect**: Captions still playable; retry available; no stuck blocker.

### C. YouTube IPA-only (P1)

1. YouTube captions, line-only. Confirm karaoke disabled. Tap enrich (pronunciation copy).
2. **Expect**: Nested words without usable times; IPA switch enables; karaoke stays disabled; video is not saved locally for alignment.
3. IPA on. Tap IPA. Tap a non-active line.
4. **Expect**: Spelling visible; IPA tap does not seek a word; line tap still seeks the line.
5. Leave karaoke preference on from a Craft session, reopen YouTube.
6. **Expect**: 0 in-line word highlights.

### D. Coexistence (P1)

1. Echo, lookup, blur, translation on a YouTube IPA-enriched item and an owned timed item.
2. **Expect**: Line identity unchanged; IPA does not auto-reveal blur; translation line has no karaoke/IPA/enrich.
