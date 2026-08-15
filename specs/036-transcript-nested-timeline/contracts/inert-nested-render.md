# Contract: Inert nested render

**Feature**: `036-transcript-nested-timeline`  
**UI**: `TranscriptLineTile` and transcript panel consumers

This slice adds no learner-facing chrome. Nested spans are storage-only.

## Must remain true

1. Primary body text is `line.text` (via existing markup / blur widgets). The tile MUST NOT concatenate `timeline[].text` for display.
2. Timestamp meta uses `line.startMs` only.
3. No karaoke highlight, IPA ruby, per-word chips, or new Settings toggle.
4. A fixture cue with `timeline` / `phones` populated renders the same visible line text and timestamp as the same cue with `timeline` stripped.
5. Semantics label still combines timestamp + line snippet (existing accessibility contract). Nested IPA MUST NOT appear in semantics this slice.

## Test shape

Widget (or golden-free) test: two `TranscriptLineTile`s — one line-only, one with nested words/phones, identical `text` / `startMs` / `durationMs` / tile flags — expose the same primary plain text and timestamp string.

## Non-goals

- Word-level tap targets
- Settings → Transcript enrichment toggle
- Changing `parseSubtitleMarkup` / selection toolbar
