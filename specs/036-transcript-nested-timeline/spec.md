# Feature Specification: Nested Transcript Timeline

**Feature Branch**: `036-transcript-nested-timeline`

**Created**: 2026-08-12

**Status**: Draft

**Input**: User description: "Audit issue #540, split it into several specs, we start to implement the first foundation spec. We should make each spec shippable, not break any features."

**Source**: [GitHub issue #540](https://github.com/baizhiheizi/enjoy_player/issues/540) (on-device transcript timeline enrichment). This specification is **slice 1** of that program.

## Program split (issue #540)

Issue #540 asks for richer transcript timing (line → word → phone) so later work can add karaoke highlighting, IPA on words, and better Craft practice transcripts. Shipping that as one change would mix a data-model migration, a new alignment engine, Craft pipeline changes, and new transcript UI — any of which could regress existing practice.

Each slice below MUST be independently shippable: existing transcript, playback, Craft, import, speech-to-text, YouTube captions, echo, lookup, and translation behavior stay intact unless that slice’s opt-in path is explicitly on.

| Slice | Spec (planned) | What ships | Why it does not break existing features |
|-------|----------------|------------|----------------------------------------|
| **1 (this spec)** | Nested transcript timeline | A cue MAY carry optional word spans, and a word MAY carry optional phone spans. Flat cues remain valid. No new UI. No new learner setting. | Additive only. Every current flow keeps using line text and line times. Nested data is ignored until a later slice consumes it. |
| **2** | Alignment engine | A standalone capability that, given known text and extractable audio, can produce word- and phone-level timings. Not wired into Craft or the transcript panel. | Unused by product flows in that slice. Learners see no change. |
| **3** | Craft timeline enrichment | Opt-in: Craft items may store nested word/phone timings from alignment. Default remains today’s synthesis-timing transcript. Failures fall back to today’s path. | Off by default. On failure, Craft save and playback match pre-feature behavior. |
| **4** | Karaoke word highlight | Opt-in: while media plays, the transcript panel may highlight the current **word** when that cue has word timings. | Off by default, and inactive on cues with no word spans. Line-level current-cue behavior stays. |
| **5** | Word-level practice | Opt-in later: tap a word to seek, loop a word, inspect phones. | Same gates: no nested data → today’s line-level interactions. |
| **Related** | IPA overlay ([#527](https://github.com/baizhiheizi/enjoy_player/issues/527)) | Display pronunciation spelling per word. May consume phone/IPA fields this model allows, but is specified separately. | Own toggle and own spec; this slice only makes storage possible. |

**Out of the #540 program (all slices):** aligning YouTube WebView playback (no extractable audio), aligning the learner’s own shadow-reading recording, replacing Craft’s high-quality playback audio with a synthetic reference voice, real-time/streaming alignment, and cross-language alignment (audio in one language, transcript in another).

## Scope (this slice only)

### In scope

- Extend the stored transcript cue so it **can** hold optional nested word spans and optional nested phone spans without removing or renaming any existing cue field.
- Load and save nested data when it is present; omit it when it is absent.
- Guarantee that every existing transcript source (imported captions, YouTube captions, speech-to-text, Craft synthesis timings, auto-translate overlays) continues to produce and render **line-level** cues exactly as today.
- Guarantee that existing transcript interactions that key off line text and line times (current line, tap-to-seek line, echo region, blur practice, dictionary lookup, auto-translate fingerprinting) keep using those line-level fields even if nested data is present.

### Out of scope (this slice)

- Any new transcript panel visuals (karaoke, IPA ruby, word chips).
- Any new Settings toggle (nothing to opt into yet).
- Producing word/phone timings (alignment engine, Craft pipeline, speech-to-text word preservation).
- Changing how Craft builds line breaks from synthesis timings ([spec 030](../030-craft-tts-transcript/spec.md) remains the Craft line-quality contract).
- YouTube caption word timings.
- Database table redesign or a required migration of existing transcript rows.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Existing transcripts are unchanged (Priority: P1)

A learner opens media they already use: imported captions, YouTube captions, a speech-to-text track, or a Craft item with today’s synthesis-built lines. The transcript panel shows the same lines, the same times, and the same interactions as before this change. Nothing new appears. Nothing is missing.

**Why this priority**: The program’s hard constraint is “never break existing flows.” If this foundation slice changes what learners see or how they practice, it is not shippable.

**Independent Test**: Open a curated set of existing library items (at least one import, one YouTube item with captions, one speech-to-text track, one Craft item with a synthesis transcript). Confirm line text, line order, line start times, tap-to-seek, current-line tracking, echo region, lookup, and translation behave as they did on the pre-feature build.

**Acceptance Scenarios**:

1. **Given** a stored transcript whose cues have only line text and line times (no nested spans), **When** the learner opens that media, **Then** each cue’s visible text, start, and duration match the pre-feature record.
2. **Given** that same transcript, **When** the learner taps a non-active line, **Then** playback seeks to that line’s start as today.
3. **Given** that same transcript, **When** playback advances, **Then** the current-line highlight still follows line start/end, not any nested data.
4. **Given** echo mode, blur practice, dictionary lookup, or auto-translate on that transcript, **When** the learner uses those features, **Then** they complete with the same line identity rules as today (line text and line times).

---

### User Story 2 - A cue can remember optional word and phone spans (Priority: P1)

The product can store, on a single cue, an optional ordered list of words (each with text and optional start/duration), and on each word an optional ordered list of phones (each with a pronunciation spelling and optional start/duration). After save and reload, that nested data is still there. The cue’s line text, line start, and line duration are unchanged by the presence of nested data.

**Why this priority**: Later slices have nowhere to put alignment output unless this shape exists and round-trips. This is the entire user-visible “capability” of slice 1 (even though learners do not see a new control yet).

**Independent Test**: Persist a cue that includes nested word and phone spans; reload the transcript; confirm line fields are identical and every word/phone span is present with the same text, order, and times.

**Acceptance Scenarios**:

1. **Given** a cue with line text and times plus an ordered list of word spans, **When** the transcript is saved and loaded again, **Then** the word spans are present in the same order with the same text and times.
2. **Given** a word span that includes ordered phone spans (pronunciation spelling plus times), **When** the transcript is saved and loaded again, **Then** those phone spans are present unchanged.
3. **Given** a cue with nested spans, **When** it is saved and loaded, **Then** line text, line start, and line duration are identical to the values before save.
4. **Given** a cue with no nested spans, **When** it is saved and loaded, **Then** it remains a valid line-only cue (nested data absent, not required).

---

### User Story 3 - Nested data is inert until a later slice uses it (Priority: P1)

If a cue happens to include nested word or phone spans (for example after a future enrichment, or in a test fixture), the transcript panel and all current practice flows still treat that cue as a normal line. Learners do not see word highlight, IPA, or new tap targets in this slice. Enriching a cue MUST NOT reset which line is current, the echo window, scroll position, or translation identity of that line.

**Why this priority**: Slice 1 must be safe to ship before karaoke or Craft enrichment exist. Nested data cannot become a breaking side channel.

**Independent Test**: Load a transcript where some cues include nested spans and others do not. Use playback, tap-to-seek, echo, lookup, and auto-translate. Confirm behavior matches line-only cues and that no new word-level UI appears.

**Acceptance Scenarios**:

1. **Given** a mix of line-only cues and cues that also have nested spans, **When** the transcript panel renders, **Then** every cue still shows the same line-level text presentation as today (no karaoke, no IPA overlay, no per-word chips).
2. **Given** a cue that gains nested spans while it remains the same line text and line times, **When** playback or echo is already using that cue, **Then** current-line, echo membership, and seek-to-line behavior do not jump or reset.
3. **Given** auto-translate or blur practice keyed to a cue, **When** nested spans are present or later added, **Then** that cue is still the same line for those features (identity stays on line text and line times).
4. **Given** a cue whose nested spans are incomplete (words without times, phones without times, or only some words nested), **When** the panel renders, **Then** the line still displays and seeks using line-level fields; incomplete nested data is ignored, not treated as an error.

---

### Edge Cases

- **Omitted vs empty nested lists**: A cue with no nested field and a cue with an empty word list are both valid line-only cues; neither crashes load or render.
- **Partial timing**: Words or phones may omit start/duration. Line-level times remain authoritative for playback tracking in this slice.
- **Times outside the parent cue**: Nested start/duration that fall outside the cue’s line window MUST NOT change line start/duration or current-line tracking. Later slices may clamp or ignore those spans; this slice must still load the cue.
- **Malformed nested data**: Unreadable nested fields MUST NOT prevent loading the line text and line times. The cue degrades to line-only.
- **Whitespace / concatenation**: Nested word texts SHOULD correspond to the line text, but a mismatch MUST NOT blank the line or block playback; line text remains the displayed source in this slice.
- **Very large nested lists**: A long cue with many words/phones MUST still load; this slice does not add new scrolling or virtualization requirements beyond today’s list.
- **Mixed tracks**: Primary and secondary (translation) tracks may independently have or lack nested data. Secondary-track matching and auto-translate stay line-index / line-fingerprint based as today.
- **Existing writers**: Import, YouTube captions, speech-to-text grouping, Craft synthesis-timing builder, and auto-translate skeleton writes continue to emit line-only cues in this slice (they MUST NOT start requiring nested data).
- **Cloud / worker payloads**: Extra unknown fields on a cue continue to be ignored; new optional nested fields MUST be omitted when empty so older readers that only understand line fields still see a normal cue.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every transcript cue MUST continue to have line text, line start, and line duration as required fields with the same meaning as today.
- **FR-002**: A cue MUST allow an optional ordered list of **word spans** (`timeline`). Each word span has text and MAY have start time and duration (milliseconds relative to the parent line).
- **FR-003**: A word span MUST allow an optional ordered list of **phone spans** (`phones`). Each phone span has a pronunciation label (`phone` / `text`) and MAY have `startTime` / `endTime` in seconds (`PhoneTiming`).
- **FR-004**: Nested fields MUST be additive. The product MUST NOT remove, rename, or require any existing cue field (including the optional line fingerprint used for translation overlays).
- **FR-005**: Saving and loading a cue MUST round-trip nested word and phone spans when they are present, without changing line text, line start, or line duration.
- **FR-006**: Saving and loading a cue that has no nested spans MUST remain valid and MUST NOT invent nested spans.
- **FR-007**: Existing transcript producers (caption import, YouTube captions, speech-to-text line grouping, Craft synthesis-timing transcripts, auto-translate overlays) MUST keep writing line-only cues in this slice.
- **FR-008**: Existing transcript consumers (panel render, current-line tracking, tap-to-seek line, echo region, blur practice, dictionary lookup, auto-translate identity) MUST keep using line text and line times. They MUST NOT require nested spans and MUST NOT change behavior when nested spans are present.
- **FR-009**: This slice MUST NOT introduce karaoke highlighting, IPA overlay, per-word tap targets, or a new learner-facing setting.
- **FR-010**: Unreadable or incomplete nested data MUST degrade to line-only behavior for that cue; the rest of the transcript MUST still load.
- **FR-011**: Nested word times, when present, use milliseconds relative to the parent line (`start` / `duration`). Nested phone times use seconds (`startTime` / `endTime`). Neither replaces line times in this slice.
- **FR-012**: Existing stored transcripts MUST load without a required data-structure migration of historical rows. Old cues that omit nested fields remain first-class.
- **FR-013**: Cue identity used for current line, echo membership, blur, and translation fingerprinting MUST stay based on line-level fields so adding nested spans does not treat the cue as a different line.

### Key Entities

- **Transcript cue (line)**: One timed block of transcript text with required start and duration on the media timeline. Optionally carries word spans. This is what learners see and what playback tracks today.
- **Word span**: An ordered substring of a cue, with optional start/duration (ms relative to the parent line) and optional phone spans. Absent on today’s cues.
- **Phone span**: An ordered pronunciation unit under a word (`PhoneTiming`: `phone`, `text`, `startTime`/`endTime` in seconds). Absent on today’s cues.
- **Line-only cue**: A cue with no nested word/phone data. The only shape existing sources write in this slice.
- **Nested cue**: A cue that also has word and/or phone spans. Valid to store; inert in the UI in this slice.
- **Line identity**: The combination of line text and line times (and the existing translation fingerprint when present) used by current-line, echo, blur, and auto-translate. Independent of nested spans.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a curated regression set of at least 10 existing transcripts covering import, YouTube captions, speech-to-text, and Craft synthesis lines, 100% of cues keep the same line text, order, start, and duration after this slice ships (compare to the pre-feature build).
- **SC-002**: In the same regression set, tap-to-seek, current-line tracking, echo region membership, dictionary lookup, and auto-translate each complete without new errors or changed line identity (0 functional regressions in that checklist).
- **SC-003**: A nested cue with at least 3 words and at least 1 word that has phone spans round-trips through save and load with 100% of nested fields preserved and with line text/start/duration unchanged.
- **SC-004**: A line-only cue round-trips without gaining nested spans (0 invented words or phones).
- **SC-005**: Loading a transcript that mixes line-only cues, nested cues, empty nested lists, and incomplete nested times still shows every cue’s line text; 0 cues disappear or fail the whole track.
- **SC-006**: Learners notice no new transcript controls or layout in this slice: side-by-side with the pre-feature build, the panel is visually unchanged for line-only library items (no new buttons, toggles, or per-word chrome).

## Assumptions

- Product shape for nested data is **line → word → phone**, matching enjoy web `TranscriptLine.timeline` / `TranscriptWord.phones`. A fully recursive unlimited tree is not required for this slice; later alignment output can be adapted into this shape.
- Word times use milliseconds relative to the parent line. Phone times use seconds (`PhoneTiming`). Line start/duration stay milliseconds on the media timeline.
- Pronunciation spelling on words/phones is optional storage only; this slice does not generate or display IPA.
- No Settings toggle in this slice. The first consumer slice (Craft enrichment or karaoke) will introduce `transcript.timelineEnrichment` (default off) as specified in issue #540.
- Existing Craft line-building from synthesis word timings ([spec 030](../030-craft-tts-transcript/spec.md)) does not change here. Deprecating those timings as a *timeline source* belongs to slice 3.
- Speech-to-text already has per-word timings internally in some paths; **preserving** those onto word spans is a later slice, not this one.
- YouTube WebView items remain caption-only; this slice does not add word timings for them.
- Issue #527 may later display IPA from word/phone fields; this slice only makes those fields possible.
- Shipping this slice with no new learner-facing behavior is acceptable and intended: the value is a safe substrate for slices 2–5.

## Dependencies

- Relies on the existing stored transcript cue list (opaque per-track timeline already used for imports and playback).
- Does not depend on the alignment engine (slice 2) or Craft enrichment (slice 3).
- Must stay compatible with auto-translate line fingerprinting ([ADR-0039](../../docs/decisions/0039-auto-translate-primary-text-keyed-overlay.md)) and existing transcript panel behavior documented in [docs/features/transcript.md](../../docs/features/transcript.md).
