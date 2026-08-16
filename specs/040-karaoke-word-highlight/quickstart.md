# Quickstart: Karaoke Word Highlight

**Feature**: `040-karaoke-word-highlight`  
**Contracts**: [contracts/README.md](./contracts/README.md) · **Model**: [data-model.md](./data-model.md)

## Prerequisites

- Flutter toolchain per repo README
- Slice 3 on the tree (ADR-0073): at least one Craft item saved with **Enrich Craft word timings** on, so nested `timeline` exists. Karaoke still works on any cue that already has timed words.
- After Riverpod / ARB edits: `dart run build_runner build` and `flutter gen-l10n`; commit generated files

## Automated checks

```bash
flutter test test/data/subtitle test/features/transcript test/features/settings test/features/alignment
flutter analyze
bash .github/scripts/validate_ci_gates.sh --fix
```

Expected:

- Matcher: three timed words → index follows position; overlap → last match; line-only / out-of-window → null
- Text range: sequential substring on plain line text; missing token → null range
- Setting defaults off; persist true/false; registry includes Transcript / `karaokeHighlight`
- Tile with nested words + karaoke **off**: same text/timestamp as line-only; no phone IPA in semantics (existing inert pin)
- Tile + karaoke **on** + position in a word: in-place highlight; no phone labels; no extra chip widgets
- Blur + karaoke on: active cue stays blurred until hover/hold
- Import / YouTube / ASR / Craft-save tests unchanged (no new nested writers)
- `forced_alignment` still not imported from transcript/settings/player/l10n

## Manual validation (E2E)

### A. Default off (P1)

1. Leave **Highlight current word** (karaoke) off.
2. Open an enriched Craft item (nested words in SQLite) and a line-only import.
3. Play both.
4. **Expect**: Line-level current cue only; no in-line word highlight; no IPA.

### B. Opt-in karaoke (P1)

1. Settings → Transcript → turn karaoke **on**. Do not restart.
2. Play the enriched Craft item at 1×.
3. **Expect**: The spoken word is highlighted in place; the rest of the line stays readable; line rail/auto-follow still follow the **line**.
4. Pause mid-word.
5. **Expect**: That word stays highlighted.
6. Tap a non-active line.
7. **Expect**: Seek to that line’s start (not a word).

### C. Mixed / incomplete (P1)

1. Karaoke on. Play a track that mixes line-only cues and nested cues.
2. **Expect**: Word highlight only on timed words; line-only cues look as today.

### D. Practice modes (P1)

1. Karaoke on + echo: highlight may show on the active echo cue’s primary text; echo expand/shrink unchanged.
2. Karaoke on + blur: active line stays blurred until hover/hold; no auto-reveal.
3. Karaoke on + translation line: highlight on primary only.
4. Karaoke on + enrichment **off**: already-enriched item still highlights; a **new** Craft save stays line-only per slice 3.

### E. Assessment karaoke (out of scope)

1. Run shadow-reading assessment take replay.
2. **Expect**: Azure word-chip karaoke unchanged; it does not require the new Settings toggle.
