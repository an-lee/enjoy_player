# Research: Karaoke Word Highlight

**Feature**: `040-karaoke-word-highlight` | **Date**: 2026-08-16

Slice 3 already persists optional nested word/phone spans on Craft save. The panel still ignores them. This research locks how the panel becomes the first **reader** without changing save, alignment, or line-level practice.

## Decisions

### 1. Independent display setting (not enrichment, not a practice mode)

**Decision**: Add `SettingsKeys.transcriptKaraokeHighlight = 'transcript.karaokeHighlight'` (`'true'`/`'false'`, missing ≡ off) on the **device-global** `SettingsDao` (same store as enrichment). Keep-alive Riverpod notifier mirroring `TimelineEnrichmentSettings`, including `resolveEnabled` / `ref.read(…).future` so the first play after launch cannot treat a still-loading read as off.

Place a **second** `SettingsRow` + `Switch.adaptive` in the existing Transcript section (after enrichment). Register `rowId = karaokeHighlight` in the spec 004 search registry. Honor on the next play without restart.

Karaoke does **not** require `transcript.timelineEnrichment` to be on at play time.

**Rationale**: Spec US4 / FR-001 / FR-002. Echo and blur are per-media practice modes; karaoke is a persisted reading preference. Coupling display to the Craft **save** toggle would hide timings on already-enriched items.

**Alternatives considered**:
- Transport-bar toggle like blur — more discoverable during play, but would be another per-session mode; spec assumes Settings.
- Auto-on whenever nested data exists — violates “off by default.”
- Reuse enrichment key — mixes save vs display.

### 2. In-place highlight of existing line text, not chips

**Decision**: Keep one `Text.rich` / selectable rich text for the primary line. When karaoke is on and a current word exists, paint that substring with a distinct style (background or primary-container tint + weight) **inside** the existing markup tree. Do not replace the line with tappable word chips (assessment-result UI). Secondary/translation text is never highlighted.

Tap/seek/lookup stay line-level (`onTap` / selection toolbar unchanged).

**Rationale**: FR-005 / FR-007. Chips would be slice 5 and would fight selection lookup.

**Alternatives considered**:
- Word `Wrap` of `Chip`s — new tap targets; rejected.
- Overlay highlighter by pixel — fragile with markup/CJK; rejected.

### 3. Time match first; then map word text onto plain line text

**Decision**: Pure functions in `lib/data/subtitle/current_transcript_word.dart` (no Flutter):

1. `currentWordIndex(line, positionMs) → int?`  
   Media position `p`. Word `i` matches when  
   `line.startMs + word.startMs ≤ p < line.startMs + word.startMs + word.durationMs`  
   (last matching word in list order if windows overlap). Skip words with empty text or non-positive duration. Ignore words whose window lies entirely outside `[line.startMs, line.startMs + line.durationMs]` (FR-009).
2. `wordHighlightRange(plainLineText, words, index) → (start, end)?`  
   Walk words in order with a sequential substring search on `transcriptPlainForSelection` text. If word `index` cannot be located, return null (no paint; line still shows).

Never invent a split of a line-only cue.

**Rationale**: Spec edge cases + slice 1 “mismatch MUST NOT blank the line.” Times decide *which* word; text mapping decides *where* to paint.

**Alternatives considered**:
- Split `line.text` on whitespace and index by token — breaks markup/CJK/punctuation (`doesn` vs `doesn't`).
- Highlight by character width from alignment — not stored.

### 4. 50 ms karaoke bucket; keep 400 ms line highlight

**Decision**: Add `kPositionBucketKaraokeMs = 50` next to the existing scrubber bucket. `karaokeWordIndexProvider(mediaId)` watches `rawEnginePositionStreamProvider` through `quantizedPositionStream(..., bucketMs: 50)`, plus current cue index and the karaoke setting. Return `int?` (word index on the **current** primary line). Consumers `.select` so inactive tiles do not rebuild.

Do **not** change `kPositionBucketDisplayMs = 400` (transcript list + a11y flood on Windows).

Paused: last quantized position remains → word stays highlighted. Stop/clear: provider returns null with the rest of playback chrome.

**Rationale**: SC-008 vs `flutter/flutter#182444`. 400 ms display buckets can skip an entire short word; 50 ms is already used by the scrubber.

**Alternatives considered**:
- Reuse `displayPositionProvider` — too coarse for karaoke.
- Raw unbucketed ticks into every tile — list jank / a11y flood.

### 5. Blur, echo, lookup unchanged except paint on visible primary text

**Decision**:
- Blur: karaoke MUST NOT write `transcriptCueRevealProvider`. Highlight may exist under the blur filter; it only becomes visible when the cue is already revealed (hover/hold) or blur is off.
- Echo: same `TranscriptLineTile`; highlight on primary text of the active echo cue when karaoke is on.
- Lookup: selectable cues keep the selection toolbar; words are not exclusive hit targets.
- Auto-follow still targets the **line** / echo block.

**Rationale**: Spec US4. Assessment-result Azure chip karaoke stays a separate surface (no shared setting).

**Alternatives considered**:
- Auto-unblur the current word — violates spec 006 / FR-010.

### 6. Writers and alignment stay inert

**Decision**: Import, YouTube, ASR, auto-translate, and Craft save are unchanged. This slice does not call `alignSegments`. Transcript and Settings Dart MUST NOT import `package:forced_alignment/`. Keep forbidding that import in those roots; **allow** transcript to *read* `TranscriptLine.timeline` for highlight.

Retarget `transcript_line_tile_nested_inert_test.dart`: default (karaoke off) still shows no IPA and identical line text; add a karaoke-on test that highlights word text without showing `phones[].phone`.

**Rationale**: FR-012–FR-015. Slice 3 already writes nested JSON.

### 7. ADR-0074; docs

**Decision**: New ADR-0074 (panel consumer, independent setting, in-place highlight, karaoke bucket, no IPA/tap). Do not rewrite ADR-0070–0073. Update `docs/features/transcript.md` (nested spans are no longer fully inert when karaoke is on). Settings search keywords: karaoke, word highlight, timings.

**Rationale**: Constitution V.

## Open items resolved (no spec change)

| Topic | Resolution |
|-------|------------|
| Where the toggle lives | Settings → Transcript, second row |
| Setting key | `transcript.karaokeHighlight` |
| Coupling to enrichment | Independent |
| Visual | In-place span, not chips |
| Position cadence | 50 ms karaoke bucket only |
| Blur | No auto-reveal |
| IPA | Not shown |
| Play-time alignment | None |

## Dependencies

- Slice 1 nested cue JSON (ADR-0070) and slice 3 Craft writer (ADR-0073) for typical data. Karaoke still works on any cue that already has timed words.
- `displayPosition` / `rawEnginePositionStream` / `quantizedPositionStream` (ADR-0015 player engine).
- Settings hub Transcript section from 039.
- Blur contracts from spec 006.
