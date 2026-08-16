# Contract: Enrichment fallback

Craft save MUST complete with today’s transcript when enrichment cannot succeed.

## Fallback (persist spec 030 JSON, no nested spans)

| Cause | Engine / extract reason |
|-------|-------------------------|
| Setting off | skipped |
| Blank 030 transcript | skipped (do not invent lines) |
| Dedupe hit | skipped (do not rewrite) |
| PCM extract failed | audio unavailable |
| Spoken reference missing | `spokenReferenceUnavailable` |
| Language not in focus map | `unsupportedLanguage` (or skip before call) |
| Cancel / timeout | `cancelled` / `timedOut` |
| Mapping threw / empty unexpected payload | treat as failed |

## Forbidden

- Encoding failure as `AlignmentSuccess` with a duration-model or letter-split timeline.
- Blocking `CraftSaveFailure` solely because alignment failed.
- Required learner-facing error chrome on fallback.
- Extra AI credits or a network call beyond the synthesis the learner already ran.

## Logging

`logNamed('craft.enrichment')` (or `alignment.enrichment`) at warning for fallback reason. No `print()`.
