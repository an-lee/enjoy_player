# ADR-0076: Stacked IPA columns, player transcript controls, always-on Craft enrichment

## Status

Accepted

## Context

ADR-0075 shipped a CustomPaint IPA annotation layer above Source Serif 4
orthography, plus Settings-hub toggles for IPA overlay and word-level
practice (loop / inspect sheet). Learners saw tofu glyphs, overlapping
labels (no width cap), and no usable way to tap the current word for
playback. Craft enrichment remained default-off behind a Settings switch
(ADR-0073).

Enjoy web already uses stacked English + IPA word columns, familiar-form
`IPA_MAPPINGS`, and an IPA toggle on the player chrome. Stored phones were
also corrupted when eSpeak IPA UTF-8 bytes were decoded with
`String.fromCharCodes` (Latin-1 mojibake / tofu).

This ADR does **not** rewrite ADR-0070–0075; it supersedes the overlay
paint model, inspect/loop UI, Settings-hub transcript section, and
ADR-0073’s default-off enrichment gate.

## Decision

1. **Stacked word columns** — when IPA overlay is on and the cue has
   phones, render a `Wrap` of per-word columns (orthography on top, IPA
   underneath), matching Enjoy web `AlignedWord`. Line-only cues stay
   today’s single `Text.rich`. Karaoke while overlay is on uses a bottom
   border on the active word column; overlay off keeps ADR-0074 in-place
   highlight.
2. **Familiar IPA mapping** — display uses `formatPhonesAsFamiliarIpa`
   (ported from `@enjoy/utils/ipa`): tokenize concatenated eSpeak chunks,
   apply `IPA_MAPPINGS`, join without slash wrappers. No G2P; no invented
   phones.
3. **Noto Sans for IPA** — IPA labels use `GoogleFonts.notoSans()` so IPA
   Extensions rasterize. Orthography keeps Source Serif 4 / Inter.
4. **Tap IPA → play that word once** — `seekToWord` + `play()`. Not A-B
   loop. No inspect sheet. Orthography on selectable (active/echo) rows
   stays dictionary lookup. Unrevealed blur: IPA is not shown or
   hittable.
5. **Subtitle-sheet transcript controls** — karaoke + IPA switches live in
   the CC subtitle track picker (sheet / dialog), not Settings → Transcript
   and not a separate panel tune button. IPA switch is disabled until the
   current primary transcript has phones. Blur stays on the transport bar.
   The Settings Transcript section is removed.
6. **Craft enrichment always on** — every real (non-dedupe) Craft save
   attempts `alignSegments`. Failure stays fail-closed (line-only JSON,
   save succeeds). No enrichment Settings switch. Old
   `transcript.timelineEnrichment` keys remain allowlisted but unread.
7. **Retired UI** — word-level practice Settings toggle, meta-row loop /
   inspect icons, and the inspect sheet are removed. Ephemeral word-loop
   infrastructure may remain unused for a follow-up; product path is
   IPA tap-to-play only.
8. **eSpeak phoneme UTF-8** — `espeakINITIALIZE_PHONEME_IPA` writes UTF-8
   into `id.string[8]`; decode with `utf8.decode`, never
   `String.fromCharCodes` on raw bytes. Display also repairs Latin-1
   mojibake for phones already stored before the fix.

## Consequences

- IPA is readable and tappable on the current line without leaving the
  player.
- New Craft saves get nested timings when alignment succeeds, without a
  user toggle.
- Existing library items are not backfilled.
- Remaining #527 G2P / phonemizer work for line-only captions stays
  deferred.
