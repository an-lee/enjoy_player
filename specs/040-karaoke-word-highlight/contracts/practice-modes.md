# Contract: Practice modes

Karaoke is paint-only on primary text. Line identity rules do not change.

## Echo

- Echo membership, expand/shrink, and merged echo card still use line times
- When karaoke is on and the active echo cue has timed words, the current word MAY highlight on that cue’s primary text
- Shadow-reading **assessment** take-replay chip karaoke is unchanged and does not read `transcript.karaokeHighlight`

## Blur (spec 006)

- Karaoke MUST NOT auto-reveal the active cue (`transcriptCueRevealProvider` / hover-hold unchanged)
- While the cue is blurred, word highlight MUST NOT punch a visible hole through the blur
- After hover or tap-hold reveal, highlight MAY show on the revealed primary text

## Lookup

- Selection toolbar and 1–100 character lookup still apply to the line / selected substring
- Words are not exclusive hit targets

## Auto-translate

- Secondary line stays line-level (no word highlight)
- `sourceKey` / `cueIdFor` still ignore nested spans

## Tests

- Blur + karaoke on + active nested cue: existing “active line stays blurred” assertion still holds
- Echo + karaoke: highlight allowed on primary; echo region still groups by line
- Translation line present: 0 highlight styles on secondary text
