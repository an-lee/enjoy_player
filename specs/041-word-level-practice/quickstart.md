# Quickstart: Word-Level Practice

**Feature**: `041-word-level-practice`  
**Contracts**: [contracts/README.md](./contracts/README.md) · **Model**: [data-model.md](./data-model.md)

## Prerequisites

- Flutter toolchain per repo README
- Slice 3 on the tree (ADR-0073): at least one Craft item saved with **Enrich Craft word timings** on, so nested `timeline` / `phones` exist. Overlay and practice still work on any cue that already has that data.
- Slice 4 karaoke (ADR-0074) may be on or off independently.
- After Riverpod / ARB edits: `dart run build_runner build` and `flutter gen-l10n`; commit generated files
- Implement on git branch `041-word-level-practice` (do not land these files in the karaoke PR)

## Automated checks

```bash
flutter test test/data/subtitle test/features/transcript test/features/settings test/features/player test/features/alignment
flutter analyze
bash .github/scripts/validate_ci_gates.sh --fix
```

Expected:

- IPA concat: ordered non-empty `phone` labels; empty list → null
- Hit-test: offset inside a timed word → index; gap / untimed → null
- Word media window: `line.start + word.start`; out-of-line → not a target
- Word loop: wrap at end; cancel on stop / practice off
- Both settings default off; persist true/false; registry includes `ipaOverlay` and `wordPractice`
- Tile + both **off** + nested words/phones: same text/timestamp as line-only; no phone IPA (inert pin)
- Overlay **on**: IPA in annotation layer; absent from selection / lookup callback; no chips
- Practice **on** + non-selectable: tap word seeks to word start; timestamp seeks to line
- Practice **on** + selectable: no seek-to-word from text; loop/inspect icons when current word exists
- Blur + overlay: active cue stays blurred; IPA not visible until hover/hold
- Import / YouTube / ASR / Craft-save tests unchanged (no new nested writers)
- `forced_alignment` still not imported from transcript/settings/player/l10n

## Manual validation (E2E)

### A. Default off (P1)

1. Leave IPA overlay and word-level practice off (karaoke may be either).
2. Open an enriched Craft item and a line-only import.
3. Play, tap, lookup, echo, blur.
4. **Expect**: No IPA on the line; taps still line-level; lookup unchanged.

### B. Opt-in IPA overlay (P1)

1. Settings → Transcript → turn **IPA overlay** on. Practice stays off. Do not restart.
2. Open the enriched item.
3. **Expect**: Words with stored phones show pronunciation with the word; words without phones look ordinary; line-only cues unchanged.
4. Select text on the active line for lookup.
5. **Expect**: Lookup uses transcript text, not IPA.
6. Tap a non-active nested line.
7. **Expect**: Seek to **line** start (overlay is display-only).

### C. Opt-in word tap (P1)

1. Turn **word-level practice** on (overlay optional).
2. Pause so a nested cue is not active and not in echo.
3. Tap a middle timed word; tap the timestamp on another row.
4. **Expect**: Word tap seeks into that word’s window; timestamp seeks to the line.
5. Play the active line and select a substring.
6. **Expect**: Lookup still opens; that tap does not seek to a word.

### D. Loop and inspect (P1)

1. Practice on. Use loop on the current timed word (meta-row icon) or after choosing a word.
2. **Expect**: Playback repeats that one word until cancel; echo expand/shrink still moves **lines**.
3. Cancel (stop or turn practice off).
4. **Expect**: Ordinary play / echo resumes.
5. Inspect a word that has phones.
6. **Expect**: Ordered stored pieces. A word without phones has no inspect control.

### E. Practice modes (P1)

1. Overlay + karaoke: highlight on the spoken **word** text; IPA stays with its word.
2. Overlay + blur: active line stays blurred until hover/hold; no IPA leak.
3. Overlay + translation line: IPA on primary only.
4. Either toggle on + enrichment **off**: already-enriched item still shows/practices stored data; a **new** Craft save stays line-only per slice 3.

### F. Assessment karaoke (out of scope)

1. Run shadow-reading assessment take replay.
2. **Expect**: Azure word-chip karaoke unchanged; it does not require the new Settings toggles.
