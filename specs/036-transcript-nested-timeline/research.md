# Research: Nested Transcript Timeline

**Feature**: `036-transcript-nested-timeline` | **Date**: 2026-08-12

## Decisions

### 1. Product shape matches enjoy web (line → word → phone)

**Decision**: Persist optional `timeline` (`TranscriptWord[]`) on `TranscriptLine` and optional `phones` (`PhoneTiming[]`) on each word — the same stored cue as enjoy web Spec 027 (`apps/web/src/types/db/transcript.ts`). Do **not** store a recursive Echogarden `type` / `startTime` tree on the cue.

**Rationale**: Flutter and the web app share the same backend API and transcript payloads. The stored cue is enjoy web Spec 027. Issue #540’s alignment package (slice 2) will emit Echogarden-shaped recursive entries; slice 3’s adapter flattens into this model, same as web.

**Alternatives considered**:
- Flutter-invented `words` / `phonemes` / `ipa` with millisecond phones — rejected; would diverge from the shared API.
- Recursive `List<TimelineEntry>? timeline` on the cue (browser extension local type) — not the shared API contract; unused this slice.

### 2. JSON keys and units match enjoy web

**Decision**:
- Line: `text`, `start`, `duration` (ms, media timeline); optional `confidence`; Flutter-only optional `sourceKey`.
- Word: `text`, `start`, `duration` (ms **relative to the parent line**); optional `phones`.
- Phone: `phone`, `text`, `startTime`, `endTime` (**seconds**), optional `wordIndex` — `@enjoy/alignment` `PhoneTiming`.
- Omit empty optional keys (same pattern as `sourceKey`). Do not read or write a second nested vocabulary (`words`, `phonemes`, `ipa`).

**Rationale**: Web already ships this contract. Mixing a second naming scheme would split readers and invite unit bugs. Seconds belong on phones because that is how `PhoneTiming` is persisted on web; word offsets stay in cue milliseconds.

**Alternatives considered**:
- Millisecond `{ipa, start, duration}` phones — rejected; not the shared API.
- Dual-read aliases (`words` / `phonemes` / extension nested `timeline`) — rejected; the clients share one data source.
- `startMs` in JSON — inconsistent with existing cue keys.

### 3. Empty nested lists normalize to absent

**Decision**: `fromJson` and `toJson` treat missing, `null`, and empty `timeline` / `phones` as **absent** (`null` in memory; key omitted on write). `==` therefore does not distinguish `null` from `[]`.

**Rationale**: Spec: omitted vs empty are both line-only cues. Distinguishing them would cause stream `distinctBy(listEquals)` churn and larger JSON for no product value. Older readers that only understand line fields never see a `timeline: []` key.

**Alternatives considered**:
- Preserve empty lists — extra bytes and two “empty” states; rejected.

### 4. Value equality includes nested data; line identity does not

**Decision**:
- `TranscriptLine.==` / `hashCode` include `timeline` and `confidence` (after empty→null normalize).
- `cueIdFor` stays `{startMs, endMs, hash(plain text)}` — **no** nested fields.
- Auto-translate `sourceKey` stays a fingerprint of **line** text + language pair (ADR-0039).
- Echo membership, current-line index, tap-to-seek, and blur continue to use line times / line index / `cueIdFor`.

**Rationale**: FR-013: adding nested spans must not treat the cue as a different line for practice features. Value equality including words lets a later enrichment pass re-emit the lines stream (needed for karaoke) without changing blur/echo identity.

**Alternatives considered**:
- Exclude `timeline` from `==` — later enrichment would not notify `transcriptLinesForMediaProvider` listeners (`distinctBy(listEquals)`). Rejected.
- Fold words into `cueIdFor` — would reset blur holds and look like a new cue; rejected.

### 5. Malformed nested data degrades per cue, never drops the line

**Decision**: Parse line fields first. If `timeline` is not a list, ignore it. Skip non-object elements, words with empty `text`, and phones with empty labels. Never throw from `TranscriptLine.fromJson` for nested junk. The rest of the track still loads.

**Rationale**: FR-010 / SC-005. `transcriptLinesFromApiTimeline` already skips non-object cues via `castJsonObjectOrNull`; nested parse must be equally defensive (`castJsonObjectOrNull` + `intFromJson`).

**Alternatives considered**:
- Fail the whole track on one bad word — violates “0 cues disappear.”
- Keep invalid words with empty text — pollutes later karaoke; skip instead.

### 6. No Drift migration; writers stay line-only

**Decision**: Nested data lives inside existing `transcripts.timeline_json` (TEXT). No schema change. Import, YouTube, ASR grouping, Craft synthesis builder, and auto-translate skeleton keep emitting line-only JSON in this slice.

**Rationale**: Same additive pattern as ADR-0039 `sourceKey`. FR-007 / FR-012. Producers that started writing `timeline` now would change Craft/ASR output without a consumer — out of scope.

### 7. Documentation: focused ADR + transcript feature note

**Decision**: Add **ADR-0070** (enjoy-web nested cue JSON; line identity unchanged; alignment tree stays out of the stored cue). Update `docs/features/transcript.md` with a short “Nested word/phone spans (storage only)” note. No Settings copy, no ARB strings, no UI chrome.

**Rationale**: Constitution V — the JSON contract is costly to reverse. Feature behavior is “no visible change,” which still needs a doc so later slices do not assume the panel already consumes `timeline`.

**Alternatives considered**:
- Defer ADR until slice 2 — the storage shape would already be in production without a decision record; rejected.

## Resolved unknowns

| Topic | Resolution |
|-------|------------|
| Recursive vs flat | Flat `timeline` / `phones` matching enjoy web |
| Line / word JSON units | Milliseconds; keys `start` / `duration`; word times relative to parent line |
| Phone JSON units | Seconds; keys `startTime` / `endTime` (`PhoneTiming`) |
| Empty lists | Normalize to omitted / `null` |
| `==` vs identity | Nested in `==`; not in `cueIdFor` / `sourceKey` |
| Bad JSON | Skip nested junk; keep line fields |
| Schema | No Drift migration |
| Settings toggle | Not this slice |
| copyWith | Optional helper on `TranscriptLine` if it simplifies tests; not required for the product |

## Open risks (implementation / QA, not blockers)

1. **Cloud round-trip**: Worker/API may strip unknown keys. This slice does not require the server to persist `timeline`; local Drift is the source of truth. If a future sync path rewrites `timeline_json` from a server payload that omits nested words, that is a slice-3+ concern.
2. **Equality test updates**: `transcript_lines_provider_dedupe_test` “changing any field breaks ==” should gain a nested-words case so identity vs value equality stays documented.
3. **Large nested fixtures**: Only test fixtures carry nested data this slice; production rows stay flat. Parse cost is one extra key lookup per cue.
