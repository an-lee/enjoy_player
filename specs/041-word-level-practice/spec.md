# Feature Specification: Word-Level Practice

**Feature Branch**: `041-word-level-practice`

**Created**: 2026-08-16

**Status**: Draft

**Input**: User description: "continue to finish the remaining follow-up specs" then "we should implement the IPA overlay in this spec too"

**Source**: [GitHub issue #540](https://github.com/baizhiheizi/enjoy_player/issues/540) **slice 5**, absorbing the stored-phone display from [GitHub issue #527](https://github.com/baizhiheizi/enjoy_player/issues/527). Slice 1 ([036-transcript-nested-timeline](../036-transcript-nested-timeline/spec.md)) lets a stored cue hold optional word/phone spans. Slices 2–2b ([037](../037-alignment-engine/spec.md), [038](../038-alignment-spoken-reference/spec.md)) can produce those timings. Slice 3 ([039-craft-timeline-enrichment](../039-craft-timeline-enrichment/spec.md)) may persist nested timings on Craft save. Slice 4 ([040-karaoke-word-highlight](../040-karaoke-word-highlight/spec.md)) may highlight the current timed word while media plays. This slice is the **interactive and pronunciation-display consumer** of those stored words: opt-in IPA overlay from stored phones, tap to seek a word, loop a word, and inspect that word’s phone pieces. It does **not** generate IPA for line-only captions, run new alignment, or backfill the library.

## Program split (issue #540)

Each slice MUST be independently shippable: existing transcript, playback, Craft, import, speech-to-text, YouTube captions, echo, lookup, karaoke, and translation behavior stay intact unless that slice’s opt-in path is explicitly on.

| Slice | Spec | What ships | Why it does not break existing features |
|-------|------|------------|----------------------------------------|
| **1** | [Nested transcript timeline](../036-transcript-nested-timeline/spec.md) | A cue MAY carry optional word/phone spans. No new UI. | Additive storage. Nested data ignored until a consumer slice. |
| **2** | [Alignment engine](../037-alignment-engine/spec.md) | Standalone capability: known text + extractable audio → word/phone timings. | Unused by product flows in that slice. |
| **2b** | [Spoken alignment reference](../038-alignment-spoken-reference/spec.md) | Production alignment compares the clip to a same-language spoken rendering. | Unused. Learners see no change. |
| **3** | [Craft timeline enrichment](../039-craft-timeline-enrichment/spec.md) | Opt-in: Craft items may store nested timings. Default remains today’s synthesis-timing transcript. | Off by default. On failure, Craft save and playback match pre-feature behavior. |
| **4** | [Karaoke word highlight](../040-karaoke-word-highlight/spec.md) | Opt-in word highlight while media plays, when the cue has word timings. | Off by default; inactive on line-only cues. Line-level current-cue behavior stays. |
| **5 (this spec)** | Word-level practice + IPA overlay | Opt-in: show stored pronunciation spelling per word; tap/loop/inspect a timed word. | Off by default. No nested phones → no IPA. No nested times → today’s line-level tap. Lookup stays on selectable rows. |

**Out of the #540 program (all slices):** aligning YouTube WebView playback (no extractable audio), aligning the learner’s own shadow-reading recording, replacing Craft’s high-quality playback audio with a synthetic reference voice, real-time/streaming alignment, and cross-language alignment (audio in one language, transcript in another).

**Still deferred from [#527](https://github.com/baizhiheizi/enjoy_player/issues/527) (not this spec):** generating pronunciation spelling for captions that have **no** stored phones (wordlists, cloud phonemizers, or other lookup-time IPA). This slice only **displays** pronunciation already stored on nested phone spans.

## Scope (this slice only)

### In scope

- Add two learner-facing **opt-in** controls (both default **off**), independent of each other, of karaoke, and of Craft enrichment:
  - **IPA overlay** — show stored pronunciation spelling with each word on the visible primary line when that word has stored phone / pronunciation pieces.
  - **Word-level practice** — on cues that already store usable timed words: tap a timed word to seek, loop that word’s stored media window, and inspect that word’s stored phones.
- While **IPA overlay** is **on**, words with stored pronunciation pieces show that spelling together with the word (secondary spelling attached to the word, not a translation line). Words without stored phones show ordinary word text only.
- While **word-level practice** is **on**:
  - On rows that are **not** selectable for dictionary lookup, tapping a timed word seeks playback to that word’s stored media window (not only the line start).
  - The learner can **loop** one chosen timed word’s stored media window until they cancel.
  - The learner can **inspect** the ordered stored phone pieces for that chosen word when those pieces exist (detail beyond the overlay’s per-word spelling).
- While both controls are **off**, or a cue has no usable nested data, tap-to-seek, echo, lookup, karaoke, and blur MUST match today’s line-level behavior for that cue.
- Consume **already stored** nested word and phone data. Do not run alignment, do not invent IPA, do not rewrite the library, and do not change Craft save or karaoke’s highlight contract.
- Keep echo membership, cue identity, auto-translate fingerprint, and shadow-reading assessment on **line-level** fields.

### Out of scope (this slice)

- Generating IPA / pronunciation spelling for line-only cues or for words that have no stored phones ([#527](https://github.com/baizhiheizi/enjoy_player/issues/527) G2P / dictionary / cloud phonemizer path).
- Changing karaoke highlight rules, Craft enrichment save, or who writes nested timings (import / YouTube / speech-to-text stay line-only writers).
- First-play or mid-playback alignment, including alignment when the learner taps a word or turns overlay on.
- Replacing lesson playback with a spoken-reference voice.
- Changing shadow-reading **assessment** karaoke (Azure word chips while a **take** replays). Assessment IPA on a take remains that surface.
- YouTube demux, learner-recording alignment, streaming alignment, cross-language alignment.
- Changing cue identity or echo-window membership rules (which lines are in echo still uses line times; expand/shrink stays line-based).
- Turning timed words into exclusive tap targets on **selectable** rows (active cue and cues inside the echo window). Dictionary lookup remains the primary interaction there.
- A new echo region whose start/end is a word. Word loop is a playback-window overlay, not a rewrite of echo.
- Phone-level karaoke (highlighting individual phones while they play). Overlay shows spelling; karaoke (slice 4) still highlights the **word**.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Default off: transcripts still behave as line-level (Priority: P1)

A learner who never turns IPA overlay or word-level practice on (the shipped defaults) practices exactly as after slice 4. Inactive rows still seek to the **line**. Active and echo rows stay selectable for dictionary lookup. Karaoke, if on, still only highlights. Enriched Craft items may store nested words and phones, but the panel does not show pronunciation spelling, and tapping a word does not seek, loop, or open inspect.

**Why this priority**: Slice 5 is only shippable if the default path is today’s transcript. IPA and word targets must not appear uninvited and must not steal lookup.

**Independent Test**: Leave both new controls at default. Open a mix of line-only items and at least one Craft item known to have nested word timings and phones. Play, tap inactive lines, select text on the active/echo line, echo, karaoke, lookup, and blur. Confirm no IPA spelling on the line, no seek-to-word, no word loop, and no inspect chrome.

**Acceptance Scenarios**:

1. **Given** both new controls at default (off) and a cue that stores timed words and phones, **When** the learner taps that cue’s primary text on a non-active, non-echo row, **Then** playback still seeks to that **line’s** start (not to a word) and no pronunciation spelling is shown on the line.
2. **Given** those defaults and karaoke on, **When** the item plays, **Then** karaoke may still highlight the current word, and tapping still follows today’s seek vs lookup rules.
3. **Given** those defaults, **When** the learner opens Settings, **Then** they can find both the IPA overlay control and the word-level practice control and see that each is **off**.

---

### User Story 2 - Opt-in IPA overlay shows stored pronunciation on words (Priority: P1)

A learner turns IPA overlay on, then opens an item whose cues already store phone / pronunciation pieces (typically a Craft item saved with enrichment on). Each word that has stored spelling shows that spelling together with the word on the primary line. The line remains readable as transcript text. Words without stored phones look as they do today. Line-only cues are unchanged. This is the first in-app way to **read** stored IPA on the transcript — without generating new spelling and without requiring karaoke or word tap.

**Why this priority**: Seeing pronunciation on the line is the #527 user-visible win, and nested phones are wasted until a panel consumer shows them.

**Independent Test**: Turn IPA overlay on (word-level practice may stay off). Open an item with a multi-word cue that has stored phones on some words and not others. Confirm spelling appears only on words that have stored pieces, that the transcript text is still the primary reading line, and that a line-only cue shows no IPA.

**Acceptance Scenarios**:

1. **Given** IPA overlay is on and a visible primary cue has words with stored pronunciation pieces, **When** the learner reads that cue, **Then** each such word shows its stored spelling together with the word (not as a translation/secondary line).
2. **Given** that same setup, **When** a word on that cue has no stored phones, **Then** that word shows ordinary text only (no invented spelling, no empty error chrome).
3. **Given** IPA overlay is on and a cue is line-only, **When** the learner views that cue, **Then** the cue stays visually line-level (no fake per-word IPA split).
4. **Given** IPA overlay is on and word-level practice is off, **When** the learner taps a non-active, non-echo row, **Then** playback still seeks to the **line** (overlay is display-only).
5. **Given** IPA overlay is on, **When** the learner selects text on a selectable row for dictionary lookup, **Then** lookup still uses the transcript text (or selected substring) as today, **not** the pronunciation spelling.

---

### User Story 3 - Opt-in: tap a timed word to hear it (Priority: P1)

A learner turns word-level practice on, then taps a timed word on a row that is **not** used for dictionary lookup (inactive, outside the echo window). Playback jumps to that word’s stored start on the media timeline and plays from there. Tapping the timestamp or other line chrome still seeks to the **line**. Line-only cues and untimed words keep today’s line seek. IPA overlay may be on or off independently.

**Why this priority**: Seek-to-word is the core new interaction. It must work only where it does not collide with lookup.

**Independent Test**: Turn word-level practice on. Open an item with a multi-word nested cue that is not currently active or in echo. Tap a middle timed word. Confirm playback position is inside that word’s stored window (line start plus the word’s stored start), not the line start. Tap a line-only cue and confirm line seek.

**Acceptance Scenarios**:

1. **Given** word-level practice is on and a non-selectable cue has ordered timed words, **When** the learner taps a timed word, **Then** playback seeks to that word’s stored media start and that word becomes the chosen word.
2. **Given** that same setup, **When** the learner taps the cue’s timestamp or other non-word chrome, **Then** playback still seeks to the **line** start.
3. **Given** word-level practice is on and a cue is line-only (or its words have no usable times), **When** the learner taps that cue, **Then** playback still seeks to the line as today.
4. **Given** word-level practice is on and the row is selectable (active cue or inside the echo window), **When** the learner selects or taps text, **Then** dictionary lookup and selection still work as today; that tap does **not** seek to a word.

---

### User Story 4 - Loop one word, then inspect its stored phones (Priority: P1)

After choosing a timed word (by tapping it on a non-selectable row, or via a current-word practice action while that word is playing), the learner can repeat **only that word’s** stored media window until they cancel. They can also inspect the **ordered** stored phone pieces for that word when those pieces exist. Overlay (if on) already shows per-word spelling while reading; inspect is the closer look at that chosen word’s pieces. Echo expand/shrink and which lines belong to echo stay line-based.

**Why this priority**: Loop and inspect complete the program’s “practice a word” promise. They must not invent IPA, start alignment, or replace echo.

**Independent Test**: Turn word-level practice on. Choose a timed word that also has stored phones. Start a word loop and confirm playback repeats that word’s window. Cancel and confirm ordinary playback/echo resumes. Open inspect and confirm the stored pieces appear in order; repeat on a timed word with no phones and confirm a quiet empty result (no invented spelling).

**Acceptance Scenarios**:

1. **Given** word-level practice is on and a timed word is chosen, **When** the learner starts a word loop, **Then** playback repeats that one word’s stored media window until they cancel; other words on the line are not included.
2. **Given** a word loop is active inside an echo region, **When** the learner expands or shrinks echo, **Then** echo membership still uses **line** times; the word loop does not become a new echo window.
3. **Given** a word loop is active, **When** the learner cancels it (stop, leave the item, turn the setting off, or choose another playback target such as another word or a line seek), **Then** word looping ends and ordinary play or echo enforcement resumes.
4. **Given** a chosen timed word has stored phone pieces, **When** the learner inspects that word, **Then** those stored pieces are shown for that word only, in stored order.
5. **Given** a chosen timed word has no stored phones, **When** the learner would inspect, **Then** the product does not invent IPA, does not run alignment, and either offers no inspect chrome or a quiet empty state.
6. **Given** the current row is selectable for lookup, **When** the learner wants to loop or inspect the **current** timed word (the word whose stored window contains playback position), **Then** they can do so through a practice action that does **not** replace text selection / lookup.

---

### User Story 5 - Overlay and practice coexist with karaoke, echo, lookup, blur, and translation (Priority: P1)

A learner can use IPA overlay and word-level practice together with karaoke, echo, dictionary lookup, blur, and translation without those features changing their line identity rules. Overlay is a **display** preference; word-level practice is an **interaction** preference. Both are independent of karaoke (highlight) and Craft enrichment (save). Turning them on does not rewrite the library and does not start aligning captions or phonemizing line-only tracks.

**Why this priority**: Lookup, blur, and echo are daily practice. Overlay that leaks through blur, steals lookup text, or starts generating IPA would break those contracts.

**Independent Test**: Turn IPA overlay and word-level practice on. Exercise karaoke, echo, lookup on the active line, blur (including that the active line stays blurred until hover/hold), and a secondary translation line. Confirm line identity stays, lookup still uses transcript text, IPA appears only on visible primary words that have stored phones, and word actions apply only to visible primary text with stored times.

**Acceptance Scenarios**:

1. **Given** word-level practice is on and karaoke is off, **When** the learner taps a timed word on a non-selectable row, **Then** seek-to-word still works (practice does not require karaoke).
2. **Given** IPA overlay is on and karaoke is on, **When** the item plays through a cue that has timed words and stored phones, **Then** karaoke may still highlight the current **word** text; pronunciation spelling stays visible with its word and is not a second karaoke target.
3. **Given** IPA overlay and/or word-level practice is on and blur practice is on, **When** a cue is blurred, **Then** neither overlay nor word practice MUST auto-reveal that cue. IPA and word tap/loop/inspect apply only to primary text that is already visible (blur off, or hover/hold reveal). Blurred text MUST NOT leak pronunciation spelling.
4. **Given** either new control is on and a translation/secondary line is shown, **When** the learner views or interacts, **Then** IPA overlay and word seek/loop/inspect apply to the **primary** line only; the translation line stays line-level as today.
5. **Given** either new control is on and Craft enrichment is **off**, **When** the learner opens an already-enriched item, **Then** stored phones and timed words can still be shown and practiced (display/interaction do not require the save toggle). New Craft saves still follow slice 3.
6. **Given** either new control is on, **When** the learner imports captions, opens YouTube captions, or generates speech-to-text, **Then** those tracks remain line-only; this slice does not add IPA or word targets to them.

---

### Edge Cases

- **No stored word times anywhere on the track**: Word-level practice on is a no-op for tap/loop/inspect; the panel stays line-level. The setting may still show on.
- **No stored phones anywhere on the track**: IPA overlay on is a no-op visually; the panel stays without pronunciation spelling. The setting may still show on.
- **Phones without word times**: Overlay MAY still show stored spelling on those words. Those words are not seek/loop targets.
- **Times without phones**: Seek/loop MAY work. Overlay shows no spelling on those words.
- **Tap on a gap, punctuation, or untimed word**: Seek falls back to the **line** (same as today on that row type). That tap does not start a word loop.
- **Overlapping word windows**: Choose exactly one word — the last timed word in line order whose stored window contains the tap or the playback position. Do not loop two words at once. Overlay may still show spelling on every word that has phones.
- **Word times outside the parent line window**: Ignore those words as seek/loop/inspect targets. Do not rewrite line start/duration. Overlay MAY still show their stored spelling if the parent line is visible, or omit them if they are not part of the readable line text.
- **Seek / scrub / speed change during a word loop**: The looped window still uses stored times on the media timeline. Speed changes apply to that window as they do to ordinary playback. Scrubbing outside the looped word cancels the loop.
- **Paused / stopped / media cleared**: Pause may keep the chosen word and overlay. Stop or leaving the item clears word loop and inspect chrome with the rest of playback chrome. Overlay follows the setting for whatever cues remain visible.
- **Auto-follow**: The list still follows the **line** (and echo block in echo mode) as today. Overlay and word practice MUST NOT retarget auto-follow to a word.
- **Blurred inactive row**: Today’s reveal-hold still applies. While the cue stays blurred, a tap MUST NOT use hidden word geometry as a new way to cheat-reveal, and IPA MUST NOT show through the blur. After the text is visible, overlay and timed-word targets work.
- **Very long lines / many words**: The line still scrolls like today’s list. Showing IPA on many words and hitting one word MUST NOT freeze the panel or drop current-line tracking.
- **Shadow-reading take replay**: Assessment-result karaoke on Azure word chips while a **take** plays is unchanged and is not these settings.
- **Karaoke current word vs chosen word**: Karaoke may highlight the word that contains **playback position**. The chosen word for loop/inspect is the word the learner selected, or the current timed word when they use the current-word practice action. They may differ after a pause on another word.
- **Multiple timed words with empty text**: Skip empty spans; they never become seek, loop, inspect, or IPA targets.
- **Unreadable nested phones**: Skip that word’s overlay; do not blank the line.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The product MUST add two learner-facing settings — IPA overlay and word-level practice — each default **off**, persisted with the rest of Settings, and honored on the next play without requiring an app restart.
- **FR-002**: Those settings MUST be independent of each other, of karaoke highlight, and of Craft timeline enrichment. Karaoke continues to control in-place highlight; enrichment continues to control whether new Craft saves store nested timings; overlay controls whether stored pronunciation is shown; word-level practice controls whether stored words can be sought, looped, and inspected.
- **FR-003**: While both new settings are off, tap-to-seek, lookup, echo, karaoke, and blur MUST match today’s behavior even when nested word timings and phones are present. No pronunciation spelling appears on the line.
- **FR-004**: While IPA overlay is on, the panel MUST show stored pronunciation spelling together with each visible primary-line word that has stored phone pieces. It MUST NOT invent spelling for words without stored phones. It MUST NOT move that spelling onto the translation/secondary line.
- **FR-005**: Dictionary lookup MUST continue to use transcript text (the line or the selected substring), never the pronunciation spelling, even when overlay is on.
- **FR-006**: While word-level practice is on, tapping a timed word on a **non-selectable** nested cue MUST seek playback to that word’s stored media start (`line start + word start` in the slice 1 meaning). Tapping line chrome on that row MUST still seek to the line.
- **FR-007**: While word-level practice is on, selectable rows (active cue and cues inside the echo window) MUST remain selectable for dictionary lookup. Those rows MUST NOT treat timed words as exclusive seek targets.
- **FR-008**: Learners MUST be able to loop **one** chosen timed word’s stored media window until they cancel. Word loop MUST NOT rewrite echo start/end or which lines belong to the echo region.
- **FR-009**: Learners MUST be able to inspect ordered stored phone pieces for the chosen timed word when those pieces exist. Missing phones MUST NOT invent IPA and MUST NOT start alignment.
- **FR-010**: On selectable rows, loop and inspect of the **current** timed word (the word whose stored window contains playback position) MUST be available through a path that does not replace text selection / lookup.
- **FR-011**: A cue with no timed words, no phones, incomplete data, or unreadable nested data MUST present and seek as a normal line (no invented split, no error chrome that blocks playback). Overlay is a no-op on that cue when phones are missing.
- **FR-012**: Word times outside the parent line window MUST be ignored for seek/loop/inspect and MUST NOT rewrite line start/duration or current-line membership.
- **FR-013**: IPA overlay and word practice MUST NOT auto-reveal a blurred cue. Pronunciation spelling, word tap, loop, and inspect may apply only to primary text that is already visible.
- **FR-014**: Secondary / translation text MUST stay line-level in this slice (no IPA overlay, word seek, loop, or inspect on the translation line).
- **FR-015**: This slice MUST NOT run alignment, MUST NOT generate IPA for cues or words that lack stored phones, MUST NOT rewrite already-saved items in the background, and MUST NOT start writing nested spans from import, YouTube captions, or speech-to-text.
- **FR-016**: This slice MUST NOT play a spoken alignment reference and MUST NOT replace lesson audio.
- **FR-017**: This slice MUST NOT add phone-level karaoke. Slice 4 continues to highlight the current **word** only.
- **FR-018**: Shadow-reading assessment take-replay karaoke MUST remain a separate surface and MUST NOT require these new settings.
- **FR-019**: Learners MUST be able to find both controls under Settings (Transcript), see that each is off by default, and have the choices remembered across relaunch.
- **FR-020**: Auto-follow MUST continue to target the line (or echo block in echo mode), not a word.

### Key Entities

- **IPA overlay setting**: A single opt-in learner control (default off) that shows stored pronunciation spelling with each primary-line word that has stored phone pieces.
- **Word-level practice setting**: A single opt-in learner control (default off) that allows seek-to-word, loop-a-word, and inspect-phones when stored timed words exist.
- **Timed word span**: A stored word on a cue that includes a usable start and duration (slice 1 meaning: times relative to the parent line). Untimed words cannot be seek or loop targets.
- **Stored pronunciation pieces**: Ordered phone / pronunciation spellings stored on a word. Overlay concatenates them as that word’s visible spelling; inspect shows them as the chosen word’s piece list. Missing pieces mean no overlay and no inspect content for that word.
- **Chosen word**: The at-most-one timed word the learner is practicing (tapped on a non-selectable row, or the current timed word via the selectable-row practice action).
- **Current timed word**: The at-most-one timed word on the current primary cue whose stored time window contains the current playback position (same meaning karaoke uses for highlight).
- **Word loop**: A temporary playback overlay that repeats the chosen word’s stored media window until cancelled. Distinct from the echo region.
- **Phone inspect**: On-demand ordered view of stored pronunciation pieces for the chosen word. Complements overlay (reading-time spelling on every eligible word).
- **Line-only cue**: A cue with no usable timed words and no stored phones. This slice never splits it into word targets or IPA.
- **Line identity**: Line text and line times (and the existing translation fingerprint when present) used by current-line, echo, blur, lookup, and auto-translate. Unchanged by this slice. Lookup text excludes pronunciation spelling.
- **Karaoke setting**: Slice 4’s separate control for in-place word highlight. Not a prerequisite for overlay or word practice.
- **Enrichment setting**: Slice 3’s separate control for whether Craft **save** stores nested timings. Not a prerequisite for showing or practicing items that already have those timings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With both new controls at default (off), on a curated set of at least 10 transcripts (import, YouTube captions, speech-to-text, Craft line-only, and at least one Craft item with nested word timings and phones), 0 cues show pronunciation spelling; 0 taps seek to a word; 0 word loops start; 0 inspect surfaces appear; 100% keep today’s line-level tap-to-seek, lookup, echo, karaoke, and blur behavior.
- **SC-002**: Learners can find both controls in Settings → Transcript; a fresh profile shows each **off**; a changed value is still there after relaunch; the next playback honors it without restart.
- **SC-003**: With IPA overlay on and a visible cue of at least 3 words that have stored phones plus at least 1 word that does not, **100%** of words with stored phones show that stored spelling with the word; **0** words without stored phones show invented IPA; **0** line-only cues in the set gain a fake IPA split.
- **SC-004**: With IPA overlay on, dictionary lookup on selectable rows still submits transcript text (not pronunciation spelling) in **100%** of sampled selections. With overlay on and word-level practice off, **100%** of taps on non-selectable nested rows still seek to the **line**.
- **SC-005**: With word-level practice on and a non-selectable cue of at least 3 timed words, tapping each timed word seeks into that word’s stored media window for **100%** of those words; tapping timestamp/chrome still seeks to the line; 0 of those taps open dictionary lookup.
- **SC-006**: With word-level practice on, 100% of selectable (active/echo) rows in the same set keep today’s selection and lookup; 0 of those rows treat a text tap as seek-to-word.
- **SC-007**: With word-level practice on, looping a timed word repeats that **one** word’s window until cancel on **100%** of sampled words; 0 loops rewrite echo membership; cancel restores ordinary play or echo.
- **SC-008**: For timed words that store phones, inspect shows those stored pieces for that word only, in order. For words with no phones, 0 invented IPA strings and 0 alignment runs.
- **SC-009**: With either new control on and blur on, the active cue stays blurred until hover/hold (0 auto-reveals; 0 IPA leaks through blur). With a translation line visible, 0 IPA overlay or word seek/loop/inspect actions apply to the translation line.
- **SC-010**: Turning either new control on does not change stored transcripts (0 library rewrites). Craft save still follows slice 3. Karaoke still follows slice 4. 0 alignment runs and 0 IPA-generation runs start from opening, playing, tapping, or toggling overlay.
- **SC-011**: On a typical enriched item (about **60 s** or less, on the order of **100** lines or fewer), with overlay on, the transcript remains scrollable and current-line tracking still updates. With practice on, tapping a timed word feels immediate (seek without waiting for the next line change).

## Assumptions

- This slice consumes nested **phones** for display and nested **word times** for interaction. Karaoke (slice 4) remains paint-only highlight unless word-level practice is also on.
- IPA overlay and word-level practice are **persisted preferences** (Settings → Transcript), not per-media practice modes like echo or blur. Each applies across items until the learner turns it off.
- **Two** settings, independent of karaoke, is the default: learners may want to read IPA without changing tap behavior, or tap/loop without crowding the line with spelling, or both.
- Overlay uses **stored** phone spellings only. It does not phonemize line-only captions. That remaining [#527](https://github.com/baizhiheizi/enjoy_player/issues/527) path (wordlists / cloud phonemizer for tracks without nested phones) stays out of this spec.
- Pronunciation spelling is attached **per word** on the primary line (secondary spelling with the word). Exact typography is a plan-time choice; it must not become a third translation line and must not enter lookup text.
- Dictionary lookup on active and echo rows is more important than tap-to-word on those rows. Seek-to-word is therefore limited to non-selectable nested rows; loop/inspect on the playing word uses a separate practice action.
- Word loop is a mini repeat of one stored window, not a new echo session and not a rewrite of echo expand/shrink.
- Inspect is the ordered phone list for one chosen word. Overlay is reading-time spelling on every eligible word. Both may be on together without duplicating a blocking UI.
- Neither control requires Craft enrichment to be on at play time. They only need stored phones (overlay) or stored timed words (practice) on the cue.
- Word windows use the slice 1 meaning (start/duration relative to the parent line). Playback position is on the media timeline; a word’s media window is `[line start + word start, line start + word start + word duration)`.
- Exact Settings copy belongs in localization during implementation.
- Quiet degradation (no blocking error) when nested data is missing or incomplete. Diagnostic logging may record why a cue has no overlay or word targets; a toast is not required.
- Focus learning languages and alignment quality remain slice 3’s problem. This slice does not repair bad timings or bad IPA; it only shows, seeks, loops, and inspects what is stored.
- YouTube WebView items stay caption-line-only unless some later slice stores word times or phones on them.

## Dependencies

- Relies on slice 1 nested cue meaning ([036](../036-transcript-nested-timeline/spec.md), [ADR-0070](../../docs/decisions/0070-nested-transcript-timeline.md)), including optional phone / pronunciation pieces on words.
- Relies on items that already have nested word timings and/or phones, typically from slice 3 Craft enrichment ([039](../039-craft-timeline-enrichment/spec.md), [ADR-0073](../../docs/decisions/0073-craft-timeline-enrichment.md)). It does not require calling the alignment engine at play, tap, or overlay-toggle time.
- Relies on slice 4 karaoke remaining a display-only word-highlight preference ([040](../040-karaoke-word-highlight/spec.md), [ADR-0074](../../docs/decisions/0074-karaoke-word-highlight.md)). This slice must not regress karaoke’s default-off highlight contract.
- Relies on existing transcript panel contracts in [docs/features/transcript.md](../../docs/features/transcript.md): current line, tap-to-seek, echo, blur (active line stays blurred), lookup, auto-translate.
- Relies on dictionary lookup remaining the primary interaction on selectable rows ([docs/features/dictionary-lookup.md](../../docs/features/dictionary-lookup.md), [ADR-0019](../../docs/decisions/0019-transcript-dictionary-lookup.md)), with lookup text still the transcript string.
- Must not change shadow-reading assessment take-replay karaoke documented in [docs/features/shadow-reading.md](../../docs/features/shadow-reading.md).
- Absorbs the **stored-phone display** portion of [#527](https://github.com/baizhiheizi/enjoy_player/issues/527). It does not absorb generating IPA for tracks without nested phones.
- Must update [docs/features/transcript.md](../../docs/features/transcript.md) (and Settings copy if the Transcript section gains rows) when this behavior ships.
- A new ADR (expected 0075) belongs at plan time, not in this specify step. Do not rewrite ADR-0070–0074.
