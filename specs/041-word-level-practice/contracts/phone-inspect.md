# Contract: Phone inspect

On-demand ordered list of stored phone labels for the **chosen** or **current** timed word.

## Surface

`showEnjoyAdaptiveSheet` (ADR-0065, root navigator). Title / body show the word text plus each non-empty `TranscriptPhone.phone` in stored order. No times required in v1 (times MAY be shown as secondary text if already stored).

## Visibility

- Practice on
- A chosen/current timed word exists
- That word has at least one non-empty `phone`
- Cue text is already visible (blur off or revealed)

If there are no stored phones: **omit** the inspect icon (quiet empty). Do not invent IPA. Do not run alignment. Do not call Worker `/pronounce` in this slice.

Selectable rows: inspect is the meta-row icon, never a competing text tap.

## Tests

- Word with `["æ", "n"]` → sheet lists those two strings in order; word orthography present; lookup string not involved
- Word with empty/missing phones → no inspect control
- Overlay on + inspect: sheet still lists pieces; line annotation still concat
- Assessment take-replay dialog unchanged
