# Feature Specification: On-Demand Transcript Enrichment

**Feature Branch**: `042-on-demand-transcript-enrichment`

**Created**: 2026-08-17

**Status**: Draft

**Input**: User description: "The karaoke and IPA display should depend on the transcript enrichment. If the transcript don't contain the `words`, `karaoke` and `IPA` switch should be disabled. Instead, we should display a button to do the alignment, generate the words and IPA data. For YT video, we don't own the audio/video, we can't produce the word-level timestamp using the alignment, so the `karaoke` should be disabled for the YT videos. But we could produce the IPA using the alignment related APIs. It means the time information in `transcript.timeline.words` might be optional. Help me to confirm it is feasible, generate the IPA for YT video transcript."

**Source**: Follow-on to issue [#540](https://github.com/baizhiheizi/enjoy_player/issues/540) (nested timeline, alignment, karaoke, IPA) and remaining [#527](https://github.com/baizhiheizi/enjoy_player/issues/527) pronunciation for captions that have no stored phones. Slices 1–5 already let a cue store optional word/phone spans, produce them when extractable audio exists (Craft save), highlight timed words, and show stored IPA. This slice is the **first learner-facing producer outside Craft save**: karaoke and IPA controls follow whether the **current transcript already has nested words**, and a button can generate that nested data on demand. YouTube items cannot gain word times (no owned audio); they **can** gain pronunciation spelling.

## Program split (issue #540)

Each slice MUST be independently shippable: existing transcript, playback, Craft, import, speech-to-text, YouTube captions, echo, lookup, and translation behavior stay intact unless that slice’s opt-in path is explicitly on.

| Slice | Spec | What ships | Why it does not break existing features |
|-------|------|------------|----------------------------------------|
| **1** | [Nested transcript timeline](../036-transcript-nested-timeline/spec.md) | A cue MAY carry optional word/phone spans. Word times MAY be omitted. | Additive storage. |
| **2–2b** | [Alignment engine](../037-alignment-engine/spec.md), [Spoken reference](../038-alignment-spoken-reference/spec.md) | Known text + extractable audio → timed words/phones; spoken rendering of known text also yields pronunciation labels. | Previously unused except Craft save. |
| **3** | [Craft timeline enrichment](../039-craft-timeline-enrichment/spec.md) | Craft save may persist nested timings when alignment succeeds. | Craft path unchanged unless this slice adds a player-side button. |
| **4** | [Karaoke word highlight](../040-karaoke-word-highlight/spec.md) | Opt-in word highlight when the cue has **timed** words. | Off by default; inactive on untimed/line-only cues. |
| **5** | [Word-level practice + IPA overlay](../041-word-level-practice/spec.md) | Opt-in IPA from stored phones; tap IPA to play a **timed** word. | Off by default; no phones → no IPA. |
| **6 (this spec)** | On-demand enrichment | Karaoke / IPA switches follow nested data (and media type). A button generates words + IPA when missing. YouTube: IPA-only words; karaoke stays off. | Switches already exist; they become gated. Generation is explicit, not first-play. |

**Still out of the #540 program:** downloading or demuxing YouTube audio/video, aligning the learner’s shadow-reading recording, replacing lesson playback with a synthetic voice, real-time/streaming alignment, and cross-language alignment.

## Feasibility (YouTube IPA without word times)

**Confirmed feasible** for this product, without owning YouTube audio/video.

| Need | YouTube (WebView / remote, no owned media file) | Owned local / Craft audio or video |
|------|--------------------------------------------------|-------------------------------------|
| Nested **word list** (orthography split of the caption line) | Yes — from known caption text | Yes — from known line text |
| **Pronunciation spelling (IPA)** per word | Yes — from known caption text + language, using the same on-device pronunciation path the alignment capability already uses for a spoken rendering of that text. Display only concatenates stored phone **labels**; it does not need phone clocks on the media timeline. | Yes — same labels, plus clocks when alignment against extractable audio succeeds |
| **Word start/duration** on the media timeline | **No** — alignment that places words on the lesson clock requires extractable audio we do not have and will not download | Yes — per-line alignment of extractable audio |
| **Karaoke** (highlight the spoken word while the lesson plays) | **Must stay off** — no trustworthy word clocks | Available once timed words exist |
| **Tap IPA to play that word** | **Must not seek to a word** — no word window. IPA remains readable. Line-level seek/lookup stay as today. | Available once timed words exist |

Word times on a nested word span are therefore **optional**: a YouTube cue MAY store ordered words with pronunciation and **omit** start/duration (or treat missing/zero duration as untimed). Karaoke and tap-to-play already ignore untimed words. IPA overlay already ignores phone clocks and only needs labels.

This slice does **not** invent a second pronunciation catalog. It reuses the alignment-related pronunciation path on caption text. It does **not** add a YouTube download/demux path.

## Scope (this slice only)

### In scope

- Gate the existing karaoke and IPA switches on the **current primary transcript’s nested data** (and on whether this media can ever have word times).
- When the current primary transcript has **no nested words**, keep both switches **disabled** and show one learner-facing **enrich** control that generates nested word (and pronunciation) data for that transcript.
- For **owned media** with extractable audio and existing line cues: that control runs alignment so successful lines store **timed** words plus pronunciation. Karaoke and IPA can then be turned on.
- For **YouTube / other items without owned extractable audio**: that control generates **untimed** words plus pronunciation from caption text. IPA can then be turned on. Karaoke stays **disabled** for that item even after success.
- Treat nested word start/duration as optional in stored meaning: untimed words are valid; karaoke and tap-IPA-to-play require a usable time window.
- Persist generated nested data onto the current primary transcript without changing line text, line start, or line duration.
- Keep generation **explicit** (the button). Do not align on first play, on seek, or as a silent library-wide backfill.

### Out of scope (this slice)

- Downloading, demuxing, or otherwise extracting YouTube audio/video.
- Changing Craft save’s existing always-on enrichment attempt.
- Changing echo, blur, lookup, auto-translate identity, or line-level tap-to-seek.
- Enabling karaoke on YouTube by faking word clocks (for example spreading the line duration evenly across words).
- Generating IPA from a cloud dictionary, wordlist, or network phonemizer other than the existing on-device alignment-related pronunciation path.
- Aligning the learner’s own recording, streaming alignment, or cross-language alignment.
- Shadow-reading assessment take-replay karaoke.
- A new Settings hub row; controls stay on the existing transcript display surface (CC subtitle sheet).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Switches follow nested words; missing data offers enrich (Priority: P1)

A learner opens the transcript display controls on an item whose current captions are line-only (imported file, speech-to-text, or YouTube captions with no nested words). Karaoke and IPA switches are visible but **disabled** — turning them on would do nothing useful. Instead they see a control that offers to generate word and pronunciation data for this transcript. After a successful run on owned media, both switches become available. They do not have to leave the player or re-import captions.

**Why this priority**: Today karaoke can be toggled on a line-only track (a no-op), and IPA is disabled only when phones are missing — with no way to create them from the panel. Gating plus an explicit generate path is the whole product change.

**Independent Test**: Open a line-only local item and a line-only YouTube item. Confirm both switches disabled and the enrich control present. Do not run enrich yet.

**Acceptance Scenarios**:

1. **Given** the current primary transcript has no nested word spans, **When** the learner opens transcript display controls, **Then** karaoke and IPA switches are disabled and an enrich control is shown.
2. **Given** that same line-only transcript, **When** the learner does not use the enrich control, **Then** the panel stays line-level; no nested data is invented in the background.
3. **Given** a transcript that already has nested words with usable times (typically an enriched Craft item), **When** they open display controls, **Then** karaoke and IPA switches are enabled (IPA still requires stored pronunciation on at least one word) and the enrich control is not required.
4. **Given** karaoke or IPA was previously left **on** in preferences, **When** they open a line-only transcript, **Then** those switches still appear **off/disabled** for this item; the stored preference is not lost for items that already have the needed data.

---

### User Story 2 - Owned media: enrich produces timed words and IPA (Priority: P1)

A learner is practicing a local file or Craft item they own. Captions exist as lines but have no nested words. They tap enrich. When the language is supported and audio can be read, each successful line keeps the same wording and line times, and also stores ordered words with start/duration on that line plus pronunciation pieces. They can then turn karaoke on and follow the spoken word, and turn IPA on to read pronunciation. Tap IPA still plays that word when it has a usable time window.

**Why this priority**: This is the owned-media value: the same nested data Craft save already can store, produced on demand for captions that were never Craft-enriched.

**Independent Test**: On a short local item with a line-only multi-word transcript and extractable audio, run enrich. Reopen display controls: karaoke and IPA enabled. Play with karaoke on; confirm the highlighted word matches stored windows. Turn IPA on; confirm spelling appears and tap-IPA plays that word.

**Acceptance Scenarios**:

1. **Given** owned media, extractable audio, a supported language, and line-only cues, **When** enrich completes successfully, **Then** successful lines keep the same line text/start/duration and store ordered words with usable times plus pronunciation on at least some words.
2. **Given** that successful result, **When** the learner opens display controls, **Then** karaoke is enabled and IPA is enabled if pronunciation pieces exist.
3. **Given** karaoke on after enrich, **When** playback sits inside a timed word, **Then** that word highlights as in slice 4.
4. **Given** IPA on after enrich, **When** a word has stored pronunciation, **Then** that spelling is shown with the word; tapping it plays that word’s stored window (slice 5 contract).
5. **Given** enrich fails or is cancelled, **When** the run ends, **Then** the transcript stays line-only, playback continues, and the learner is not blocked from using the item.

---

### User Story 3 - YouTube: IPA without karaoke (Priority: P1)

A learner opens a YouTube item with captions. They cannot own or extract that audio, so the app must not promise word-level highlight. Karaoke stays disabled before and after enrich. They can still generate pronunciation: enrich splits caption lines into words and stores IPA labels **without** word clocks on the video timeline. After success, IPA can be turned on. Words with IPA are readable. Tapping IPA does not seek to a fake word time. Line tap-to-seek, lookup, echo, and blur stay as today.

**Why this priority**: This is the YouTube-specific contract and the feasibility proof: pronunciation without demux, karaoke honestly off.

**Independent Test**: Open a YouTube item with line-only captions. Confirm karaoke disabled. Run enrich. Confirm nested words exist, at least some have pronunciation, word times are omitted or unusable, IPA switch enables, karaoke stays disabled, IPA overlay shows spelling, tap IPA does not seek to a word.

**Acceptance Scenarios**:

1. **Given** a YouTube (or other non-extractable) item, **When** the learner opens display controls, **Then** karaoke is disabled regardless of the persisted karaoke preference.
2. **Given** that item still has no nested words, **When** they open display controls, **Then** IPA is also disabled and the enrich control is shown.
3. **Given** enrich succeeds on that item, **When** the transcript is loaded again, **Then** cues keep the same line text/start/duration; nested words exist; those words have **no usable media time window**; at least some words have pronunciation labels.
4. **Given** that result, **When** they open display controls, **Then** IPA is enabled and karaoke remains disabled.
5. **Given** IPA on for that YouTube transcript, **When** they view a line with pronunciation, **Then** spelling appears with the words; tapping IPA does not seek or loop a word; tapping a non-active line still seeks to the **line**.
6. **Given** enrich is offered on YouTube, **When** it runs, **Then** the product does not download or demux the YouTube media file.

---

### User Story 4 - Partial data, mixed library, and safe degradation (Priority: P1)

A learner’s library mixes Craft-enriched items, line-only imports, YouTube captions, and a transcript that has words but no phones (or phones but no times). Controls follow **this** primary track and **this** media type. Incomplete nested data never blanks a line or blocks playback. Re-running enrich is not required once the data this media type can produce is already present.

**Why this priority**: Most items stay line-only until the learner asks. Wrong gating (karaoke on YouTube, IPA on with no phones, enrich that rewrites line times) would break daily practice.

**Independent Test**: Cycle through (a) enriched Craft with timed words + phones, (b) line-only import, (c) YouTube after IPA-only enrich, (d) a fixture with words but zero duration. Confirm switch enablement and that (d) does not karaoke.

**Acceptance Scenarios**:

1. **Given** nested words with no usable times, **When** karaoke would otherwise be allowed by preference, **Then** karaoke stays disabled (or is a visual no-op with the switch disabled) because there is nothing to highlight.
2. **Given** nested words with no pronunciation pieces, **When** the learner opens display controls, **Then** IPA stays disabled; karaoke is enabled only if usable times exist and the media is not YouTube.
3. **Given** some lines enriched and some still line-only after a partial run, **When** the track loads, **Then** every line still displays; enriched lines may karaoke/IPA; line-only lines stay line-level.
4. **Given** the primary track already has the nested data this media type can produce, **When** they open display controls, **Then** the enrich control is not shown as a required next step (optional re-run is not required in this slice).
5. **Given** unreadable nested data on one cue, **When** the track loads, **Then** that cue degrades to line-only and the rest of the transcript still loads.

---

### Edge Cases

- **No transcript / empty track**: Display switches and enrich are not offered as if nested words existed. Empty-state transcript actions (import, extract, AI transcript) stay as today.
- **Language unsupported** by the pronunciation/alignment path: Enrich fails clearly enough to retry later; the transcript is not rewritten; karaoke/IPA stay disabled.
- **Very long YouTube captions**: Enrich MUST NOT freeze playback or the rest of the app. The learner can cancel. Partial success MAY keep words/IPA on completed lines and leave the rest line-only.
- **Very long local files**: Prefer per-line work against existing cue windows; do not require one whole-file pass over a multi-minute file (same bar as slice 2).
- **Secondary / translation track**: Enrich and IPA/karaoke apply to the **primary** practice transcript only.
- **Blur**: IPA MUST NOT auto-reveal a blurred cue (slice 5). Enrich does not change blur.
- **Markup in line text**: Nested word text should still correspond to readable caption text; a mismatch MUST NOT blank the line.
- **Evenly faked word times**: Forbidden on YouTube (and on any item without extractable audio). Untimed is honest; fake clocks would karaoke against the wrong speech.
- **Phone clocks on YouTube**: Pronunciation labels MAY be stored with omitted or unused phone times. Overlay must not require those clocks.
- **Switch preference vs this item**: A global “karaoke on” preference does not force karaoke chrome on YouTube or on line-only tracks.
- **Craft item already nested from save**: No extra enrich step required; switches behave as after a successful owned-media enrich.
- **Remote non-YouTube media** without a local file: Treat like YouTube for karaoke (disabled) and for enrich (IPA-only if caption text exists; no demux).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Karaoke and IPA display controls MUST remain on the existing transcript display surface (CC subtitle sheet). This slice MUST NOT move them back to a Settings hub section.
- **FR-002**: The karaoke control MUST be enabled only when the current primary transcript has at least one nested word with a **usable time window** AND the current item is one for which word times can be trusted (owned extractable media). YouTube and other non-extractable items MUST keep karaoke disabled even if nested words exist.
- **FR-003**: The IPA control MUST be enabled only when the current primary transcript has at least one nested word with stored pronunciation pieces. Word times MUST NOT be required for IPA enablement.
- **FR-004**: When the current primary transcript has no nested word spans, both karaoke and IPA MUST be disabled, and the product MUST show one enrich control that generates nested word and pronunciation data for that transcript.
- **FR-005**: Enrich MUST be explicit (learner-initiated). Opening, playing, seeking, or toggling karaoke/IPA MUST NOT start enrich.
- **FR-006**: For owned media with extractable audio, existing line cues, and a supported language, enrich MUST align each line’s text to that line’s audio window and, on success, persist ordered nested words with usable start/duration plus pronunciation pieces, without changing line text, line start, or line duration.
- **FR-007**: For YouTube and other items without extractable audio, enrich MUST NOT attempt to produce word times on the media timeline and MUST NOT download or demux the remote media. On success it MUST persist ordered nested words from caption text with optional/omitted times and stored pronunciation labels.
- **FR-008**: Nested word start/duration MUST be optional in stored meaning. A word with missing times or non-positive duration is valid and MUST NOT be treated as a karaoke or tap-to-play target. Writers MUST NOT persist dummy clocks (including evenly split line duration) to simulate karaoke on non-extractable media.
- **FR-009**: IPA overlay MUST display stored pronunciation for words that have labels even when those words (and their phones) have no usable media times. Tap-IPA-to-play MUST apply only when that word has a usable time window; otherwise IPA is read-only.
- **FR-010**: Enrich MUST persist onto the current primary transcript in place. It MUST NOT create a duplicate track, MUST NOT change cue identity (line text and line times), and MUST NOT rewrite echo, blur, lookup, or auto-translate identity rules.
- **FR-011**: Enrich failure, unsupported language, cancel, and timeout MUST leave the previous transcript intact (or keep already-completed lines if a partial write was already committed) and MUST NOT block playback. The learner MUST be able to retry.
- **FR-012**: While enrich runs, the rest of the app MUST stay usable (playback and transport still respond). The learner MUST be able to cancel an in-flight run.
- **FR-013**: After a successful owned-media enrich, karaoke and IPA enablement MUST follow FR-002 and FR-003 without requiring an app restart.
- **FR-014**: After a successful YouTube (IPA-only) enrich, IPA MUST become enableable and karaoke MUST remain disabled.
- **FR-015**: This slice MUST NOT enable karaoke on YouTube, MUST NOT add a YouTube extract path, and MUST NOT replace lesson audio with a spoken reference.
- **FR-016**: Line-only cues, incomplete nested data, and unreadable nested data MUST keep today’s line-level presentation for that cue. Enrich MUST NOT blank the transcript if some lines fail.
- **FR-017**: A persisted karaoke or IPA preference MUST NOT force those features on for an item whose current transcript cannot support them. When the learner later opens an item that can support them, the preference MAY apply again.
- **FR-018**: Secondary/translation text MUST stay line-level for karaoke, IPA, and enrich in this slice.

### Key Entities

- **Nested word span**: An ordered word on a cue (`timeline` entry). Requires display text. **May** include start/duration relative to the parent line. **May** include pronunciation pieces. Absence of the whole list means a line-only cue.
- **Timed word**: A nested word with a usable time window (positive duration, overlapping the parent line). Required for karaoke and tap-IPA-to-play.
- **Untimed word**: A nested word without a usable time window. Valid for IPA display. Invalid as a karaoke or word-seek target.
- **Pronunciation pieces**: Stored phone / IPA labels on a word. Sufficient for IPA overlay. Their own clocks are optional for display.
- **Enrich control**: The learner-facing action that generates nested words (and pronunciation) for the current primary transcript when they are missing.
- **Owned extractable media**: Local or Craft items whose audio/video the app can read for alignment. Word times are possible.
- **Non-extractable media**: YouTube WebView playback and other remote items without a local media file. Word times are not possible; IPA-only nested words are possible.
- **Karaoke control / IPA control**: Existing opt-in display switches. This slice changes **when they are available**, not their default-off preference or their visual contracts when enabled.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a curated set of at least 8 line-only transcripts (import, speech-to-text, YouTube captions, un-enriched Craft/local), 100% show karaoke and IPA **disabled** in display controls, and 100% show the enrich control, before any enrich run.
- **SC-002**: On at least 2 already-enriched owned items (timed words + pronunciation), 100% show karaoke enabled and IPA enabled; 0 require enrich as a blocking next step.
- **SC-003**: After one successful enrich of a short owned item (about **60 s** or less, at least 2 lines and 2 words), 100% of lines keep prior line text/start/duration; 100% of successful lines have nested words with usable times; at least one word has pronunciation; karaoke highlight matches stored windows for **at least 95%** of sampled positions at 1× (same bar as slice 4).
- **SC-004**: After one successful enrich of a YouTube (or equivalent remote) caption track with at least 3 lines, 100% of lines keep prior line text/start/duration; nested words exist; **0** nested words have a usable media time window invented for karaoke; at least one word shows IPA when the overlay is on; karaoke remains disabled; tap IPA never seeks to a word; the app does not save a copy of the YouTube video or audio in order to generate pronunciation.
- **SC-005**: Learners can complete an enrich request and then enable the newly available switch(es) without restarting the app. A cancelled or failed enrich leaves the previous captions playable in **under 2 seconds** of UI recovery (no stuck spinner that blocks the player).
- **SC-006**: With karaoke preference left on, opening a YouTube item still shows **0** in-line word highlights. Opening a timed enriched item still highlights when the switch is enabled.
- **SC-007**: Side-by-side with the pre-feature build, echo, lookup, blur, auto-translate, and line tap-to-seek keep line-level identity on the same fixtures when enrich has not run; after enrich, those behaviors still use line text and line times (0 identity regressions).
- **SC-008**: While enrich runs on a typical practice item (about **60 s** owned, or a YouTube caption set on the order of **100** lines or fewer), transport remains responsive, captions stay visible, and the learner can cancel. YouTube IPA-only enrich of that caption size completes in time a learner will wait (**under 15 s** on a current mid-range device, documented if slower on a given platform).

## Assumptions

- **YouTube IPA is feasible** without owned audio because (1) captions already supply known line text and language, (2) the existing alignment-related spoken-rendering path already produces per-word pronunciation labels from text, and (3) IPA overlay already displays those labels without needing phone or word clocks. This spec treats that combination as sufficient; it does not require a new cloud phonemizer.
- Word times were already optional in slice 1 meaning (“MAY have start/duration”). This slice makes that optionality **product-visible**: YouTube writes untimed words on purpose; karaoke/IPA gating and tap-to-play distinguish timed vs untimed.
- Persisting `0` duration is equivalent to omitted times for “not a karaoke target.” New YouTube writes SHOULD omit times rather than store placeholder clocks that could be mistaken for real alignment.
- Enrich writes the current **primary** track in place (same pattern as Craft enrichment attaching nested JSON to existing lines). A new track type is unnecessary.
- Enrich is **not** a library-wide backfill and **not** first-play. Learners who never tap it keep today’s line-only YouTube and import experience.
- Karaoke and IPA remain **opt-in display preferences** (default off) when enabled. Gating disables the switch for unsupported items; it does not invert the default to on after enrich.
- Fake word times (equal split of the line) are worse than no karaoke on YouTube; they would highlight the wrong word against real speech.
- Tap-IPA-to-play on untimed words stays inert rather than seeking to the line, so IPA tap does not surprise-seek during lookup or reading.
- Exact button copy belongs in localization during implementation. The control should make YouTube’s outcome honest (pronunciation, not karaoke) without a second hidden settings page.
- Supported languages remain the app’s current focus learning languages for this pronunciation/alignment path. Unsupported language is a failed enrich, not a silent other-language voice.
- Quiet-enough failure: a retryable status on the same display surface is enough; a blocking modal that prevents playback is not.
- Craft save enrichment stays as today. This slice does not require turning that off, and does not require showing enrich on items that already have nested words from save.
- Remote non-YouTube items without a local file follow the YouTube contract (no karaoke, IPA-only enrich if captions exist).
- Shadow-reading assessment karaoke stays a separate surface.

## Dependencies

- Relies on slice 1 nested cue meaning ([036](../036-transcript-nested-timeline/spec.md), [ADR-0070](../../docs/decisions/0070-nested-transcript-timeline.md)), including optional word times and optional phones.
- Relies on the alignment capability and spoken-reference pronunciation path ([037](../037-alignment-engine/spec.md), [038](../038-alignment-spoken-reference/spec.md)) for owned-media timed enrich and for text-only pronunciation labels.
- Relies on karaoke ([040](../040-karaoke-word-highlight/spec.md), [ADR-0074](../../docs/decisions/0074-karaoke-word-highlight.md)) already ignoring untimed words, and IPA overlay ([041](../041-word-level-practice/spec.md), [ADR-0076](../../docs/decisions/0076-stacked-ipa-player-controls.md)) already rendering labels without clocks.
- Relies on existing “no extractable audio” treatment of YouTube WebView ([037](../037-alignment-engine/spec.md) FR-010). This slice MUST NOT reverse that.
- Must update [docs/features/transcript.md](../../docs/features/transcript.md) when this behavior ships. A new or superseding ADR is expected if the YouTube IPA-only nested shape (untimed words) is treated as a lasting storage contract.
- Remaining #527 work (cloud dictionary / third-party G2P for languages the on-device path cannot pronounce) stays out of this slice.
