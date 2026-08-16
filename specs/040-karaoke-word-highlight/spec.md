# Feature Specification: Karaoke Word Highlight

**Feature Branch**: `040-karaoke-word-highlight`

**Created**: 2026-08-16

**Status**: Draft

**Input**: User description: "continue to implement next follow-up spec"

**Source**: [GitHub issue #540](https://github.com/baizhiheizi/enjoy_player/issues/540). This specification is **slice 4** of that program. Slice 1 ([036-transcript-nested-timeline](../036-transcript-nested-timeline/spec.md)) lets a stored cue hold optional word/phone spans. Slices 2–2b ([037](../037-alignment-engine/spec.md), [038](../038-alignment-spoken-reference/spec.md)) can produce those timings. Slice 3 ([039-craft-timeline-enrichment](../039-craft-timeline-enrichment/spec.md)) is the first product writer: opt-in Craft save may persist nested word/phone timings. This slice is the **first product reader in the transcript panel**: opt-in karaoke may highlight the current **word** while media plays, when that cue already has word timings. It does **not** add IPA overlay, per-word tap/seek/loop, new alignment, or library backfill.

## Program split (issue #540)

Each slice MUST be independently shippable: existing transcript, playback, Craft, import, speech-to-text, YouTube captions, echo, lookup, and translation behavior stay intact unless that slice’s opt-in path is explicitly on.

| Slice | Spec | What ships | Why it does not break existing features |
|-------|------|------------|----------------------------------------|
| **1** | [Nested transcript timeline](../036-transcript-nested-timeline/spec.md) | A cue MAY carry optional word/phone spans. No new UI. | Additive storage. Nested data ignored until a consumer slice. |
| **2** | [Alignment engine](../037-alignment-engine/spec.md) | Standalone capability: known text + extractable audio → word/phone timings. | Unused by product flows in that slice. |
| **2b** | [Spoken alignment reference](../038-alignment-spoken-reference/spec.md) | Production alignment compares the clip to a same-language spoken rendering. | Unused. Learners see no change. |
| **3** | [Craft timeline enrichment](../039-craft-timeline-enrichment/spec.md) | Opt-in: Craft items may store nested timings. Default remains today’s synthesis-timing transcript. | Off by default. On failure, Craft save and playback match pre-feature behavior. |
| **4 (this spec)** | Karaoke word highlight | Opt-in word highlight while media plays, when the cue has word timings. | Off by default; inactive on line-only cues. Line-level current-cue behavior stays. |
| **5** | Word-level practice | Opt-in later: tap/loop/inspect a word. | No nested data → today’s line-level interactions. |
| **Related** | IPA overlay ([#527](https://github.com/baizhiheizi/enjoy_player/issues/527)) | Display pronunciation spelling per word. | Own toggle and own spec. |

**Out of the #540 program (all slices):** aligning YouTube WebView playback (no extractable audio), aligning the learner’s own shadow-reading recording, replacing Craft’s high-quality playback audio with a synthetic reference voice, real-time/streaming alignment, and cross-language alignment (audio in one language, transcript in another).

## Scope (this slice only)

### In scope

- Add one learner-facing **opt-in** control (default **off**) that allows the transcript panel to highlight the **current word** on cues that already store word timings.
- While that control is **on** and playback position falls inside a timed word on the current line, show a clear in-place highlight on that word. Line-level current-cue chrome (row tint, rail, auto-follow) stays.
- While that control is **off**, or a cue has no usable word timings, the panel MUST match today’s line-level presentation for that cue.
- Consume **already stored** nested word times. Do not run alignment, do not rewrite the library, and do not change Craft save.
- Keep tap-to-seek, echo, lookup, blur, auto-translate, and cue identity on **line-level** fields.

### Out of scope (this slice)

- Per-word tap, seek-to-word, loop-a-word, or inspect phones (slice 5).
- IPA / pronunciation spelling overlay ([#527](https://github.com/baizhiheizi/enjoy_player/issues/527)). Phone labels may exist in storage; this slice does not show them. Learners still cannot “see IPA” here — they can see that **word timings** are in use via karaoke.
- Producing or backfilling word timings (Craft enrichment stays slice 3; import / YouTube / speech-to-text stay line-only writers).
- First-play or mid-playback alignment that delays opening or seeking.
- Changing how Craft builds or saves transcripts ([spec 030](../030-craft-tts-transcript/spec.md) / [spec 039](../039-craft-timeline-enrichment/spec.md)).
- Replacing lesson playback with a spoken-reference voice.
- Changing shadow-reading **assessment** karaoke (the result sheet that highlights Azure word chips while a **take** replays). That surface stays as today.
- YouTube demux, learner-recording alignment, streaming alignment, cross-language alignment.
- Changing cue identity (`cueIdFor`, auto-translate fingerprint) or echo-window membership rules.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Default off: transcripts still behave as line-level (Priority: P1)

A learner who never turns karaoke on (the shipped default) practices exactly as after slice 3. Current-line tracking, tap-to-seek, echo, lookup, blur, and auto-translate are unchanged. Enriched Craft items may still store nested word timings, but the panel does not highlight individual words. Line-only items (import, YouTube captions, speech-to-text, un-enriched Craft) look as they do today.

**Why this priority**: Slice 4 is only shippable if the default path is today’s transcript panel. Karaoke must not appear uninvited on every enriched line.

**Independent Test**: Leave karaoke at default. Open a mix of line-only items and at least one Craft item known to have nested word timings. Play, pause, seek, echo, lookup, and blur. Confirm no in-line word highlight and that line chrome matches the post-slice-3 panel.

**Acceptance Scenarios**:

1. **Given** karaoke at its default (off) and a cue that stores word timings, **When** the item plays through that cue, **Then** the panel still uses today’s line-level current-cue presentation and does not highlight individual words.
2. **Given** that same default and a line-only cue, **When** the item plays, **Then** current-line, tap-to-seek, echo, lookup, and blur match today.
3. **Given** karaoke off, **When** the learner opens Settings, **Then** they can find the karaoke control and see that it is **off**.

---

### User Story 2 - Opt-in karaoke highlights the spoken word (Priority: P1)

A learner turns karaoke on, then plays an item whose current cue already has timed words (typically a Craft item saved with enrichment on). As speech moves through the line, the word being spoken is visually distinct from the rest of that line. The rest of the line stays readable. When playback leaves that word, the highlight moves to the next timed word, or clears if none applies. This is the first in-app way to tell that nested word timings exist — without showing IPA.

**Why this priority**: This is the entire product value of slice 4: stored word times become something the learner can follow by eye.

**Independent Test**: Turn karaoke on. Open an item with at least one multi-word cue that has stored word timings. Play at 1×. Confirm the highlighted word is the one whose stored time window contains the current playback position, and that line-level current-cue chrome still marks that row.

**Acceptance Scenarios**:

1. **Given** karaoke is on and the current cue has ordered timed words, **When** playback position sits inside a word’s stored time window, **Then** that word is highlighted in place in the existing line text.
2. **Given** that same setup, **When** playback advances into the next timed word, **Then** the highlight moves to that word and the previous word returns to ordinary line text styling.
3. **Given** karaoke is on, **When** playback is paused inside a timed word, **Then** that word stays highlighted until position changes.
4. **Given** karaoke is on and the current cue is also the active line, **When** the word highlight is visible, **Then** today’s line-level current-cue chrome (row treatment and auto-follow of the **line**) still applies.
5. **Given** karaoke is on, **When** the learner taps a non-active, non-echo line, **Then** playback still seeks to that **line’s** start (not to a word). Tapping a word does not introduce a new seek target in this slice.

---

### User Story 3 - Line-only and incomplete cues stay safe (Priority: P1)

A learner has karaoke on but is practicing mixed material: some cues have timed words, some are line-only, some have nested words without times. Karaoke never blanks a line, never blocks playback, and never invents word timings. Cues without a usable current word keep today’s line-level presentation.

**Why this priority**: Most library items remain line-only. Karaoke must degrade per cue, not per session.

**Independent Test**: Turn karaoke on. Play a transcript that mixes (a) a cue with timed words, (b) a line-only cue, (c) a cue with words that omit times. Confirm only (a) shows word highlight, and that (b) and (c) still show and seek as lines.

**Acceptance Scenarios**:

1. **Given** karaoke is on and the current cue has no word timings, **When** that cue is active, **Then** the panel uses today’s line-level presentation for that cue (no fake per-word split of the line text).
2. **Given** karaoke is on and a cue lists words but none have usable times, **When** that cue is active, **Then** no word is highlighted; the line still displays and seeks using line times.
3. **Given** karaoke is on and only some words on a cue have times, **When** position is inside an untimed word’s text, **Then** no word is highlighted until position enters a timed word (the line remains visible).
4. **Given** karaoke is on and a cue’s word times fall outside that cue’s line window, **When** playback runs, **Then** those out-of-window words are not highlighted; line start/duration and current-line tracking do not change.
5. **Given** unreadable nested data on one cue, **When** the track loads, **Then** that cue degrades to line-only presentation and the rest of the transcript still loads.

---

### User Story 4 - Karaoke coexists with practice modes and other settings (Priority: P1)

A learner can use karaoke together with echo, dictionary lookup, blur, and translation without those features changing their line identity rules. Karaoke is a **display** preference, independent of Craft’s enrichment **save** toggle. Turning karaoke on does not rewrite the library and does not start aligning captions.

**Why this priority**: Echo, blur, and lookup are daily practice. A word highlight that seeks on tap, unblurs the active line, or starts aligning YouTube would break those contracts.

**Independent Test**: Turn karaoke on. Exercise echo region, lookup on the active line, blur (including that the active line stays blurred until hover/hold), and a secondary translation line. Confirm line identity and those interactions match today, with word highlight only on the primary line text when it is actually visible.

**Acceptance Scenarios**:

1. **Given** karaoke is on and echo mode is on, **When** lesson audio plays through the active echo cue and that cue has timed words, **Then** the current word can highlight on that cue’s **primary** text; echo membership and expand/shrink still use line times.
2. **Given** karaoke is on and the active/echo line is selectable for lookup, **When** the learner selects text for dictionary lookup, **Then** lookup still uses the line (or the selected substring) as today; words are not new exclusive tap targets.
3. **Given** karaoke is on and blur practice is on, **When** a cue is blurred, **Then** karaoke MUST NOT auto-reveal that cue. When the learner reveals it (hover or hold), word highlight MAY show on the revealed primary text.
4. **Given** karaoke is on and a translation/secondary line is shown, **When** playback advances, **Then** word highlight applies to the **primary** line only; the translation line stays line-level as today.
5. **Given** karaoke is on and Craft enrichment is **off**, **When** the learner opens an already-enriched item, **Then** karaoke still highlights stored word times (display does not require the save toggle). New Craft saves still follow slice 3 (no nested spans while enrichment is off).
6. **Given** karaoke is on, **When** the learner imports captions, opens YouTube captions, or generates speech-to-text, **Then** those tracks remain line-only; this slice does not enrich them so they can karaoke.

---

### Edge Cases

- **No stored word times anywhere on the track**: Karaoke on is a no-op visually; the panel stays line-level. The setting may still show on.
- **Playback position between words**: If position is on the current line but in a gap (or punctuation) that no timed word covers, no word is highlighted until a timed window matches.
- **Overlapping word windows**: Highlight exactly one word — the last timed word in line order whose window contains the position. Do not highlight two words at once.
- **Seek / scrub / speed change**: Highlight follows **media position**, not wall-clock time. After a seek, the word at the new position is highlighted without waiting for the next line change.
- **Paused / stopped / media cleared**: Pause keeps the word at the paused position. Stop or leaving the item clears word highlight with the rest of playback chrome.
- **Auto-follow**: The list still follows the **line** (and echo block in echo mode) as today. Karaoke MUST NOT retarget auto-follow to a word.
- **Markup in line text**: Styled caption markup still renders; karaoke highlights the spoken word inside that readable text, not raw tags.
- **Very long lines / many words**: The line still scrolls and virtualizes like today’s list. Highlighting one word MUST NOT freeze the panel or drop current-line tracking.
- **Shadow-reading take replay**: Assessment-result karaoke on Azure word chips while a **take** plays is unchanged and is not this setting.
- **Reduced motion**: The current word may still change; extra motion between words is not required.
- **Multiple timed words with empty text**: Skip empty spans; they never become the highlighted word.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The product MUST add one learner-facing karaoke / word-highlight setting, default **off**, persisted with the rest of Settings, and honored on the next play without requiring an app restart.
- **FR-002**: That setting MUST be independent of Craft timeline enrichment. Enrichment continues to control whether new Craft saves store nested timings; karaoke controls only whether stored word times are shown as a highlight.
- **FR-003**: While karaoke is off, the transcript panel MUST match today’s line-level presentation even when nested word timings are present.
- **FR-004**: While karaoke is on, the panel MUST highlight at most one current word on the current primary cue, and only when that word has a usable stored time window that contains the current playback position.
- **FR-005**: Word highlight MUST be in-place in the existing primary line text (the rest of the line stays readable). This slice MUST NOT convert the line into a row of new per-word chips or buttons.
- **FR-006**: Line-level current-cue tracking, row chrome, tap-to-seek-to-line, echo region, auto-follow, blur, lookup, and auto-translate identity MUST keep using line text and line times. Nested spans MUST NOT become the source of those behaviors.
- **FR-007**: This slice MUST NOT add seek-to-word, loop-a-word, or inspect-phones. Tapping a line follows today’s seek vs lookup rules.
- **FR-008**: A cue with no timed words, incomplete times, or unreadable nested data MUST present as a normal line (no invented split, no error chrome that blocks playback).
- **FR-009**: Word times outside the parent line window MUST be ignored for highlighting and MUST NOT rewrite line start/duration or current-line membership.
- **FR-010**: Karaoke MUST NOT auto-reveal a blurred cue. Highlight may appear only on primary text that is already visible (blur off, or hover/hold reveal).
- **FR-011**: Secondary / translation text MUST stay line-level in this slice (no word highlight on the translation line).
- **FR-012**: This slice MUST NOT run alignment, MUST NOT rewrite already-saved items in the background, and MUST NOT start writing nested spans from import, YouTube captions, or speech-to-text.
- **FR-013**: This slice MUST NOT play a spoken alignment reference and MUST NOT replace lesson audio.
- **FR-014**: This slice MUST NOT add IPA overlay. Phone spans may exist in storage; they are not shown here.
- **FR-015**: Shadow-reading assessment take-replay karaoke MUST remain a separate surface and MUST NOT require this new setting.
- **FR-016**: Learners MUST be able to find the karaoke control under Settings (Transcript), see that it is off by default, and have the choice remembered across relaunch.

### Key Entities

- **Karaoke setting**: A single opt-in learner control (default off) that allows the transcript panel to highlight the current word when stored word timings exist.
- **Current word**: The at-most-one timed word on the current primary cue whose stored time window contains the current playback position.
- **Timed word span**: A stored word on a cue that includes a usable start and duration (slice 1 meaning: times relative to the parent line). Untimed words cannot be the current word.
- **Line-only cue**: A cue with no usable timed words. Karaoke never splits it visually in this slice.
- **Line identity**: Line text and line times (and the existing translation fingerprint when present) used by current-line, echo, blur, lookup, and auto-translate. Unchanged by karaoke.
- **Enrichment setting**: Slice 3’s separate control for whether Craft **save** stores nested timings. Not a prerequisite for displaying karaoke on items that already have those timings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With karaoke at default (off), on a curated set of at least 10 transcripts (import, YouTube captions, speech-to-text, Craft line-only, and at least one Craft item with nested word timings), 0 cues show in-line word highlight; 100% keep today’s line-level current-cue, tap-to-seek, echo, lookup, and blur behavior.
- **SC-002**: Learners can find the karaoke control in Settings → Transcript; a fresh profile shows it **off**; a changed value is still there after relaunch; the next playback honors it without restart.
- **SC-003**: With karaoke on and a cue of at least 3 timed words, sampling playback position at 1× across that cue, the highlighted word matches the timed word whose stored window contains that position for **at least 95%** of samples; 0 samples highlight two words at once.
- **SC-004**: With karaoke on, 100% of line-only cues in the same set stay visually line-level (no invented per-word split). Incomplete or out-of-window word times never blank the line or block playback.
- **SC-005**: With karaoke on and blur on, the active cue stays blurred until hover/hold (0 auto-reveals caused by word highlight). With karaoke on and a translation line visible, 0 word highlights appear on the translation line.
- **SC-006**: Side-by-side with the post-slice-3 build, tap-to-seek still targets **lines**; 0 new per-word tap/loop/inspect controls; 0 new IPA chrome; 0 alignment runs started by opening or playing an item.
- **SC-007**: Turning karaoke on does not change stored transcripts (0 library rewrites). Craft save still follows slice 3 regardless of the karaoke setting.
- **SC-008**: On a typical enriched item (about **60 s** or less, on the order of **100** lines or fewer), while playing at 1× with karaoke on, the transcript remains scrollable and current-line tracking still updates; learners see the highlighted word change in step with speech rather than trailing a full word behind.

## Assumptions

- This slice is the first **panel consumer** of nested word times. Shipping karaoke without IPA or per-word tap is intended; those are later slices.
- Karaoke is a **persisted display preference** (Settings → Transcript), not a per-media practice mode like echo or blur. It applies across items until the learner turns it off.
- Karaoke does not require Craft enrichment to be on at play time. It only needs stored timed words on the cue.
- In-place highlight of existing line text is the enjoy-web-like reading experience. Assessment-result word **chips** remain a different surface.
- Line times remain authoritative for “which cue is current.” Word times only decide which substring of that cue is emphasized.
- Word windows use the slice 1 meaning (start/duration relative to the parent line). Playback position is on the media timeline; a word matches when media position falls in `[line start + word start, line start + word start + word duration)`.
- Exact Settings copy belongs in localization during implementation.
- Quiet degradation (no blocking error) when nested data is missing or incomplete. Diagnostic logging may record why a cue has no current word; a toast is not required.
- Focus learning languages and alignment quality remain slice 3’s problem. This slice does not repair bad timings; it only highlights what is stored.
- YouTube WebView items stay caption-line-only unless some later slice stores word times on them.
- Seeing stored **phones / IPA labels** in the panel is [#527](https://github.com/baizhiheizi/enjoy_player/issues/527), not this slice. Karaoke only proves that **word timings** are present.

## Dependencies

- Relies on slice 1 nested cue meaning ([036](../036-transcript-nested-timeline/spec.md), [ADR-0070](../../docs/decisions/0070-nested-transcript-timeline.md)).
- Relies on items that already have nested word timings, typically from slice 3 Craft enrichment ([039](../039-craft-timeline-enrichment/spec.md), [ADR-0073](../../docs/decisions/0073-craft-timeline-enrichment.md)). It does not require calling the alignment engine at play time.
- Relies on existing transcript panel contracts in [docs/features/transcript.md](../../docs/features/transcript.md): current line, tap-to-seek, echo, blur (active line stays blurred), lookup, auto-translate.
- Must not change shadow-reading assessment take-replay karaoke documented in [docs/features/shadow-reading.md](../../docs/features/shadow-reading.md).
- Does not depend on slice 5 word practice or [#527](https://github.com/baizhiheizi/enjoy_player/issues/527) IPA overlay.
- Must update [docs/features/transcript.md](../../docs/features/transcript.md) (and Settings copy if the Transcript section gains a row) when this behavior ships.
