# Feature Specification: Craft Timeline Enrichment

**Feature Branch**: `039-craft-timeline-enrichment`

**Created**: 2026-08-16

**Status**: Draft

**Input**: User description: "continue to next follow-up spec"

**Source**: [GitHub issue #540](https://github.com/baizhiheizi/enjoy_player/issues/540). This specification is **slice 3** of that program. Slice 1 ([036-transcript-nested-timeline](../036-transcript-nested-timeline/spec.md)) lets a stored cue hold optional word/phone spans. Slices 2 and 2b ([037-alignment-engine](../037-alignment-engine/spec.md), [038-alignment-spoken-reference](../038-alignment-spoken-reference/spec.md)) can produce those timings from known text and extractable audio, comparing the clip to a same-language spoken reference. This slice is the **first product caller**: opt-in Craft save may store those nested timings. It does **not** add karaoke, IPA overlay, or per-word tap.

## Program split (issue #540)

Each slice MUST be independently shippable: existing transcript, playback, Craft, import, speech-to-text, YouTube captions, echo, lookup, and translation behavior stay intact unless that slice’s opt-in path is explicitly on.

| Slice | Spec | What ships | Why it does not break existing features |
|-------|------|------------|----------------------------------------|
| **1** | [Nested transcript timeline](../036-transcript-nested-timeline/spec.md) | A cue MAY carry optional word/phone spans. No new UI. | Additive storage. Nested data ignored until a consumer slice. |
| **2** | [Alignment engine](../037-alignment-engine/spec.md) | Standalone capability: known text + extractable audio → word/phone timings. Not wired into Craft or the panel. | Unused by product flows. |
| **2b** | [Spoken alignment reference](../038-alignment-spoken-reference/spec.md) | Production alignment compares the clip to a same-language spoken rendering. Still unused by product. | Unused. Learners see no change. |
| **3 (this spec)** | Craft timeline enrichment | Opt-in: Craft items may store nested timings from this engine. Default remains today’s synthesis-timing transcript. | Off by default. On failure, Craft save and playback match pre-feature behavior. |
| **4** | Karaoke word highlight | Opt-in word highlight while media plays, when the cue has word timings. | Off by default; inactive on line-only cues. |
| **5** | Word-level practice | Opt-in later: tap/loop/inspect a word. | No nested data → today’s line-level interactions. |
| **Related** | IPA overlay ([#527](https://github.com/baizhiheizi/enjoy_player/issues/527)) | Display pronunciation spelling per word. | Own toggle and own spec. |

**Out of the #540 program (all slices):** aligning YouTube WebView playback (no extractable audio), aligning the learner’s own shadow-reading recording, replacing Craft’s high-quality playback audio with a synthetic reference voice, real-time/streaming alignment, and cross-language alignment (audio in one language, transcript in another).

## Scope (this slice only)

### In scope

- Add one learner-facing **opt-in** setting (default **off**) that allows Craft to store nested word/phone timings from the alignment capability.
- When that setting is **on** and Craft already has a solid synthesis-built line transcript plus extractable audio, run alignment against those **existing line windows** and persist nested spans on those cues. Line text, line start, and line duration stay the [spec 030](../030-craft-tts-transcript/spec.md) synthesis-timing transcript.
- When the setting is **off**, or alignment cannot succeed, Craft save MUST match today’s path: line-only cues from synthesis timings, or a blank transcript when synthesis timings are not solid.
- Keep the transcript panel, playback tracking, echo, lookup, blur, and auto-translate on **line-level** fields. Nested spans are stored; they are not shown as karaoke, IPA, or per-word targets in this slice.
- Keep Craft/library playback as today’s high-quality Craft audio. The spoken reference used for alignment is never what the learner hears.

### Out of scope (this slice)

- Karaoke word highlight (slice 4), per-word tap/loop/inspect (slice 5), IPA overlay ([#527](https://github.com/baizhiheizi/enjoy_player/issues/527)).
- Enriching import, YouTube captions, or speech-to-text tracks. Those producers stay line-only.
- Retroactive background rewrite of the existing library. Already-saved items are unchanged until the learner **re-saves** a Craft item with the setting on.
- First-play or mid-playback alignment that delays opening or seeking an existing item.
- Using alignment to invent a transcript when Craft save would otherwise leave the transcript blank ([spec 030](../030-craft-tts-transcript/spec.md) / no solid synthesis timings).
- Replacing Craft playback audio with a spoken-reference voice.
- YouTube WebView demux, learner-recording alignment, streaming alignment, cross-language alignment.
- Changing cue identity (`cueIdFor`, auto-translate fingerprint) or [spec 030](../030-craft-tts-transcript/spec.md) line-break rules.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Default off: Craft and library behave as today (Priority: P1)

A learner who never turns the new setting on (the shipped default) crafts, saves, and practices exactly as before. Craft still builds line-only cues from synthesis timings when those timings are solid, or leaves the transcript blank when they are not. Imported captions, YouTube captions, and speech-to-text tracks are unchanged. They still hear Craft’s high-quality audio.

**Why this priority**: Slice 3 is only shippable if the default path is byte-for-byte today’s Craft and library experience.

**Independent Test**: Leave the new setting at default. Run the same curated set as slices 1–2b (import, YouTube captions, speech-to-text, Craft with synthesis transcript, Craft with blank transcript). Confirm line text, order, times, interactions, and that new Craft saves stay line-only (or blank per spec 030).

**Acceptance Scenarios**:

1. **Given** the enrichment setting at its default (off), **When** the learner saves a Craft item that has solid synthesis timings, **Then** stored cues are line-only and match today’s synthesis-timing transcript (same wording, line breaks, and line times).
2. **Given** that same default, **When** synthesis cannot produce a solid timed transcript, **Then** Craft still saves playable audio with a blank transcript; the learner can still generate cues later with speech-to-text.
3. **Given** a library item created before this slice, **When** the learner opens and plays it, **Then** visible lines, start times, tap-to-seek, current-line, echo, lookup, and auto-translate match the pre-feature record.
4. **Given** Craft or library playback with the setting off, **When** the item plays, **Then** the learner hears the existing high-quality audio, not a spoken-reference rendering.

---

### User Story 2 - Opt-in Craft save stores nested word and phone timings (Priority: P1)

A learner turns enrichment on, then crafts a short practice item whose synthesis path already produces a solid line transcript. After save and reopen, each line still looks and seeks like today’s cue, but the stored cue now also remembers ordered word spans (and default-quality phone spans) that came from aligning that line’s text to that line’s audio window.

**Why this priority**: This is the entire product value of slice 3: nested timings exist on Craft items so later karaoke/IPA can consume them, without changing what the learner sees yet.

**Independent Test**: Turn the setting on. Craft a short multi-word, multi-line item on a path that already saves a synthesis transcript. Reopen the item. Confirm line text/start/duration match the synthesis-timing transcript, and that stored cues now include word spans in transcript order (and phones at default quality) whose times sit on the source audio / parent line.

**Acceptance Scenarios**:

1. **Given** enrichment is on and Craft has solid synthesis line cues plus extractable audio, **When** the learner saves, **Then** each saved line keeps the same text, start, and duration as the synthesis-timing transcript, and successful lines also store ordered word spans.
2. **Given** that same save at default alignment quality, **When** the transcript is loaded again, **Then** at least one word on a successful line has a non-empty phone list, and every phone names a parent word that exists.
3. **Given** a successful enriched cue, **When** word times are inspected, **Then** they lie inside that cue’s line window except for the published pad (50 ms); line start/duration are not rewritten.
4. **Given** the same practice text, audio, language, and setting, **When** Craft save runs twice, **Then** line order and counts match; nested word counts match; start times stay within the published tolerance.
5. **Given** a Craft item saved with nested spans, **When** the learner opens it in the player, **Then** the panel still shows today’s line-level presentation (no karaoke, IPA, or per-word chips in this slice).

---

### User Story 3 - Alignment failure keeps today’s Craft transcript (Priority: P1)

A learner has enrichment on, but this save cannot produce a spoken-reference alignment (unsupported language, spoken reference unavailable on the device, missing extractable audio, cancel, or timeout). Craft save still succeeds. The stored transcript is the same line-only (or blank) result they would have gotten before this slice. They are not blocked, and they do not get a fake nested timeline.

**Why this priority**: A failed or fake enrichment would either break Craft save or write bad word times that later karaoke would trust.

**Independent Test**: Turn the setting on and drive each failure class (spoken reference unavailable, unsupported language, no extractable audio, timeout). Confirm save completes, the transcript matches the pre-feature Craft result for that path, and no nested spans are invented from a stand-in.

**Acceptance Scenarios**:

1. **Given** enrichment is on but a spoken reference cannot be produced, **When** the learner saves a Craft item that has solid synthesis timings, **Then** save succeeds with the same line-only synthesis-timing transcript as today (no nested spans).
2. **Given** enrichment is on and the language has no alignment voice, **When** the learner saves, **Then** the result is today’s Craft transcript for that path; timings MUST NOT be written as if another language’s voice was used.
3. **Given** enrichment is on and audio is not extractable, **When** the learner saves, **Then** Craft still stores today’s synthesis-timing (or blank) transcript; save is not refused.
4. **Given** enrichment is on and alignment is cancelled or times out, **When** save finishes, **Then** the stored transcript is today’s line-only (or blank) result; the rest of the app stays usable.
5. **Given** any of these fallbacks, **When** the learner is in Craft or the player, **Then** they are not shown a blocking error that prevents save or playback (quiet fallback; no new required error chrome).

---

### User Story 4 - The setting is discoverable, persists, and does not rewrite the library (Priority: P1)

A learner can find the enrichment control under Settings, see that it is off by default, turn it on or off, and have that choice remembered. Turning it on does not rewrite items they already saved. Import, YouTube, and speech-to-text flows never start writing nested spans in this slice. Changing the setting does not require restarting the app.

**Why this priority**: Opt-in is the program’s hard constraint. A hidden or sticky-on toggle, or a silent library rewrite, would break “default remains today’s transcript.”

**Independent Test**: Confirm the Settings row exists, defaults off, and persists across relaunch. With it on, save one new Craft item (enriched or fallback). Confirm pre-existing library items still have their previous cues. Confirm an import / YouTube / speech-to-text save still writes line-only cues.

**Acceptance Scenarios**:

1. **Given** a fresh profile, **When** the learner opens Settings, **Then** they can find a transcript-enrichment control that is **off**.
2. **Given** they turn it on (or off), **When** they leave Settings and return or relaunch the app, **Then** the control still shows their choice; they do not need to restart for the next Craft save to honor it.
3. **Given** enrichment is on, **When** they open a Craft or library item saved before this slice (or saved while the setting was off), **Then** that item’s cues are unchanged until they **re-save** that Craft item.
4. **Given** enrichment is on, **When** they import captions, open YouTube captions, or generate a speech-to-text transcript, **Then** those tracks remain line-only (this slice does not enrich them).

---

### Edge Cases

- **Blank Craft transcript**: If synthesis timings are not solid, Craft still saves audio without a primary timed transcript. This slice MUST NOT invent lines or nested spans from alignment in that case. Speech-to-text remains the way to get cues later.
- **Setting off on re-save**: A re-save with enrichment off writes today’s line-only synthesis transcript (or blank). It MUST NOT invent nested spans. Previously stored nested spans on that item MAY be replaced by the new line-only save (same as any Craft re-save replacing the transcript).
- **Partial cue success**: If some line windows align and others fail, the save MUST still succeed. Successful lines MAY store nested spans; failed lines stay line-only. Line text/start/duration stay the synthesis transcript for every line.
- **Reference length ≠ clip length**: Spoken-reference duration may differ from the Craft audio. Stored word/phone times MUST still sit on the Craft audio / parent-line timeline; practice text is not rewritten.
- **Text/audio mismatch**: Best-effort nested times are allowed; do not replace the learner’s crafted wording.
- **Punctuation-only or empty line**: That line stays valid as today; it does not require a spoken reference.
- **Secondary / translation track**: Alignment enriches the **practice** (primary) Craft transcript only. Translation overlays stay line-level and keep today’s identity rules.
- **Deduped Craft create**: Re-pasting identical text that returns an existing item without a new synthesis MUST NOT silently rewrite that item’s transcript in the background.
- **Long Craft audio with line windows**: Prefer per-line alignment of existing cue windows. Do not run one unbounded whole-file alignment over a multi-minute file.
- **Learner never hears the reference**: The spoken rendering is an internal alignment input only.
- **Incomplete nested data**: Words or phones without times still load; the panel uses line-level fields (slice 1 rules).
- **Malformed nested write**: A failed mapping MUST degrade to line-only for that cue, not fail the whole save.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The product MUST add one learner-facing transcript-enrichment setting, default **off**, persisted with the rest of Settings, and honored on the next Craft save without requiring an app restart.
- **FR-002**: While that setting is off, Craft save, library playback, import, YouTube captions, and speech-to-text MUST match pre-feature behavior (line-only or blank per [spec 030](../030-craft-tts-transcript/spec.md)).
- **FR-003**: While that setting is on, Craft save MUST still build line cues with [spec 030](../030-craft-tts-transcript/spec.md) rules (wording, sentence/phrase breaks, solid-timings-or-blank). Alignment MUST NOT replace that line-building step.
- **FR-004**: While that setting is on and a solid line transcript plus extractable audio exist, Craft save MUST request per-line alignment of those cue windows (known line text + that line’s time window) and, on success, persist nested word spans (and default-quality phone spans) on those cues.
- **FR-005**: Successful nested times MUST lie on the Craft source-audio timeline and MUST be stored in the slice 1 meaning (word start/duration relative to the parent line; phones as pronunciation + seconds). Line text, line start, and line duration MUST NOT change.
- **FR-006**: Synthesis word-boundary events remain valid for **line building**. They MUST NOT be the stored source of nested word/phone spans when enrichment succeeds. A non-speech stand-in MUST NOT be stored as nested success.
- **FR-007**: If alignment cannot succeed (spoken reference unavailable, unsupported language, audio unavailable, too short, cancel, timeout, or mapping failure), Craft save MUST still succeed with today’s synthesis-timing or blank transcript and MUST NOT write a fake nested timeline.
- **FR-008**: A Craft save that would be blank under spec 030 MUST stay blank. Alignment MUST NOT invent a primary transcript.
- **FR-009**: Import, YouTube captions, speech-to-text, auto-translate overlays, echo, lookup, and blur MUST NOT start calling alignment or requiring nested spans in this slice.
- **FR-010**: Already-saved items MUST NOT be rewritten in the background. Enrichment applies to a Craft save (or re-save) while the setting is on.
- **FR-011**: The spoken reference MUST NOT be played to the learner and MUST NOT replace Craft or library playback audio.
- **FR-012**: This slice MUST NOT add karaoke, IPA overlay, or per-word tap/loop/inspect. Nested data remains inert in the transcript panel (slice 1 consumer rules).
- **FR-013**: Cue identity used for current line, echo, blur, and translation fingerprinting MUST stay based on line-level fields.
- **FR-014**: Failures and fallbacks MUST NOT spend extra learner credits and MUST NOT require a network round-trip beyond the Craft synthesis the learner already requested.
- **FR-015**: YouTube WebView remains without extractable audio; this slice MUST NOT add a YouTube download/demux path.
- **FR-016**: Supported alignment languages remain the app’s current focus learning languages. An unmapped language MUST fall back (FR-007), not silently swap voice.

### Key Entities

- **Enrichment setting**: A single opt-in learner control (default off) that allows Craft save to persist nested timings from the alignment capability.
- **Synthesis-timing transcript**: Today’s Craft primary transcript: line cues built from synthesis word timings ([spec 030](../030-craft-tts-transcript/spec.md)). Still the line source when enrichment is on, and the entire stored transcript when enrichment is off or alignment fails.
- **Enriched Craft cue**: A synthesis-timing line that also stores optional word/phone spans from a successful same-language spoken-reference alignment of that line’s window.
- **Alignment fallback**: Save completed with the synthesis-timing or blank transcript and no nested spans, after alignment could not succeed.
- **Spoken reference**: Internal same-language voice rendering used by the alignment capability (slices 2b). Never the learner’s playback audio.
- **Transcript cue / word span / phone span / line identity**: Same meaning as [slice 1](../036-transcript-nested-timeline/spec.md).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With enrichment at default (off), on the same curated regression set as slices 1–2b (at least 10 existing transcripts: import, YouTube captions, speech-to-text, Craft synthesis, plus at least one blank-transcript Craft path), 100% of cues keep the same line text, order, start, and duration; 0 new Craft saves gain nested spans.
- **SC-002**: Learners can find the enrichment control in Settings; a fresh profile shows it **off**; a changed value is still there after relaunch; the next Craft save honors it without restart.
- **SC-003**: With enrichment on and a short Craft item (at least 2 lines, at least 2 words) that already gets a solid synthesis transcript, 100% of lines keep synthesis text/start/duration; 100% of successful lines store word spans in order; each word start is within **50 ms** of that line window except for the published pad; at least one word has phones that are not a letter-split of the spelling.
- **SC-004**: With enrichment on and alignment forced unavailable (or unsupported language, or no extractable audio, or timeout), 100% of Craft saves still complete; the stored transcript matches the pre-feature result for that path; 0 nested spans from a non-speech stand-in.
- **SC-005**: With enrichment on, 0 import / YouTube / speech-to-text saves gain nested spans from this slice; 0 already-saved library items change until a Craft re-save.
- **SC-006**: Side-by-side with the pre-feature build, the transcript panel shows no karaoke, IPA, or per-word chrome; 0 playback substitutions of a spoken-reference voice.
- **SC-007**: A Craft save that is blank under spec 030 stays blank (0 invented lines or nested spans) even when enrichment is on.
- **SC-008**: While a typical Craft clip (about **60 s** or less) is being enriched, the rest of the app remains usable. If alignment cannot finish in time a save can wait (**under 10 s** on a current mid-range device, documented if slower on a given platform), the save still completes via SC-004 fallback rather than hanging.

## Assumptions

- This slice is the first **product caller** of the unused alignment capability. Shipping with inert nested data in the panel is intended; karaoke is slice 4.
- Enrichment runs on **Craft save / re-save**, not on first play and not as a library-wide backfill. That keeps save/playback independently testable and avoids delaying open of old items.
- Line windows already exist from spec 030 when timings are solid. Per-line alignment is the calling pattern. Whole-clip alignment is not required for this Craft path.
- Spec 030 remains the contract for “solid timings → lines” vs “no solid timings → blank + later speech-to-text.” Alignment does not become a third way to create a transcript.
- Synthesis word-boundary events stay the **line** source. They are no longer the stored source of **nested** word/phone spans when enrichment succeeds.
- The setting key remains `transcript.timelineEnrichment` (default off), as named in issue #540 and slices 1–2b. Exact Settings copy belongs in localization during implementation.
- Quiet fallback (no blocking error chrome) is the default when alignment fails so Craft save cannot become more fragile than today. Diagnostic logging may record the reason; a toast is not required in this slice.
- Word-start tolerance remains **±50 ms** vs the spoken reference / line window pad from slices 2–2b. Bit-identical timestamps are not required.
- Focus learning languages remain the v1 alignment language bar.
- Offline/on-device alignment. Extra learner credits are not spent.
- Deduped Craft creates that skip synthesis also skip enrichment (no silent rewrite).
- Secondary translation tracks are not aligned in this slice.
- Slice 1 nested storage, slice 2 calling patterns, and slice 2b spoken-reference / fail-closed rules remain dependencies.

## Dependencies

- Relies on slice 1 nested cue meaning ([036](../036-transcript-nested-timeline/spec.md), [ADR-0070](../../docs/decisions/0070-nested-transcript-timeline.md)).
- Relies on the callable alignment capability ([037](../037-alignment-engine/spec.md)) and spoken-reference production path ([038](../038-alignment-spoken-reference/spec.md), [ADR-0072](../../docs/decisions/0072-spoken-alignment-reference.md)).
- Relies on Craft line-building and blank-transcript rules ([030](../030-craft-tts-transcript/spec.md), ADR-0063).
- Relies on existing extractable-audio paths for **Craft** files. Does not rely on YouTube WebView PCM.
- Does not depend on slice 4 karaoke, slice 5 word practice, or [#527](https://github.com/baizhiheizi/enjoy_player/issues/527) IPA overlay.
- Must not change auto-translate fingerprinting or transcript panel behavior documented in [docs/features/transcript.md](../../docs/features/transcript.md) beyond storing optional nested fields on Craft saves.
- Must update [docs/features/craft.md](../../docs/features/craft.md) and [docs/features/transcript.md](../../docs/features/transcript.md) when this behavior ships.
