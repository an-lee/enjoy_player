# Feature Specification: Craft Shadow-Friendly Transcript Cues

**Feature Branch**: `032-craft-shadow-cues`

**Created**: 2026-07-30

**Status**: Draft

**Input**: User description: "Let's do #1 [wire WordBoundary in the iOS/macOS native plugin]. And also improve the flow. The current result from the word boundary is not perfect. We should make the lines friendly to shadow."

## Scope

### In scope

- Extend timed-transcript coverage to **iOS and macOS** for the Enjoy default TTS path so Craft items built on Apple devices receive word-boundary-driven cues instead of a blank transcript.
- Rework Craft transcript segmentation so saved lines are sized and placed for **shadow-reading practice**: each line is a repeatable phrase that breaks at natural speech boundaries (sentence ends, clause ends, and inter-word pauses), caps to a shadow-friendly duration, and avoids orphaned single-word or punctuation-only lines.
- Apply the improved segmentation **across all platforms** that already supply word boundaries (Android, Windows) so every learner benefits, not only Apple users.
- Respect clause and phrase punctuation (commas, semicolons, em-dashes, CJK full-width punctuation) as break candidates, not only sentence-ending marks.
- Keep the learner's crafted practice text as the transcript wording (no STT substitution at save).
- Preserve the existing blank-transcript-then-STT fallback for paths that genuinely cannot supply word boundaries (BYOK OpenAI TTS, Linux).

### Out of scope

- **Forced alignment** (local or cloud) re-timing known text against audio with a dedicated aligner — remains deferred; this feature relies solely on synthesis-provided word boundaries.
- **Linux native TTS plugin work** — Linux has no Azure Speech native plugin; it continues to save blank transcripts and rely on player STT.
- **BYOK OpenAI TTS word boundaries** — the OpenAI `/audio/speech` path does not return word timing; it stays blank + STT.
- **Changing the default Craft TTS provider** or adding new TTS vendors.
- **Changing the saved transcript storage schema** (`transcripts.timelineJson` remains a `[{text, start, duration}]` array).
- **Echo-mode interaction redesign** — echo simply consumes the improved cues.
- **Phoneme-level or token-level alignment** — this feature targets word-grouped phrase lines only.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Apple learners get timed cues on save (Priority: P1)

A learner on an iPhone, iPad, or Mac uses Express or Advanced Craft with the Enjoy default (Azure-backed) TTS. After they save, the item opens in the player **with a timed transcript already present** — lines highlight in sync with playback. They no longer land on a blank transcript panel and no longer need to generate cues via speech-to-text just to start practicing.

**Why this priority**: Today every Apple-platform Craft save produces a blank transcript (ADR-0063), forcing an extra STT step before shadow or echo practice can begin. Closing this gap is the single highest-leverage fix — it turns Apple from "blank by default" into "ready to practice."

**Independent Test**: On an iOS or macOS device, Craft a short multi-sentence paragraph (≥2 sentences) using Enjoy default TTS; save and open in the player; verify the transcript panel shows multiple timed lines that highlight during playback (not the empty/generate state).

**Acceptance Scenarios**:

1. **Given** an iOS or macOS device using Enjoy default TTS, **When** the learner saves a Craft item from a multi-sentence paragraph, **Then** the saved transcript contains ≥1 timed line (non-blank primary transcript) and the player transcript panel is not the empty/generate state.
2. **Given** the Azure Speech SDK fires word-boundary events during synthesis on iOS/macOS, **When** Craft builds the saved transcript, **Then** each word boundary's start and duration map into the saved timeline so playback highlighting tracks the spoken words.
3. **Given** a learner who previously had to run STT after every Apple Craft save, **When** they Craft the same text after this feature, **Then** they can begin shadow or echo practice immediately without any speech-to-text step.
4. **Given** synthesis completes but the SDK returns zero word boundaries on Apple (edge failure), **When** Craft saves, **Then** the item saves with a blank transcript and the player offers the Generate affordance (graceful fallback, no save failure).

---

