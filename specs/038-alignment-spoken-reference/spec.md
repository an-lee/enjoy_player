# Feature Specification: Spoken Alignment Reference

**Feature Branch**: `038-alignment-spoken-reference`

**Created**: 2026-08-16

**Status**: Draft

**Input**: User description: "Let's continue to implement the follow-up spec"

**Source**: [GitHub issue #540](https://github.com/baizhiheizi/enjoy_player/issues/540). This specification is **slice 2b** of that program. Slice 2 ([037-alignment-engine](../037-alignment-engine/spec.md)) already offers a callable aligner (known text + extractable audio → word/phone timings) that product flows do not call. That slice can produce a timeline without comparing the clip to a **spoken** rendering of the same text. This slice upgrades that missing step so later Craft enrichment can trust the times. It still does **not** save timings onto Craft items or show them in the transcript panel.

## Program split (issue #540)

Each slice MUST be independently shippable: existing transcript, playback, Craft, import, speech-to-text, YouTube captions, echo, lookup, and translation behavior stay intact unless that slice’s opt-in path is explicitly on.

| Slice | Spec | What ships | Why it does not break existing features |
|-------|------|------------|----------------------------------------|
| **1** | [Nested transcript timeline](../036-transcript-nested-timeline/spec.md) | A cue MAY carry optional word/phone spans. No new UI. | Additive storage. Nested data ignored until a consumer slice. |
| **2** | [Alignment engine](../037-alignment-engine/spec.md) | Standalone capability: known text + extractable audio → word/phone timings. Not wired into Craft or the panel. | Unused by product flows. |
| **2b (this spec)** | Spoken alignment reference | The engine compares the clip to a same-language **spoken** rendering of the known text, including pronunciation events. Still unused by product. | Unused. Learners see no change. |
| **3** | Craft timeline enrichment | Opt-in: Craft items may store nested timings from this engine. Default remains today’s synthesis-timing transcript. | Off by default. On failure, Craft save and playback match pre-feature behavior. |
| **4** | Karaoke word highlight | Opt-in word highlight while media plays, when the cue has word timings. | Off by default; inactive on line-only cues. |
| **5** | Word-level practice | Opt-in later: tap/loop/inspect a word. | No nested data → today’s line-level interactions. |
| **Related** | IPA overlay ([#527](https://github.com/baizhiheizi/enjoy_player/issues/527)) | Display pronunciation spelling per word. | Own toggle and own spec. |

**Out of the #540 program (all slices):** aligning YouTube WebView playback (no extractable audio), aligning the learner’s own shadow-reading recording, replacing Craft’s high-quality playback audio with a synthetic reference voice, real-time/streaming alignment, and cross-language alignment (audio in one language, transcript in another).

## Scope (this slice only)

### In scope

- Require production alignment to use a **spoken reference** of the caller’s known text in the same language: a voice rendering plus pronunciation events (word and, at default quality, phone).
- Compare that spoken reference to the extractable **source** audio so returned word/phone times sit on the source timeline (same public result meaning as slice 2).
- Fail with a distinct, non-crash reason when a spoken reference cannot be produced (missing voice for the language, synthesizer unavailable on the device). Do **not** treat a non-speech stand-in (evenly stretched tones or letter-by-letter “phones”) as a successful production result.
- Keep the engine **unused** by Craft, the transcript panel, playback, echo, lookup, auto-translate, import, YouTube captions, and speech-to-text. No new Settings toggle.
- Keep whole-clip and per-cue calling patterns, caps, cancel, and timeout from slice 2.

### Out of scope (this slice)

- Craft save/play pipeline changes (slice 3).
- Transcript panel karaoke, IPA overlay, per-word tap, or `transcript.timelineEnrichment`.
- Playing the spoken reference to the learner, or replacing Craft/library playback audio with that reference voice.
- YouTube WebView demux, learner-recording alignment, streaming alignment, cross-language alignment.
- IPA as a standalone “pronounce this word” API ([#527](https://github.com/baizhiheizi/enjoy_player/issues/527)).
- Changing cue identity (`cueIdFor`, auto-translate fingerprint) or writing `timeline_json`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Existing library and Craft behavior is unchanged (Priority: P1)

A learner opens the same imported captions, YouTube captions, speech-to-text track, or Craft item they used before this change. Lines, times, and interactions match the pre-feature build. Nothing new appears in Settings. They never hear a synthetic reference voice instead of their media.

**Why this priority**: Slice 2b only upgrades an unused engine. It must not become a silent side effect on save, playback, or Settings.

**Independent Test**: Same curated library set as slices 1–2 (import, YouTube captions, speech-to-text, Craft). Confirm line text, order, times, and interactions. Confirm Craft save still produces line-only cues. Confirm no new Settings row.

**Acceptance Scenarios**:

1. **Given** a library item whose transcript was created before this slice, **When** the learner opens and plays it, **Then** visible lines, start times, tap-to-seek, current-line, echo, lookup, and auto-translate match the pre-feature record.
2. **Given** a Craft item saved with today’s synthesis-timing transcript, **When** the learner saves or re-opens it after this slice, **Then** stored cues remain line-only (this engine still does not write nested spans).
3. **Given** Settings, **When** the learner looks for a transcript-enrichment or “reference voice” control, **Then** none is present in this slice.
4. **Given** Craft or library playback, **When** the item plays, **Then** the learner hears the existing high-quality audio, not a spoken-reference rendering.

---

### User Story 2 - Alignment compares the clip to a spoken rendering of the same text (Priority: P1)

A later feature (or a developer test) can hand the engine known text, extractable audio, and a language, and receive word timings (and default-quality phones) that were produced by lining the clip up with a **spoken** rendering of that text—not by stretching words evenly across the clip or inventing letter-sized phones.

**Why this priority**: Slice 3 cannot enrich Craft from a stand-in timeline. This is the quality bar slice 2 left open.

**Independent Test**: Run whole-clip alignment on a short **spoken** English fixture whose text is known (at least two words). Confirm every expected word appears in order on the source timeline, each start is within the published tolerance of the spoken reference’s own word events, and default quality includes phones that are real pronunciation units (not one letter per character for a word like “hello”).

**Acceptance Scenarios**:

1. **Given** extractable speech audio and matching transcript text in a supported language, **When** whole-clip alignment runs at default quality, **Then** the result contains one word timing per recognized word, in transcript order, on the source-audio timeline.
2. **Given** that same run, **When** word starts are compared to the spoken reference’s own word events for that text, **Then** each word start differs by at most the published tolerance (50 ms).
3. **Given** default quality, **When** phones are returned, **Then** at least one word has a non-empty phone list, every phone names a parent word that exists, and those labels are pronunciation units from the spoken reference—not a letter-split of the spelling.
4. **Given** the same audio, text, language, and quality, **When** alignment is run twice, **Then** word order and counts match; start times stay within the published tolerance.
5. **Given** a successful result, **When** a later slice maps it onto stored cues, **Then** word and phone fields keep the slice 1 / enjoy-web meaning (words relative to a parent line; phones as pronunciation + seconds).

---

### User Story 3 - Missing spoken reference fails; it does not silently succeed (Priority: P1)

If the engine cannot produce a spoken reference (no voice for the language, synthesizer unavailable on this device), the caller gets a distinct failure. The engine MUST NOT return a successful timeline built only from even time-splits or non-speech stand-in audio.

**Why this priority**: Slice 3 will fall back to today’s Craft transcript. A fake “success” would write bad word times and look like enrichment worked.

**Independent Test**: Drive “spoken reference unavailable” (for example a test harness that disables the spoken voice) and an unsupported language. Confirm a typed failure, no empty-success disguise, and no transcript-row writes.

**Acceptance Scenarios**:

1. **Given** a supported language but no spoken reference can be produced on this run, **When** alignment is requested, **Then** the result is a distinct failure (not “internal” only, and not a successful word list).
2. **Given** that failure, **When** a later consumer would have written nested spans, **Then** this slice has written 0 transcript rows (still no product caller; pin the engine itself).
3. **Given** a language with no spoken-reference voice, **When** alignment runs, **Then** it fails as unsupported language or as spoken-reference unavailable; it MUST NOT silently return timings as if another language’s voice was used.
4. **Given** any of these failures, **When** the learner is using the library/player, **Then** they see no new error chrome (no product flow calls the engine yet).

---

### User Story 4 - Per-cue jobs and safety caps still hold (Priority: P1)

Callers can still align each existing cue window locally. Whole-clip jobs still refuse multi-minute audio. Cancel and timeout still stop work. The spoken reference is built **per job** (whole clip or one cue’s text), not by speaking an entire multi-minute file as one utterance when cue windows exist.

**Why this priority**: Spoken reference must not undo slice 2’s cost and safety rules.

**Independent Test**: Two cue windows on a short spoken clip: each cue’s words fall inside that window plus the published pad. A whole-clip request longer than the published cap is refused. Cancel and timeout still return typed failures.

**Acceptance Scenarios**:

1. **Given** extractable audio and at least two line cues with text and time windows, **When** per-cue alignment runs, **Then** each successful cue has word times inside its window except for the published pad; line start/duration are not rewritten.
2. **Given** a whole-clip request longer than the published maximum, **When** alignment is requested, **Then** it is refused; it is not one unbounded spoken-reference + align pass over the entire file.
3. **Given** an in-flight alignment, **When** the caller cancels or a timeout elapses, **Then** work stops with “cancelled” or “timed out,” including any in-flight spoken-reference work.
4. **Given** blank text, missing audio, or audio shorter than the published minimum, **When** alignment runs, **Then** it still fails as in slice 2 (no spoken reference is required to classify those).

---

### Edge Cases

- **Stand-in vs production**: Automated tests MAY use a double for the spoken voice. A production success MUST come from a spoken reference. A non-speech stand-in MUST NOT be reported as success when this slice is the production path.
- **Reference length ≠ clip length**: The spoken rendering may be shorter or longer than the source audio. Times MUST still be returned on the **source** timeline; the caller’s transcript string is not rewritten.
- **Text/audio mismatch**: Best-effort timeline is allowed; do not rewrite the caller’s text.
- **Punctuation-only text**: Success with zero words remains valid; no spoken reference of empty wording is required.
- **Partial phones**: Coarse quality may omit phones. Phones without a parent word are invalid.
- **Platform without a voice**: Distinct failure (US3). Do not crash the app. Quality goldens MAY skip on a runner that cannot produce a spoken reference; failure-when-unavailable tests MUST still run.
- **Learner never hears the reference**: The spoken rendering is an internal alignment input only.
- **Determinism**: Same inputs → same word count and order; timestamps may jitter within the published tolerance.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The product MUST keep the alignment capability **uninvoked** by Craft save, transcript render, playback, echo, lookup, auto-translate, import, YouTube captions, and speech-to-text in this slice.
- **FR-002**: Production alignment MUST build a same-language **spoken reference** of the caller’s known text (voice rendering + pronunciation events) and compare it to the extractable source audio. It MUST NOT require a network round-trip or extra learner credits.
- **FR-003**: Successful word and phone timings MUST lie on the source-audio timeline and MUST NOT change the caller’s transcript string.
- **FR-004**: At default quality, phones MUST come from the spoken reference’s pronunciation events and MUST name a parent word. Coarse quality MAY omit phones. Letter-splitting the spelling MUST NOT be the production phone source.
- **FR-005**: Evenly stretching words across the clip, or comparing the clip only to non-speech stand-in audio, MUST NOT be reported as a production success.
- **FR-006**: If a spoken reference cannot be produced, alignment MUST return a distinct typed failure. That failure MUST NOT be encoded as an empty successful word list.
- **FR-007**: Per-cue and whole-clip calling patterns, minimum audio length, whole-clip maximum duration, cue-window pad, cancel, and timeout MUST remain as specified in slice 2.
- **FR-008**: The spoken reference MUST NOT be played to the learner and MUST NOT replace Craft or library playback audio.
- **FR-009**: Failures MUST NOT write transcript rows. YouTube WebView remains “audio unavailable”; this slice MUST NOT add a YouTube download/demux path.
- **FR-010**: This slice MUST NOT add karaoke, IPA overlay, per-word taps, Craft pipeline changes, or a learner Settings toggle.
- **FR-011**: Supported languages remain the app’s current focus learning languages. A language with no spoken-reference voice MUST fail without silently swapping language.
- **FR-012**: Word and phone timings MUST stay mappable onto slice 1 / enjoy-web nested cues. This slice does not persist them onto library/Craft rows.

### Key Entities

- **Spoken reference**: An on-device voice rendering of the known text in the request language, plus pronunciation events (word, and phones at default quality). Internal only; never the learner’s playback audio.
- **Spoken-reference failure**: A typed reason that the voice rendering or its events could not be produced. Distinct from blank text, too-short audio, cancel, and timeout.
- **Alignment request / success / failure, word timing, phone timing, cue window, extractable audio**: Same meaning as [slice 2](../037-alignment-engine/spec.md).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the same curated regression set as slices 1–2 (at least 10 existing transcripts: import, YouTube captions, speech-to-text, Craft synthesis), 100% of cues keep the same line text, order, start, and duration; 0 Craft saves gain nested spans from this engine; 0 playback substitutions of a reference voice.
- **SC-002**: Learners notice no new Settings row and no new transcript chrome (side-by-side with the pre-feature build).
- **SC-003**: On a short **spoken** English fixture (at least 2 words) whose text is known, 100% of expected words appear in order; each word start is within **50 ms** of the spoken reference’s own word events for that text.
- **SC-004**: On that same default-quality run, at least one word has a non-empty phone list; every phone names a parent word index that exists; those phones are not a one-letter-per-character split of “hello”.
- **SC-005**: When the spoken reference is forced unavailable in a test harness, 100% of alignment attempts return a typed spoken-reference (or unsupported-language) failure; 0 successful word lists from a non-speech stand-in.
- **SC-006**: Given at least 2 cue windows on a short spoken clip, per-cue word times fall inside each cue window except for a pad of at most **50 ms**; 0 cues have line start/duration rewritten.
- **SC-007**: A whole-clip request for multi-minute audio is still refused; cancel and timeout still yield typed failures; 0 transcript-row writes.
- **SC-008**: While a typical practice clip (about **60 s** or less) is aligning—including building the spoken reference—the rest of the app remains usable. Alignment of that clip still completes in time a later first-play consumer could wait (**under 10 s** on a current mid-range device, documented if slower on a given platform).

## Assumptions

- This slice upgrades the **reference step** of the unused engine. Shipping with no new UI is intended.
- Slice 2’s public calling patterns and result meaning stay; this slice changes *how* a success is earned.
- Alignment remains **same-language**. The spoken reference language matches the request language.
- Which on-device speech engine produces the spoken reference belongs in `/speckit-plan`, not this spec.
- Test doubles for the spoken voice are allowed in automated tests. They do not authorize a non-speech stand-in as production success.
- Quality goldens that need a real spoken voice MAY skip when that voice cannot load on a CI runner. The “unavailable → typed failure” contract MUST still be tested on every runner.
- Word-start tolerance remains **±50 ms** vs the spoken reference’s own events (and vs a later Echogarden cross-check in the plan). Bit-identical timestamps are not required.
- Focus learning languages remain the v1 language bar.
- No Settings toggle. Slice 3 still introduces `transcript.timelineEnrichment` (default off) before any product flow calls the engine.
- Slice 1 nested storage and slice 2 caps remain dependencies. Cue identity rules do not change.
- Offline/on-device is required. Extra learner credits are not spent.
- Deprecating synthesis word-boundary events as a stored timeline source remains slice 3.

## Dependencies

- Relies on slice 2’s callable alignment capability ([037](../037-alignment-engine/spec.md)).
- Relies on slice 1 nested cue meaning ([036](../036-transcript-nested-timeline/spec.md), [ADR-0070](../../docs/decisions/0070-nested-transcript-timeline.md)) so later mapping still has a home.
- Relies on existing extractable-audio paths for **local** and **Craft** files. Does not rely on YouTube WebView PCM.
- Does not depend on slice 3 Craft enrichment, slice 4 karaoke, slice 5 word practice, or [#527](https://github.com/baizhiheizi/enjoy_player/issues/527) IPA overlay.
- Must not change auto-translate fingerprinting or transcript panel behavior documented in [docs/features/transcript.md](../../docs/features/transcript.md).
