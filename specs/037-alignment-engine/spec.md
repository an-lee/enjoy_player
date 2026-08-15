# Feature Specification: Alignment Engine

**Feature Branch**: `037-alignment-engine`

**Created**: 2026-08-15

**Status**: Draft

**Input**: User description: "Let's continue to work on the follow-up spec."

**Source**: [GitHub issue #540](https://github.com/baizhiheizi/enjoy_player/issues/540) (on-device transcript timeline enrichment). This specification is **slice 2** of that program. Slice 1 ([036-transcript-nested-timeline](../036-transcript-nested-timeline/spec.md)) already lets a stored cue hold optional word and phone spans. This slice **produces** those timings from known text and extractable audio. It does **not** save them onto Craft items or show them in the transcript panel.

## Program split (issue #540)

Each slice MUST be independently shippable: existing transcript, playback, Craft, import, speech-to-text, YouTube captions, echo, lookup, and translation behavior stay intact unless that slice’s opt-in path is explicitly on.

| Slice | Spec | What ships | Why it does not break existing features |
|-------|------|------------|----------------------------------------|
| **1** | [Nested transcript timeline](../036-transcript-nested-timeline/spec.md) | A cue MAY carry optional word/phone spans. No new UI. | Additive storage. Nested data ignored until a consumer slice. |
| **2 (this spec)** | Alignment engine | A standalone capability: known text + extractable audio → word- and phone-level timings. Not wired into Craft or the transcript panel. | Unused by product flows. Learners see no change. |
| **3** | Craft timeline enrichment | Opt-in: Craft items may store nested timings from this engine. Default remains today’s synthesis-timing transcript. | Off by default. On failure, Craft save and playback match pre-feature behavior. |
| **4** | Karaoke word highlight | Opt-in word highlight while media plays, when the cue has word timings. | Off by default; inactive on line-only cues. |
| **5** | Word-level practice | Opt-in later: tap/loop/inspect a word. | No nested data → today’s line-level interactions. |
| **Related** | IPA overlay ([#527](https://github.com/baizhiheizi/enjoy_player/issues/527)) | Display pronunciation spelling per word. | Own toggle and own spec. |

**Out of the #540 program (all slices):** aligning YouTube WebView playback (no extractable audio), aligning the learner’s own shadow-reading recording, replacing Craft’s high-quality playback audio with a synthetic reference voice, real-time/streaming alignment, and cross-language alignment (audio in one language, transcript in another).

## Scope (this slice only)

### In scope

- Offer a **callable alignment capability** that, given known transcript text, extractable audio for that text, and a language, returns ordered **word timings** and, at the default quality, ordered **phone timings** with pronunciation labels.
- Support two calling patterns: **whole clip** (plain text + one audio file, typical short Craft item) and **per cue** (existing line text + that line’s time window on longer local audio).
- Guarantee that **no product flow calls this capability yet**: Craft still builds transcripts from today’s synthesis timings; the transcript panel, echo, lookup, auto-translate, import, YouTube captions, and speech-to-text stay unchanged.
- Guarantee failures, cancellation, unsupported language, and missing audio **cannot** change saved transcripts or what learners see.
- Keep results **mappable** onto the nested cue already defined in slice 1 / enjoy web (word spans on the line, phone spans on the word). Mapping into stored Craft/library rows is slice 3.

### Out of scope (this slice)

- Craft save/play pipeline changes, including replacing synthesis word-boundary transcripts.
- Transcript panel karaoke, IPA overlay, per-word tap, or any new Settings toggle (`transcript.timelineEnrichment` lands with the first consumer).
- YouTube WebView items (no extractable audio).
- Aligning the learner’s shadow-reading recording against a reference.
- Streaming / live alignment while audio is still being spoken or synthesized.
- Cross-language alignment.
- Replacing high-quality Craft playback audio with a synthetic reference voice.
- IPA as a standalone “pronounce this word” API ([#527](https://github.com/baizhiheizi/enjoy_player/issues/527) remains separate).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Existing library and Craft behavior is unchanged (Priority: P1)

A learner opens the same imported captions, YouTube captions, speech-to-text track, or Craft item they used before this change. Lines, times, tap-to-seek, current-line tracking, echo, lookup, and translation behave as they did. Craft still saves and plays with today’s transcript. Nothing new appears in Settings.

**Why this priority**: Slice 2 is only valuable if it can ship without regressing practice. The engine must exist without becoming a silent side effect on save or playback.

**Independent Test**: Open the same curated library set used for slice 1 (import, YouTube captions, speech-to-text, Craft with synthesis transcript). Confirm line text, order, times, and interactions match the pre-feature build. Confirm Craft save still produces line-only cues.

**Acceptance Scenarios**:

1. **Given** a library item whose transcript was created before this slice, **When** the learner opens and plays it, **Then** visible lines, start times, tap-to-seek, current-line, echo, lookup, and auto-translate match the pre-feature record.
2. **Given** a Craft item saved with today’s synthesis-timing transcript, **When** the learner saves or re-opens it after this slice, **Then** the stored cues remain line-only (no new word/phone spans invented by this engine).
3. **Given** Settings, **When** the learner looks for a new transcript-enrichment control, **Then** none is present in this slice.
4. **Given** YouTube WebView playback, **When** the item opens, **Then** captions and playback behave as today (this engine is not invoked).

---

### User Story 2 - Known text and extractable audio can be aligned (Priority: P1)

A later feature (or a developer test) can hand the engine known transcript text, extractable audio for that text, and a language, and receive an ordered list of word timings on that audio. At default quality, each word can also carry ordered phone timings with pronunciation labels. Times are on the **source audio** timeline. The known text is not rewritten.

**Why this priority**: Slice 3 cannot enrich Craft (or later karaoke) unless this result exists and is stable. This is the entire user-visible “capability” of slice 2, even though learners do not see a new control.

**Independent Test**: Run the engine on a short known clip (for example a few seconds of speech whose text is known) in at least English, and confirm every expected word appears in order with start/end on the audio, and that phones are present at default quality.

**Acceptance Scenarios**:

1. **Given** extractable audio and matching transcript text in a supported language, **When** whole-clip alignment runs at default quality, **Then** the result contains one word timing per recognized word, in transcript order, each with start and end on the source audio.
2. **Given** that same run, **When** default quality is used, **Then** phone timings with pronunciation labels are present and each phone is associated with a parent word (not left as an unordered bag).
3. **Given** a successful result, **When** a later slice maps it onto stored cues, **Then** word and phone fields match the meaning already defined in slice 1 (words relative to a parent line; phones as pronunciation + seconds).
4. **Given** the same audio, text, language, and quality, **When** alignment is run twice, **Then** word order and counts match; start times differ by at most a small documented tolerance (not a different transcript).

---

### User Story 3 - Existing cue windows align locally, not as one giant file (Priority: P1)

When the caller already has line cues (text + start + end on the media), the engine can align **each cue’s audio fragment and text** and return word/phone timings that belong inside that cue’s window (plus a documented small pad). Long local media MUST NOT require one whole-file alignment of the entire recording.

**Why this priority**: Issue #540’s preferred path for ASR/SRT enrichment is per-line. Whole-file alignment of multi-minute media is too costly and less stable. Craft-length clips without cue windows may still use whole-clip alignment.

**Independent Test**: Feed a short clip that already has two or more line windows. Confirm each line is aligned from its own fragment, word times fall inside that line’s window (plus pad), and a multi-minute fixture is rejected or segmented rather than aligned as one whole-file high-quality job.

**Acceptance Scenarios**:

1. **Given** extractable audio and an ordered list of line cues with text and time windows, **When** per-cue alignment runs, **Then** each cue yields its own word (and default-quality phone) timings without requiring the caller to align the entire file as one job.
2. **Given** a cue window, **When** that cue’s words are returned, **Then** those word times lie inside the cue window except for a documented small pad; they MUST NOT replace the cue’s own line start/duration.
3. **Given** a long local recording (several minutes) with existing line cues, **When** alignment is requested, **Then** the engine uses per-cue jobs rather than one whole-file high-quality pass over the entire recording.
4. **Given** a short clip that is only plain text + audio (no cue windows), **When** alignment is requested, **Then** whole-clip alignment is allowed.

---

### User Story 4 - Alignment can fail or be cancelled without harming the product (Priority: P1)

Callers get a clear failure when audio is missing, too short, text is blank, language is unsupported, the user/canceller aborts, or alignment cannot finish in a reasonable time. The app does not crash, does not rewrite transcripts, and remains usable.

**Why this priority**: Slice 3 will rely on fallback. Slice 2 must make failure a first-class result, not an exception that leaks into UI.

**Independent Test**: Drive each failure class (no audio, blank text, unsupported language, cancel, timeout) and confirm a structured failure, no saved-transcript mutation, and that the rest of the app can continue.

**Acceptance Scenarios**:

1. **Given** YouTube WebView or any source without extractable audio, **When** a caller asks to align, **Then** the engine reports that audio is unavailable; no crash; no transcript rewrite.
2. **Given** blank text, empty audio, or audio shorter than a documented minimum, **When** alignment runs, **Then** it fails clearly without inventing word timings.
3. **Given** a language the engine cannot align, **When** alignment runs, **Then** it fails as unsupported language; it MUST NOT silently return timings for a different language.
4. **Given** an in-flight alignment, **When** the caller cancels or a timeout elapses, **Then** work stops, the failure is “cancelled” or “timed out,” and the rest of the app stays responsive.
5. **Given** any of the failures above, **When** the learner is using the library/player, **Then** they see no new error chrome from this slice (no product flow is calling the engine yet).

---

### Edge Cases

- **Omitted vs empty result lists**: A failure MUST NOT look like a successful empty word list. Success with zero words is only valid when the transcript has no alignable words (for example punctuation-only); that case MUST be documented.
- **Text/audio mismatch**: If the known text is clearly not what is in the audio, the engine may still return a best-effort timeline; it MUST NOT rewrite the caller’s transcript text. Later slices decide whether to keep or discard that result.
- **Times outside a parent cue**: Per-cue alignment may produce a word slightly past the cue edge; this slice documents a pad. It MUST NOT change the cue’s line start/duration.
- **Partial phones**: A word without phones is valid (coarse quality). Phones without a parent word are not valid.
- **Very short cues**: A cue shorter than the documented minimum MAY fail that cue only; other cues in a per-cue batch still complete.
- **Very long whole-clip request**: Whole-clip alignment of multi-minute audio at fine quality MUST be refused or redirected to per-cue; it MUST NOT run unbounded.
- **Repeated punctuation / CJK**: Word splitting follows the engine’s language rules; empty “words” are omitted. Line text from the caller remains the source of truth for display in later slices.
- **Concurrent calls**: Two alignments MAY run only if they do not freeze the app; this slice does not require a global queue, but it MUST NOT block playback UI.
- **Determinism**: Same inputs → same word count and order; timestamps may jitter within the published tolerance.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The product MUST provide a standalone alignment capability that is **not invoked** by Craft save, transcript render, playback, echo, lookup, auto-translate, import, YouTube captions, or speech-to-text in this slice.
- **FR-002**: Alignment MUST accept known transcript text, extractable source audio for that text, and a language tag. It MUST NOT require a network round-trip or extra learner credits.
- **FR-003**: Whole-clip alignment MUST return ordered word timings (`text`, start, end) on the source-audio timeline, without changing the caller’s transcript string.
- **FR-004**: At default quality, alignment MUST also return ordered phone timings with a pronunciation label, start, end, and a parent-word association. Coarse quality MAY omit phones.
- **FR-005**: When the caller supplies existing cue windows (text + start + end), alignment MUST support per-cue jobs: each cue is aligned from its own audio fragment and text. Word times MUST NOT replace that cue’s line start/duration.
- **FR-006**: Whole-clip alignment is for short text+audio without cue windows. Multi-minute media with cue windows MUST use per-cue alignment, not one whole-file fine-quality pass.
- **FR-007**: Word and phone timings MUST be expressible in the same meaning as slice 1 / enjoy web nested cues (words as spans under a line; phones as pronunciation units under a word, seconds on the audio). This slice does not persist them onto library/Craft rows.
- **FR-008**: Alignment MUST be cancellable and MUST NOT freeze playback or other learner-facing UI while it runs.
- **FR-009**: Missing extractable audio, blank text, too-short audio, unsupported language, cancel, and timeout MUST each produce a distinct, non-crash failure. Failures MUST NOT write transcript rows.
- **FR-010**: YouTube WebView items MUST be treated as “audio unavailable” if someone calls the engine; this slice MUST NOT add a download/demux path for YouTube.
- **FR-011**: This slice MUST NOT add karaoke, IPA overlay, per-word taps, Craft pipeline changes, or a learner Settings toggle.
- **FR-012**: Supported languages MUST include the app’s current focus learning languages for which extractable Craft/local audio exists. A language the engine cannot handle MUST fail as unsupported, not as a generic crash.
- **FR-013**: Default quality MUST include phones. A coarser quality that returns words only MUST be available for faster/cheaper runs.

### Key Entities

- **Alignment request**: Known text, extractable source audio, language, quality (coarse vs default/fine), optional existing cue windows, optional cancellation.
- **Word timing**: One recognized word from the known text, with start and end on the source audio.
- **Phone timing**: One pronunciation unit under a word, with label, start, end, and parent-word association.
- **Alignment success**: Ordered word timings; phones present at default quality; echo of language and audio duration.
- **Alignment failure**: A typed reason (audio unavailable, too short, blank text, unsupported language, cancelled, timed out, internal). Not a rewritten transcript.
- **Cue window**: Existing line text plus start/end on the media, used only for per-cue alignment.
- **Extractable audio**: Local or Craft audio/video from which a single-channel practice-rate pulse-code sample can be taken. YouTube WebView playback is not extractable.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the same curated regression set as slice 1 (at least 10 existing transcripts: import, YouTube captions, speech-to-text, Craft synthesis), 100% of cues keep the same line text, order, start, and duration; 0 Craft saves gain nested spans from this engine.
- **SC-002**: Learners notice no new Settings row and no new transcript chrome in this slice (side-by-side with the pre-feature build).
- **SC-003**: On a short known-text fixture (at least 2 words) in English, 100% of expected words appear in order; each word start is within **50 ms** of the engine’s own reference timeline for that fixture.
- **SC-004**: On that same default-quality run, at least one word has a non-empty phone list; every phone names a parent word index that exists.
- **SC-005**: Given at least 2 cue windows on a short clip, per-cue alignment returns words for each cue whose times fall inside that cue’s window except for a pad of at most **50 ms**; 0 cues have their line start/duration rewritten.
- **SC-006**: A whole-clip request for multi-minute audio at fine quality is refused or converted to per-cue; 0 unbounded whole-file fine-quality jobs run in tests.
- **SC-007**: Each failure class in US4 is reproducible: 100% return a typed failure, 0 crashes, 0 transcript-row writes.
- **SC-008**: While a typical practice clip (about **60 s** or less) is aligning, the rest of the app remains usable (playback/transport still responds). Alignment of that clip completes in time a later first-play consumer could wait (**under 10 s** on a current mid-range device, documented if slower on a given platform).

## Assumptions

- This slice ships a **capability**, not a learner feature. Shipping with no new UI is intended.
- Alignment is **same-language**: audio language matches transcript language. Cross-language is out of program.
- The engine may use a richer internal timeline than the stored cue. Slice 3 (and later karaoke/IPA) maps engine output onto slice 1’s nested cue JSON. This slice only requires that mapping to be possible without a second stored shape.
- Default quality corresponds to “words + phones” (enjoy web `medium`). Coarse quality is words only (`low`). A finer quality may exist for tests; it is not required of product flows yet.
- Per-cue alignment is preferred whenever cue windows already exist (imported captions, ASR lines). Whole-clip is for short Craft-like “plain text + one audio file” inputs.
- Minimum audio length is on the order of **one second** of extractable audio; shorter input fails as too short.
- Timeout for a single 60 s whole-clip job is on the order of **two minutes**; callers may cancel sooner.
- Word-start tolerance of **±50 ms** vs the engine’s reference (and vs a later Echogarden cross-check in the plan) is the accuracy bar. Bit-identical timestamps are not required.
- Focus learning languages in the current catalog are the v1 language bar. Additional eSpeak-capable languages may work but are not success criteria.
- No Settings toggle in this slice. Slice 3 introduces `transcript.timelineEnrichment` (default off) before any product flow calls the engine.
- Slice 1 nested storage is a dependency. This slice does not change cue identity rules (`cueIdFor`, auto-translate fingerprint).
- Offline/on-device is required so alignment does not spend credits and works without a network. Exact native synthesis/DSP choices belong in the plan, not this spec.
- Deprecating synthesis word-boundary events as a *stored timeline source* is slice 3, not this slice. Those events remain valid for today’s Craft line building ([spec 030](../030-craft-tts-transcript/spec.md)).

## Dependencies

- Relies on slice 1 nested cue meaning ([036](../036-transcript-nested-timeline/spec.md), [ADR-0070](../../docs/decisions/0070-nested-transcript-timeline.md)) so later mapping has a home.
- Relies on existing extractable-audio paths for **local** and **Craft** files. Does not rely on YouTube WebView PCM.
- Does not depend on slice 3 Craft enrichment, slice 4 karaoke, slice 5 word practice, or [#527](https://github.com/baizhiheizi/enjoy_player/issues/527) IPA overlay.
- Must not change auto-translate fingerprinting or transcript panel behavior documented in [docs/features/transcript.md](../../docs/features/transcript.md).
