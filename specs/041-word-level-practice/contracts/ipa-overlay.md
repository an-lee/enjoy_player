# Contract: IPA overlay

Display-only. Uses stored `TranscriptPhone.phone` labels. Does not generate IPA.

## Default (overlay off)

Matches post-slice-4 nested-inert pin:

- Line text, timestamp, and semantics equal a line-only cue with the same line fields (karaoke may still highlight if on)
- No IPA / `phones[].phone` strings in the tree, annotation layer, or semantics
- Nested `timeline` does not change `cueIdFor`

## Overlay on + words with stored phones

- Primary orthography stays the existing rich / selectable text (karaoke highlight still in-place on **word text**)
- Each word with a non-empty concatenated `phone` list shows that spelling in an `IgnorePointer` annotation layer aligned to the word’s plain-text box
- Words without phones: orthography only (no empty error chrome)
- Line-only cues: no annotation layer, no fake split
- Translation / secondary line: never annotated
- `transcriptPlainForSelection` and dictionary lookup payloads MUST equal today’s transcript text (never IPA)
- Phone-level karaoke is out of scope (FR-017)

## Overlay on + blur

- MUST NOT write `transcriptCueRevealProvider`
- Annotation layer is inside the blur wrapper; IPA MUST NOT be readable through an unrevealed cue

## Tests

- Overlay **off** + nested phones: no phone labels in finders / semantics (inert pin)
- Overlay **on** + three words with phones + one without: three IPA strings present; the untimed/no-phone word has none; line text still appears once as orthography
- Overlay **on** + selectable row: simulated selection / lookup callback receives orthography only
- Overlay **on** + practice **off**: non-selectable tap still line-seeks
- Overlay **on** + line-only cue: widget tree matches overlay off aside from settings
- Overlay **on** + blur: active cue stays blurred; IPA not visible until hover/hold