### User Story 2 - Lines break at shadow-friendly sizes (Priority: P1)

A learner practices shadow reading with any Craft item that has timed cues (Android, Windows, or the new Apple path). Each transcript line is a **repeatable phrase**: short enough to hold in working memory and repeat after the speaker, and broken at a natural speech boundary. Long sentences split into phrase-sized pieces at clause ends or pause points; short sentences stay whole. The learner never sees a single line that runs on for 10+ seconds, nor an orphaned lone word.

**Why this priority**: Shadow reading depends on line length matching what a learner can echo in one breath. The current fixed 6-word chunks ignore audio duration and natural pauses, so lines are often too long to shadow or cut mid-phrase. This is the core quality complaint with today's synthesis cues.

**Independent Test**: Craft a paragraph with one long multi-clause sentence and one short sentence; save on any platform with word boundaries; open the transcript and verify the long sentence is split into ≤2 shadow-friendly lines at a clause/pause boundary while the short sentence stays as one line.

**Acceptance Scenarios**:

1. **Given** a Craft paragraph whose longest spoken sentence exceeds a shadow-friendly duration, **When** the transcript is segmented, **Then** that sentence is split into two or more lines, each within the target shadow-friendly duration range.
2. **Given** a short single-sentence Craft item, **When** the transcript is segmented, **Then** it forms one line (not split into single-word fragments) as long as it is within the target range.
3. **Given** inter-word silence gaps in the word-boundary data, **When** a long sentence is split, **Then** the system prefers breaking at the largest natural pause within the target window over an arbitrary mid-phrase word-count cut.
4. **Given** any segmented Craft transcript with solid timings, **When** lines are reviewed, **Then** no line is shorter than a minimum useful shadow duration as a standalone line (adjacent short fragments merge into a neighbor).

---

### User Story 3 - Clause and phrase punctuation guide breaks (Priority: P2)

A learner Crafts text that uses commas, semicolons, colons, em-dashes, or CJK full-width punctuation (、，；：) to mark clauses. The transcript breaks at these clause boundaries when they fall within the shadow-friendly window, so each line corresponds to a complete thought-unit rather than a fragment that splits a clause in two.

**Why this priority**: Sentences break at breath and thought boundaries; honoring clause punctuation produces more natural shadow units than sentence-only or count-only splitting. This lifts quality for all languages, especially CJK where clauses are the primary structural unit.

**Independent Test**: Craft a Chinese or Japanese paragraph with multiple full-width comma-separated clauses; save with word boundaries; verify lines break at the full-width commas when doing so keeps each line within the shadow-friendly duration.

**Acceptance Scenarios**:

1. **Given** Craft text containing clause-level punctuation (commas, semicolons, colons, em-dashes, or CJK equivalents), **When** the transcript is segmented, **Then** the system treats those marks as preferred break candidates inside a long sentence.
2. **Given** CJK text using full-width clause punctuation (`、，；：`), **When** segmented, **Then** line breaks align with those clause marks when within the shadow-friendly window, rather than applying a Latin word-count rule that does not fit spaceless scripts.
3. **Given** a clause punctuation mark adjacent to a sentence-ending mark, **When** segmented, **Then** sentence-ending marks still take priority and no line begins with punctuation-only text.

---

### User Story 4 - Timing accurately frames each phrase (Priority: P2)

A learner shadow-reads a Craft item. Each transcript line's start time marks when its first word is spoken and its end time marks when its last word finishes, so the highlight appears exactly when the learner should begin repeating. There is no drift where a line highlights well before or after its words sound.

**Why this priority**: Shadow reading requires precise cue onset; if a line's timing is off by more than a fraction of a second the learner loses sync. Accurate word-boundary-to-line mapping is what makes the cues trustworthy.

**Independent Test**: Craft a paragraph; play it back while watching the transcript; confirm each line highlights at the moment its first word is heard and stops as the last word ends.

**Acceptance Scenarios**:

