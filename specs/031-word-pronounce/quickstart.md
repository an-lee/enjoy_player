# Quickstart: Word Pronounce Playback

**Feature**: `031-word-pronounce`  
**Date**: 2026-07-30

Validation guide after implementation. Contracts: [contracts/](./contracts/), model: [data-model.md](./data-model.md).

## Prerequisites

- Signed-in Enjoy account with credits (for cache-miss generation)
- Worker pronounce deployed / local Worker with `PRONOUNCE_TTS` + Azure Speech
- Player `aiApiBaseUrl` pointing at that Worker
- Learning/lookup language from the supported catalog (e.g. `en-US`, `ja-JP`, `es-MX`, `fr-CA`)

## Automated gates

```bash
# From enjoy_player root
dart run build_runner build   # if new @Riverpod types
flutter analyze
flutter test test/features/pronounce test/data/api/services/ai
# or broader:
flutter test
bash .github/scripts/validate_ci_gates.sh --fix
```

Expected: unit tests for locale resolve across learning/lookup tags, API parse, playback state machine; widget tests for button states; no `media_kit` Player in pronounce code.

## Manual scenarios

### 1. Lookup — first play (P1)

1. Open media with a learning-language transcript (try `en-US` and one non-English, e.g. `ja-JP`); select a word; open lookup.
2. Confirm speaker icon in header next to bookmark/copy/close.
3. Tap → loading → audio plays in that language; tap again → stops.
4. Tap again → should be fast if Worker/session cache hit.

### 2. Flashcard (P2)

1. Open vocabulary review; show a card with English headword.
2. Tap speaker beside headword (front); confirm play, not media segment.
3. Flip; tap speaker on back header; confirm same word, Context chips unchanged.
4. Flip/rate while playing → audio stops.

### 3. Assessment result (P3)

1. Complete or reopen pronunciation assessment.
2. Select a word chip; confirm speaker in selected-word detail only.
3. Play model audio; change chip → previous audio stops.

### 4. Negative paths

- Truly unsupported locale tag (not in Worker allowlist) → control disabled + tooltip.
- Sign out → tap shows auth guidance / notice; no stuck spinner.
- Empty selection → control disabled.

## Docs to update when shipping

- `docs/features/dictionary-lookup.md`
- `docs/features/vocabulary.md`
- `docs/features/shadow-reading.md`
- ADR for lookup TTS follow-up (extend ADR-0019 or short new ADR)
