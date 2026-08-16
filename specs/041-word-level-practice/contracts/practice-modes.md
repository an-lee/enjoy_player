# Contract: Practice modes coexistence

Overlay is display. Word practice is interaction. Line identity rules do not change. Karaoke (ADR-0074) stays paint-only on word **text**.

## Karaoke

- Independent toggle. Practice does not require karaoke; overlay does not require karaoke
- Karaoke still highlights at most one current **word** substring; IPA annotation is not a second karaoke target
- `activeCueWordIndexProvider` may run when practice is on even if karaoke is off; `karaokeWordIndexProvider` stays null unless karaoke is on

## Echo

- Membership, expand/shrink, and merged echo card still use line times
- Selectable echo rows: no seek-to-word from text tap; loop/inspect via meta-row icons
- Tapping a non-echo line while echo is on may still retarget echo to that **line** (today’s `_seekLine`); seek lands on the word start when the tap hit a timed word
- Word loop must not assign echo start/end to the word window

## Blur (spec 006)

- Overlay and practice MUST NOT auto-reveal (`transcriptCueRevealProvider` / hover-hold unchanged)
- IPA MUST NOT punch through unrevealed blur (annotation inside the blur wrapper)
- Hidden word geometry MUST NOT be a cheat-reveal hit target; after reveal, overlay and word taps work

## Lookup (ADR-0019)

- Selection toolbar and 1–100 character lookup still apply to the line / selected substring
- Lookup payload MUST NOT include IPA
- Words are exclusive seek targets only on non-selectable rows when practice is on

## Auto-translate / auto-follow

- Secondary line stays line-level (no IPA, no word tap)
- `sourceKey` / `cueIdFor` still ignore nested spans
- Auto-follow still the line / echo block (FR-020)

## Tests

- Blur + overlay on + active nested cue: existing “active line stays blurred” assertion still holds; IPA not visible until reveal
- Echo + practice: loop does not change echo line indices
- Translation line present: 0 IPA annotations and 0 word seeks on secondary text
- Karaoke on + overlay on: highlight on orthography; IPA still visible with its word
