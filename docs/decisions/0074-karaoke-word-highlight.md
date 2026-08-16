# ADR-0074: Karaoke word highlight (first transcript-panel consumer)

## Status

Accepted

## Context

ADR-0070 stores optional nested word/phone spans on cues. ADR-0073 lets
opt-in Craft save persist those spans. Learners still only saw line-level
highlight in the transcript panel. Issue #540 slice 4 needs a **first
panel consumer** of stored word times without adding IPA overlay, per-word
tap, or play-time alignment.

Karaoke must stay independent of Craft enrichment: items that already have
word timings should highlight even when enrichment is off. Default must
remain off so the post-slice-3 line-level panel does not change until the
learner opts in.

This ADR does **not** rewrite ADR-0070–0073.

## Decision

1. **Panel consumer only** — karaoke reads stored `TranscriptWord` windows
   on the current cue. Caption import, YouTube, ASR, and Craft save stay on
   their existing writer contracts. No `alignSegments` / `package:forced_alignment/`
   from transcript, settings, player, or l10n.
2. **Independent default-off setting** — `transcript.karaokeHighlight` in
   device-global `SettingsDao` (`'true'`/`'false'`, missing ≡ off). Settings
   → Transcript shows a second switch next to Craft enrichment. Turning
   karaoke on does not rewrite the library or run alignment. The transcript
   panel and word-index provider watch the keep-alive settings notifier
   (not a sticky-false gate) so a still-loading read is not treated as off.
3. **In-place highlight on primary text** — tint the current word inside
   the existing line string (markup-aware). No chips, no IPA overlay, no
   change to line identity, tap-to-seek, echo, lookup, or auto-translate.
   Secondary/translation text is never word-highlighted. Karaoke MUST NOT
   auto-reveal a blurred cue.
4. **50 ms karaoke position bucket** — word index uses
   `quantizedPositionStream` at `kPositionBucketKaraokeMs = 50`. Do **not**
   change `kPositionBucketDisplayMs` (400 ms; Windows accessibility flood).
   Only the **active** cue tile watches the word-index provider. Fail closed
   on line-only, untimed, gapped, or out-of-window words.
5. **No new `media_kit` `Player()`** — assessment take-replay karaoke in
   shadow-reading stays a separate surface.

## Consequences

- Enriched Craft items can show current-word highlight when the learner
  opts in, without a second alignment pass.
- Default panel behavior matches the pre-feature (slice 3) build.
- IPA overlay, per-word tap/loop/inspect, play-time alignment, and library
  backfill remain later slices.
