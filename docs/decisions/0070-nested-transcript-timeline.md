# ADR-0070: Additive nested transcript cue JSON

## Status

Accepted

## Context

Transcript cues are stored as a JSON array in `transcripts.timeline_json` with `{text, start, duration}` (plus optional `sourceKey` from ADR-0039). That line-only shape blocks karaoke highlighting, IPA on words, and alignment-enriched Craft transcripts (issue #540).

Enjoy web (`apps/web/src/types/db/transcript.ts`, Spec 027) already persists nested word/phone data on each cue. Flutter must use the same JSON so local rows, sync, and later alignment work stay interchangeable with the web app.

A full recursive Echogarden `type` / `startTime` tree is the alignment *engine* result, not the stored cue. Web flattens that into `TranscriptLine.timeline` + `TranscriptWord.phones`.

## Decision

1. **Match enjoy web cue JSON** — `TranscriptLine` may include optional `timeline` (`TranscriptWord[]`) and optional `confidence`. Each word may include optional `phones` (`PhoneTiming[]`). Required line fields stay `text`, `start`, `duration` (milliseconds). Optional Flutter-only `sourceKey` is unchanged.
2. **Word times are milliseconds relative to the parent line** (`start` / `duration`), as in enjoy web. Phone times follow `@enjoy/alignment` `PhoneTiming`: `phone`, `text`, `startTime`, `endTime` in **seconds**, optional `wordIndex`.
3. **Empty ≡ absent** — missing, null, and empty `timeline` / `phones` normalize to omitted / `null`.
4. **Line identity ignores nested data** — `cueIdFor`, auto-translate `sourceKey`, current-line tracking, echo membership, and tap-to-seek stay on line text and line times. Value equality (`==`) *does* include `timeline` so a later enrichment can notify the lines stream.
5. **No Drift migration** — nested data lives inside existing `timeline_json`. Historical rows remain valid.
6. **One JSON contract with enjoy web** — read and write the same keys (`timeline`, `phones`, `PhoneTiming`). Do not accept or emit a second nested shape (`words` / `phonemes` / `ipa`, or extension recursive `timeline` children as phones). Unknown keys are ignored. Flutter-only `sourceKey` stays an additive optional line field (ADR-0039).
7. **This slice does not consume nested data** — no karaoke, IPA overlay, Settings toggle, or producer changes.

## Consequences

- Local Drift rows, sync payloads, and enjoy web Dexie cues use one nested shape.
- Malformed nested JSON degrades to line-only for that cue; the track still loads.
- Panel chrome must not start reading `timeline` until a dedicated consumer spec (karaoke / IPA) lands.
- Alignment engine output (Echogarden recursive tree) is adapted into this shape in a later slice, same as enjoy web Spec 027.
