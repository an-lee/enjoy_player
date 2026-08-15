# Contract: Inert product

**Feature**: `037-alignment-engine`

This slice must not change learner-facing behavior.

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

## Test shape

A unit/grep-style test (or `test/features/alignment/forced_alignment_inert_import_test.dart`) fails if a forbidden library imports the package. Existing Craft/transcript widget tests stay green without new golden diffs.

## Non-goals

- Hidden debug buttons to run alignment
- Pref-gated Craft wiring
