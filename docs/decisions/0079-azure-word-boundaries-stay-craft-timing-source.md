# ADR-0079: Azure TTS word boundaries stay the Craft line-timing source

## Status
Accepted

## Context

Issue #540 §5 proposed deprecating `TtsResult.wordBoundaries` as a
transcript-timeline source: attach `@Deprecated` to every timeline-source
consumer (`byok_tts_azure_capability.dart`, `craft_tts_service_synthesizer.dart`)
and route Craft transcripts exclusively through the on-device DTW engine.

The slices that actually shipped (ADR-0063, ADR-0073, ADR-0078) took a
different, strictly additive path:

- Azure `wordBoundaries` remain the **primary** cue-window source for Craft
  transcripts (ADR-0063): they decide where each line starts and ends, and
  they serve first-play timing hints before any enrichment runs.
- DTW enrichment (ADR-0073 / ADR-0076 / ADR-0078) never replaces those
  windows. It attaches nested `timeline[]` word/phone spans **inside** the
  existing cues; cues without enrichment render exactly as before.
- Consumers that would have been deprecated either do not use
  `wordBoundaries` as a timeline anymore (the enricher owns nested spans) or
  legitimately still need them (first-play hints, line windows).

Deprecating `wordBoundaries` now would annotate live, load-bearing code with
a migration path that does not exist.

## Decision

1. **Reject the issue #540 §5 deprecation.** `TtsResult.wordBoundaries` and
   its existing consumers keep their current API — no `@Deprecated`
   annotation, no rename, no removal track.
2. **Boundaries are the line-timing source; DTW is the sub-line source.**
   Azure boundaries decide cue windows; the forced-alignment engine adds
   word/phone spans within them. Neither substitutes for the other.
3. **New timeline consumers must not read `wordBoundaries`.** Any future
   word- or phone-level timing consumer uses `packages/forced_alignment`
   output (nested `timeline` cues), not cloud boundaries.
4. **Close the issue checklist item as rejected-by-implementation.** The
   `Deprecation commit` task in #540 §12 is resolved by this ADR, not by a
   code change.

## Consequences

- `packages/azure_speech` API surface is unchanged; BYOK Azure TTS keeps
  working without migration.
- The boundary-drift limitation documented in #540 §5 remains accepted for
  line-level windows; accuracy gains come from nested DTW spans instead.
- If DTW ever proves strictly better at cue segmentation, a future ADR can
  supersede this one — the additive shape makes that swap local.
