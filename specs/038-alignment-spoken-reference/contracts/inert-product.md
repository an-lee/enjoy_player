# Contract: Inert product

**Feature**: `038-alignment-spoken-reference`  
**Base**: [037 inert-product](../../037-alignment-engine/contracts/inert-product.md)

This slice still must not change learner-facing behavior.

## Must remain true

1. No `import` of `package:forced_alignment/...` from:
   - `lib/features/craft/`
   - `lib/features/transcript/`
   - `lib/features/player/`
   - `lib/features/asr/`
   - `lib/features/lookup/`
   - Settings registry / ARB
2. Craft save still emits line-only cues (existing tests).
3. No new Settings key `transcript.timelineEnrichment`.
4. No new transcript panel chrome (karaoke, IPA, word chips).
5. No new `media_kit` `Player`.
6. No YouTube demux path.
7. Craft / library playback still plays the existing high-quality audio — never the spoken-reference rendering.

## Test shape

Keep `test/features/alignment` inert-import coverage. Existing Craft/transcript widget tests stay green without new golden diffs.

## Non-goals

- Hidden debug buttons to run alignment
- Pref-gated Craft wiring
- A Settings row for “reference voice”
