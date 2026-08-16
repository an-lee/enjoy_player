# Contract: Panel render

## Default (karaoke off)

Matches post-slice-3 / nested-inert pin:

- Line text, timestamp, and semantics equal a line-only cue with the same line fields
- No IPA / `phones[].phone` strings in the tree or semantics
- No per-word chips or extra tap targets
- Nested `timeline` does not change `cueIdFor`

## Karaoke on + timed current word

- Primary line stays a single rich-text block (selectable when the cue is active/echo)
- The located substring uses a distinct highlight style; the rest of the line stays readable
- Markup (colors/bold/italic) still applies; highlight is an additional style on overlapping plain-text range
- Translation / secondary line is unhighlighted
- Semantics MAY mention current-word state on the active cue; MUST still include line snippet; MUST NOT dump phone IPA labels

## Karaoke on + no current word

Line-level presentation only (no fake whitespace split).

## Interactions

- Non-active, non-echo tap still seeks to **line** start
- Active/echo tap still lookup/select, not seek-to-word
- Auto-follow still the line / echo block

## Tests

- Nested inert test remains green with karaoke **off**
- Karaoke **on** + position in first word: finder shows line text once; highlight style present; `æ̃ˈxyz` / phone labels absent
- Karaoke **on** + line-only cue: no extra widgets vs off
- Tap on a non-active nested cue still invokes the tile `onTap` (line seek), not a per-word callback
