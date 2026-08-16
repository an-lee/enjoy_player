# ADR-0073: Craft timeline enrichment (first product caller)

## Status

Accepted

## Context

ADR-0070 stores optional nested word/phone spans on cues. ADR-0071 and
ADR-0072 shipped `packages/forced_alignment` with spoken-reference
`alignSegments`, still unused by product flows. Issue #540 slice 3 needs a
**first caller** that can persist those nested spans without changing what
learners see in the transcript panel.

Craft already writes spec 030 synthesis-timing lines (or a blank transcript)
on save. Alignment quality is not guaranteed on every clip, language, or
host (missing eSpeak voice, extract failure, timeout). Save must not become
more fragile than today.

This ADR does **not** rewrite ADR-0070–0072.

## Decision

1. **First product caller is Craft save** — after `buildCraftPrimaryTimelineJson`
   and before import/update. Caption import, YouTube, ASR, and auto-translate
   stay line-only writers. Dedupe hits skip enrichment and do not rewrite the
   existing item.
2. **Default-off setting** — `transcript.timelineEnrichment` in `SettingsDao`
   (`'true'`/`'false'`, missing ≡ off). Settings hub shows a Transcript
   section with one switch. Settings Dart must not import
   `package:forced_alignment/`. Turning the switch on does not backfill the
   library.
3. **Keep spec 030 lines** — enrichment attaches nested `TranscriptWord` /
   `TranscriptPhone` onto the same line text/start/duration. Do not call
   whole-clip `align()`. Segment `id` is the line index. Word times are
   milliseconds relative to the line; phones stay in media-timeline seconds.
   Craft may pass a primary tag (`en`); map it onto a focus alignment tag
   (`en-US`) without swapping to a different language family.
4. **Fail closed** — setting off, blank 030 JSON, extract failure, or
   `AlignmentFailed` (including `spokenReferenceUnavailable`, unsupported
   language, cancel, timeout) persist today’s line-only (or blank) JSON.
   Alignment failure is never a blocking `CraftSaveFailure`. Quiet
   `logNamed('craft.enrichment')` only. Never invent a transcript. Never
   encode a duration-model stand-in as success. Honor the persisted setting
   on the next save without treating a still-loading Settings read as off.
5. **No karaoke / no reference playback** — the panel stays line-level.
   Learners still hear Craft `previewAudioBytes` / saved WAV. The spoken
   eSpeak reference is never played. No new `media_kit` `Player()`.

## Consequences

- Opt-in Craft items can store nested JSON that later karaoke / IPA slices
  can read without a second alignment pass.
- Default Craft/library behavior matches the pre-feature build.
- Mapping and PCM live in `lib/data` so Craft does not import ASR.
- Karaoke, IPA overlay, per-word tap, library backfill, first-play
  alignment, and YouTube demux remain later slices.
