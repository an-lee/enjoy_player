# Contract: Word loop

Ephemeral A-B wrap of **one** timed word. Not an echo region.

## State

In-memory `WordLoopController` per open media: `lineIndex`, `wordIndex`, `mediaStartMs`, `mediaEndMs`. Missing ≡ inactive. Never written to `SessionDao`.

## Start

Practice on + a chosen or current timed word with a valid media window. Loop icon on selectable active/echo cues uses `activeCueWordIndexProvider` (works with karaoke off).

## Tick

`WordLoopEnforcer` runs on engine position **before** `EchoEnforcer.enforceTick`:

- If position ≥ `mediaEndMs` (ordinary playback), seek to `mediaStartMs` and keep playing (do not pause)
- While looping, **skip** echo pause-and-rewind so the echo end cannot steal the wrap
- `EchoEnforcer.clampAndSeek` still applies to user seeks when echo is on
- Speed changes apply as ordinary playback

## Cancel (clear state)

- Stop / clear media / media switch
- Practice setting off
- Progress-bar scrub
- Line chrome seek
- Seek to a different word
- Echo shrink that removes the looping line from the echo window

Expand/shrink echo still mutates **line** indices only (FR-008).

## Tests

- Unit: wrap decision at `mediaEndMs` → seek start; position inside window → no-op
- Widget/controller: start loop → two wraps without echo start/end changing
- Echo expand/shrink during loop → echo membership still line-based; loop still the same word until cancel rules fire
- Cancel via practice off / stop → no further wraps
- Karaoke on + loop: highlight may follow the looping word; auto-follow still the **line**