1. **Given** word-boundary start/duration data from synthesis, **When** lines are built, **Then** each line's start equals the first word's onset and its end equals the last word's release (duration spans the actual spoken span).
2. **Given** a pause between two lines, **When** the transcript plays, **Then** the first line's end does not artificially extend across the silence into the next line's words.

---

### Edge Cases

- **One long unpunctuated sentence**: with solid timings, split by inter-word pause gaps and the shadow-friendly duration cap; avoid single-word lines by merging.
- **Very short text (single short sentence)**: stays one line; the existing Craft minimum-length validation still applies.
- **Abbreviations and decimals** (`Mr.`, `U.S.`, `3.14`): must not create false clause/sentence breaks more often than prior behavior; residual edge cases documented in Assumptions.
- **CJK text with no clause punctuation**: split by the duration cap and available character-level word boundaries; full-width sentence punctuation (`。！？`) treated as sentence ends.
- **Word boundaries with overlapping or zero-duration tokens**: merged punctuation tokens extend the prior word's span; zero-duration words do not produce zero-duration lines.
- **Re-synthesize with a different voice after editing text**: rebuild the transcript from the new word boundaries using the improved segmentation; fall back to blank if the new save lacks solid timings.
- **BYOK OpenAI TTS (no word boundaries)**: unchanged — blank transcript; learner generates via STT in the player.
- **Linux (no native TTS plugin)**: unchanged — blank transcript; learner generates via STT.
- **Azure SDK returns zero boundaries on Apple (rare)**: graceful fallback to blank transcript + player Generate affordance; save still succeeds.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: On iOS and macOS, the Enjoy default TTS synthesis path MUST capture word-boundary timing events from the Azure Speech SDK and return them to Craft so a timed transcript can be built, replacing the current empty-boundary behavior.
- **FR-002**: When synthesis returns solid word boundaries on iOS/macOS, Craft MUST save a primary timed transcript (non-blank); when zero boundaries are returned, Craft MUST fall back to the blank-transcript policy (audio saves, no timed lines, player offers Generate).
- **FR-003**: The transcript segmenter MUST produce lines sized for shadow reading: each line's spoken duration MUST stay within a defined shadow-friendly target range (minimum and maximum), splitting long sentences and merging too-short fragments.
- **FR-004**: When splitting a long sentence, the segmenter MUST prefer natural speech boundaries in this priority order: sentence-ending punctuation, then clause/phrase punctuation, then the largest inter-word silence gap, then a maximum-duration cap — over arbitrary fixed word-count cuts.
- **FR-005**: The segmenter MUST treat clause-level punctuation — including commas, semicolons, colons, em-dashes, and CJK full-width equivalents (`、，；：`) — as valid break candidates inside a sentence.
- **FR-006**: For CJK text (no inter-word spaces), the segmenter MUST break by punctuation and duration rather than by a Latin word-count rule.
- **FR-007**: No saved transcript line MAY begin with punctuation-only text (sentence-ending or clause marks attach to the preceding line/word).
- **FR-008**: Each line's start time MUST equal its first word boundary's onset and its end time MUST equal its last word boundary's release, spanning only the spoken duration of that line's words.
- **FR-009**: The improved segmentation MUST apply uniformly on all platforms that supply word boundaries (Android, Windows, iOS, macOS).
- **FR-010**: Craft MUST keep the learner's crafted practice text as the transcript wording (no STT substitution at save) whenever a synthesis-built transcript is saved.
- **FR-011**: A synthesis transcript is solid only when word boundaries are non-empty and the segmenter emits ≥1 valid line; otherwise the blank-transcript policy applies. This gate MUST be unchanged from ADR-0063.
- **FR-012**: Forced alignment MUST NOT be required for this feature.
- **FR-013**: The feature MUST NOT change the saved transcript storage format (`transcripts.timelineJson` remains a `[{text, start, duration}]` array), Craft audio storage identity, or Craft badge behavior.

### Key Entities

