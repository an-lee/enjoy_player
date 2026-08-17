# ADR-0078: On-demand transcript enrichment (gated karaoke/IPA)

## Status
Accepted

## Context

Karaoke highlight (ADR-0074) and stacked IPA (ADR-0076) only **read** nested
`timeline` words / `phones`. Caption import, YouTube, and ASR still write
line-only cues. Craft save (ADR-0073 / ADR-0076) is the only automatic
enrichment path, so most library items leave karaoke and IPA switches looking
available while paint/tap do nothing.

Learners need an explicit way to generate nested data for the **current
primary** track. YouTube playback does not give the app extractable audio, so
word clocks cannot be trusted there. IPA overlay concatenates phone **labels**
and ignores clocks, so YouTube can still get pronunciation without demux.

This ADR does **not** rewrite ADR-0070–0077. It supplements ADR-0070’s nested
JSON and ADR-0076’s CC-sheet switches. It supersedes ADR-0076’s “no generate
path / Craft-only phones” **for this CC-sheet button only**. Craft save stays
always-on. Import / YouTube / ASR writers stay line-only until the learner
taps enrich.

## Decision

1. **Gate switches on nested data + extractability** — karaoke is enableable
   only when the primary track has timed words **and** the item is a trusted
   local file (`LocalFilePlayableSource`). IPA is enableable when any word has
   a displayable phone label. Preference keys
   `transcript.karaokeHighlight` / `transcript.ipaOverlay` stay global;
   switch **value** is preference && capability. Gated switches do not write
   `false` over a stored `true`.
2. **Explicit enrich tile** — when the primary track has lines and **no**
   nested words, the CC display card shows a generate tile
   (`TranscriptBusyListTile`). Opening the sheet, playing, seeking, or
   toggling switches does **not** start work. Success hides the tile and
   recomputes switches from the new lines without restart.
3. **Owned media** — extract local PCM (`decodeFileToPcm16kMono` / windowed
   `-ss`/`-t`), then `alignSegments` (short) or per-cue `align()` (last cue
   after ~90 s). Persist timed words + phones in place via
   `TranscriptRepository.replaceTimeline` (same id/source/language/label).
4. **YouTube / non-extractable** — `phonemizeLines` via eSpeak spoken
   reference (discard PCM). Store **untimed** words + IPA labels. Karaoke
   stays off. Never FFmpeg or demux the media URL. Fake equal-split word
   clocks are forbidden. IPA tap stays a no-op when `wordMediaWindowMs` is
   null.
5. **Optional JSON clocks** — `TranscriptWord.start`/`duration` and
   `TranscriptPhone.startTime`/`endTime` may be omitted. Missing clocks parse
   as null (word duration is **not** defaulted to `0`). Karaoke matching
   skips null or non-positive duration.
6. **Fail closed / primary only** — failed or cancelled runs leave previous
   captions. Partial cue success keeps failed cues line-only. Secondary /
   translation tracks are not enriched. Transcript **application** may import
   `package:forced_alignment/`; presentation, settings, player, ASR, lookup,
   and l10n must not. Transcript must not import Craft or ASR.

## Consequences

- Line-only local items can become karaoke+IPA capable from the CC sheet.
- YouTube can show IPA without karaoke or a local copy of the video.
- Craft save remains the automatic enrich path; this button is on-demand and
  in-place on the current primary track.
- Long owned files pay per-cue extract + `align()` instead of one unbounded
  whole-file `align()`.
