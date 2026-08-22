# ADR-0075: Word-level practice and stored IPA overlay

## Status

Accepted

## Context

ADR-0070 stores optional nested word/phone spans. ADR-0073 lets opt-in Craft
save persist them. ADR-0074 is the first panel consumer: in-place karaoke
highlight from stored word times. Learners still could not see stored
pronunciation or practice a single timed word.

Issue #540 slice 5 (absorbing stored-phone display from #527) needs two
**independent, default-off** Settings controls: an IPA overlay that annotates
stored `phones[].phone` labels, and word-level practice (seek / loop /
inspect). Neither may generate IPA for line-only captions, run play-time
alignment, or instantiate a second `media_kit` `Player()`.

This ADR does **not** rewrite ADR-0070–0074.

## Decision

1. **Two Settings keys** — `transcript.ipaOverlay` and
   `transcript.wordPractice` in device-global `SettingsDao` (`'true'` /
   `'false'`, missing ≡ off). Settings → Transcript shows both switches after
   karaoke. Each is independent of karaoke and of Craft enrichment. The
   transcript panel hydrates both keep-alive notifiers during skeleton so a
   still-loading read is not treated as off.
2. **IPA overlay is an annotation layer** — when on, stored phone labels
   paint above eligible **primary** words via `IgnorePointer` +
   `ExcludeSemantics`. Orthography stays the selectable / karaoke text.
   Lookup uses `transcriptPlainForSelection` (no IPA). Line-only cues stay
   line-level. No G2P. Overlay MUST NOT auto-reveal a blurred cue or leak
   IPA through unrevealed blur (layer only when the cue is revealed, inside
   the existing blur wrapper).
3. **Word practice hit-test** — when on, tapping a timed word on a
   **non-selectable** row seeks to `line.startMs + word.startMs`. Timestamp /
   chrome / miss still line-seek. Selectable active/echo rows keep dictionary
   lookup. Echo already on retargets echo to that **line** but lands on the
   word start.
4. **Ephemeral word loop** — A-B wrap of one word window. Not written to
   `SessionDao`. `WordLoopEnforcer` ticks **before** `EchoEnforcer` and skips
   echo pause-and-rewind while looping. Cancel on stop, practice off,
   progress scrub, line seek, other word, or echo shrink dropping the line.
   Echo membership stays line-based.
5. **Inspect is on-demand** — meta-row icon on the selectable current word
   lists ordered stored phone labels in `showEnjoyAdaptiveSheet`. Omit the
   icon when `wordIpaPieces` is empty. No invented IPA, no alignment, no
   `/pronounce`.
6. **No `package:forced_alignment/`** from transcript, settings, player, or
   l10n. Do **not** change `kPositionBucketDisplayMs`. Karaoke still uses
   the 50 ms bucket; the current-word index is carried by
   `transcriptPlaybackHighlightProvider` (a record of `cueIndex` +
   `wordIndex`), which subscribes to the 50 ms stream only after the
   karaoke gate passes. The separate `activeCueWordIndexProvider` was an
   orphan with no call sites and was removed with that consolidation
   (#607). Inactive tiles must not watch that provider. Isolated widget
   tests override the notifiers to off.

## Consequences

- Enriched items can show stored IPA and word tap/loop/inspect when the
  learner opts in, without a second alignment pass or G2P.
- Default panel behavior matches the post-slice-4 (karaoke) build.
- Remaining #527 work (G2P / ipa-dict / Worker phonemizer for line-only
  captions) stays deferred. Play-time alignment, YouTube demux, library
  backfill, and phone-level karaoke stay out of scope.