- **Craft practice text**: The learning-language text the learner confirmed before synthesis. Source of transcript wording when a synthesis-built transcript is saved.
- **Synthesis word boundaries**: Ordered spoken units, each with a start time and duration, from the TTS path. The raw timing input for segmentation. Includes standalone punctuation tokens on some platforms.
- **Shadow-friendly line**: A transcript segment whose spoken duration falls within the target repeatable range and whose boundaries follow a natural speech break (sentence end, clause end, or pause).
- **Solid timed transcript**: A primary transcript saved only when word boundaries are non-empty and the segmenter emits ≥1 valid line. Otherwise the transcript is blank (ADR-0063).
- **Blank transcript**: Craft media with playable audio and no primary timed lines; learner fills via player STT. Unchanged fallback for BYOK OpenAI TTS and Linux.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a fixed set of ≥10 multi-sentence Craft samples synthesized with Enjoy default TTS on **iOS** and **macOS**, **100%** of saves produce a non-blank primary timed transcript (≥1 timed line), versus **0%** before this feature.
- **SC-002**: On a fixed set of ≥10 Craft samples (all platforms with word boundaries) including at least one long multi-clause sentence per sample, **≥90%** of transcript lines fall within the defined shadow-friendly duration range (no line exceeds the maximum, no standalone line falls below the minimum).
- **SC-003**: On a fixed set of ≥5 Craft samples containing clause-level punctuation (Latin and CJK), **≥80%** of within-sentence splits occur at a clause mark or at the largest inter-word pause, rather than at an arbitrary mid-phrase word boundary.
- **SC-004**: On that same sample set, **100%** of saved transcript lines have non-empty text that does not start with punctuation-only characters from the set `.,;:!?。、，；：！？`.
- **SC-005**: In moderated usability checks with ≥5 learners familiar with Craft shadow reading, **≥4** report that the improved line sizes let them echo each line in one attempt without losing sync, on a sample with mixed short and long sentences.
- **SC-006**: Craft save latency for typical short paragraphs (under ~500 characters) does not regress by more than **10%** wall time versus the prior builder on the same device class.
- **SC-007**: Zero Craft save failures introduced by the new word-boundary capture or segmentation across automated tests covering Apple-boundary capture, shadow-friendly sizing, clause breaking, CJK handling, and blank-when-not-solid fallback.

## Assumptions

- The Azure Speech SDK Swift binding for iOS/macOS exposes a word-boundary event handler in the version the app depends on; if the bound API differs, the plan resolves the exact handler signature. The SDK is the same one already used for assessment and synthesis on Apple platforms.
- Enjoy's default Craft TTS remains the current Azure-backed Enjoy path; this feature extends boundary capture and improves segmentation, not vendor switching.
- Shadow-friendly target duration is informed by shadow-reading pedagogy (a phrase a learner can repeat in one breath); exact min/max values are confirmed during planning (working assumption: roughly 1.5–6 seconds per line).
- CJK "word" boundaries from Azure are character- or phrase-level units; segmentation uses punctuation and duration rather than a Latin word count.
- Existing ASR transcript generation for local audio already applies to Craft audio; this feature does not invent a separate ASR product or auto-run STT on save.
- STT generate/replace may change transcript wording relative to crafted text; that trade-off is acceptable when the learner explicitly chooses STT.
- Abbreviations and numeric decimals may still create occasional false breaks when a solid transcript is built; eliminating all linguistic edge cases is not required for v1.
- Forced alignment remains a future option if synthesis cues + STT still fall short for some languages.
- Documentation updates (`docs/features/craft.md` and related) ship with the behavior change per project governance.
- BYOK OpenAI TTS and Linux continue to save blank transcripts; this feature does not add word boundaries to those paths.

## Dependencies

- Existing Craft synthesize → save pipeline (Express and Advanced) and the `word_boundary_segmenter.dart` segmentation path.
- The `azure_speech` native plugin (`packages/azure_speech/`) iOS and macOS implementations, which must subscribe to the SDK's word-boundary event.
- Existing player transcript empty state and subtitle controls (unchanged — still the fallback for blank-transcript items).
- Existing localization pipeline for any new or unchanged strings.
