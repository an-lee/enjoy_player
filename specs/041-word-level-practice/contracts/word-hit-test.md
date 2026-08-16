# Contract: Word hit-test and seek

Pure logic in `lib/data/subtitle` plus `PlayerInteractions.seekToWord`.

## Timed target

A word is a seek target when all of:

- Practice setting is on
- Row is **not** selectable (not active, not in echo)
- `word.text` non-empty, `word.durationMs > 0`
- Media window `[line.startMs + word.startMs, + duration)` intersects the parent line window

## Hit-test

1. Strip markup: `plain = transcriptPlainForSelection(line.text)`
2. Sequential substring ranges for each word (same algorithm as `wordHighlightRange`)
3. Tap offset → `TextPainter.getPositionForOffset` → UTF-16 offset in `plain`
4. If offset is inside a seek-target range, that word wins (last overlapping range if needed)
5. Otherwise the tap is a **line** seek (including gaps, punctuation, untimed words, timestamp/meta chrome)

## Seek

`seekToWord(line, lineIndex, wordIndex)`:

- Target seconds = `(line.startMs + word.startMs) / 1000`
- Then play
- If echo is **already** active, keep today’s `_seekLine` echo **retarget** to this line (otherwise the enforcer clamps back into the old echo) but seek to the **word** start, not the line start
- Does **not** start a word loop by itself
- Sets the ephemeral chosen word

Selectable rows MUST NOT call this from a text tap.

## Tests

- Unit: `Hello world` ranges; offset in `world` → index 1; offset in the space → null (line fallthrough)
- Unit: untimed / out-of-line window → not a target
- Widget: practice on + non-selectable nested cue + tap second word → `seekToWord` with that index, not line start
- Widget: practice on + tap timestamp → line seek
- Widget: practice on + selectable row text tap → no `seekToWord`; lookup path unchanged
- Widget: practice off → all taps line-level
