# Feature Specification: Assessment Recording Playback

**Feature Branch**: `035-assess-recording-playback`

**Created**: 2026-08-06

**Status**: Draft

**Input**: User description: "After the pronounce assessment, in the detail result, we should be able to listen to the playback of the recording. Even better, we have the timestamps of each word, we could implement the karaoke style on the words list. And when user tap a word to show the detail result of the word, we could listen to the standard pronounce (already implemented), and we should be able to listen to the recording clip of that word. So we could know the difference, and improve."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Replay the full assessment take (Priority: P1)

After a pronunciation assessment finishes (or when reopening a saved result), the learner opens the detail result view and wants to hear their own recording again—not only scores and word chips. A clear play/stop control on the result detail plays the full take from the start. While it plays, the control shows a responsive playing state; a second tap stops. Closing or dismissing the result stops playback so audio does not continue in the background.

**Why this priority**: Rehearing the take is the baseline for self-comparison; without full playback, karaoke highlighting and per-word clips have no shared context.

**Independent Test**: Open an assessment result that has a stored take, tap play recording, confirm the full take is audible; tap stop (or dismiss the result) and confirm audio ends.

**Acceptance Scenarios**:

1. **Given** an assessment result detail is open for a take that still has playable recording audio, **When** the learner taps the result’s “play my recording” control, **Then** the full take starts playing from the beginning and the control shows a clear playing state.
2. **Given** the learner’s recording is playing in the result detail, **When** they tap the same control again, **Then** playback stops promptly and the control returns to a ready-to-play state.
3. **Given** recording playback is active, **When** the learner dismisses or closes the assessment result, **Then** playback stops and no take audio continues after the surface is gone.
4. **Given** the take’s audio file is missing or unreadable, **When** the result detail opens, **Then** the play-recording control is unavailable or shows a brief recoverable message, and score/word feedback remain usable.

---

### User Story 2 - Karaoke-style word highlight while the take plays (Priority: P2)

While the full take plays in the result detail, the word list uses each word’s assessment timestamps so the currently spoken word is highlighted in a karaoke-style progression. As playback advances, the highlight moves word by word in sync with the audio. When playback stops or ends, the highlight clears or settles on a neutral state. Words without usable timestamps do not falsely claim to be “current.”

**Why this priority**: Timestamp-driven highlighting turns a static score list into a guided listen-along, making weak spots easier to notice during the full replay.

**Independent Test**: Play a take whose assessment includes per-word timing; watch the word list highlight advance in sync with speech; stop playback and confirm the live highlight ends.

**Acceptance Scenarios**:

1. **Given** a result with per-word timestamps and full-take playback is running, **When** audio reaches a timed word’s interval, **Then** that word is visually emphasized as the current karaoke word and previous words are no longer the active highlight.
2. **Given** karaoke highlighting is active, **When** playback stops or finishes, **Then** the live “current word” highlight ends (no stuck “playing” word).
3. **Given** some words lack usable start/end timing, **When** the take plays through those regions, **Then** the UI does not invent a false current word for them; timed words still highlight when their intervals are reached.
4. **Given** the learner taps a word chip to open word detail while full-take karaoke playback is running, **When** selection changes, **Then** full-take playback behavior remains intentional (either continues with highlight updates, or stops cleanly—see Assumptions); the result never stacks overlapping take audio.

---

### User Story 3 - Compare model pronunciation with my word clip (Priority: P2)

When the learner selects a word chip to open that word’s detail, they can still hear the standard (model) pronunciation as today, and they can also hear just the portion of their recording that corresponds to that word’s timestamps. Side-by-side listening makes the difference obvious so they can improve. Model and own-clip controls are visually distinct so learners do not confuse “how it should sound” with “what I said.” Starting one stops the other (and any full-take playback) so only one learner-facing audio stream plays at a time from this surface.

**Why this priority**: Direct A/B listening on a single word is the highest-value practice loop after scoring; it depends on timestamps but delivers value even without watching a full karaoke pass.

**Independent Test**: Select a timed word in results; play model pronunciation; play my clip for the same word; confirm each plays the expected audio and they do not overlap.

**Acceptance Scenarios**:

1. **Given** a word with usable timestamps is selected in the result detail, **When** the learner taps “play my clip” (or equivalent), **Then** they hear only that word’s portion of their take, not the entire recording.
2. **Given** a word is selected, **When** the learner taps the existing model pronounce control, **Then** they still hear the standard pronunciation for that word (unchanged product intent from word-pronounce).
3. **Given** model pronunciation is playing, **When** the learner starts their word clip (or full-take playback), **Then** the previous stream stops before the new one is heard—no overlapping audio.
4. **Given** the selected word has no usable clip timestamps (omission, silence, or missing timing), **When** the word detail is shown, **Then** “play my clip” is disabled or explains it is unavailable, while model pronounce remains available when that path still works.
5. **Given** the learner selects a different word while a clip or model audio is playing, **When** selection changes, **Then** the previous stream stops and new controls target the newly selected word.

---

### Edge Cases

- Recording deleted or file missing after assessment was saved: scores/word feedback still open; recording play and clips are unavailable with a clear reason.
- Assessment scores saved but word timings empty or partial: full-take play still works when audio exists; karaoke and per-word clips degrade gracefully for words without timing.
- Omitted / skipped words in the assessment: no fake clip interval; clip control unavailable for those words.
- Very short words or near-zero duration intervals: clip play either plays a minimal audible window using the provided timing or is treated as unavailable—never hangs on loading.
- Rapid taps on play/stop or switching between full take, clip, and model: at most one audible stream; UI returns to a coherent idle/playing state.
- Dismiss result, leave shadow-reading panel, or start a new recording while result audio is active: all result-originated take/clip/model playback from this surface stops.
- Re-assess replaces scores/JSON: karaoke and clips follow the latest assessment timings for that take.
- Offline: local take audio and clips still play when the file is on device; model pronounce follows existing online/credits behavior.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The assessment result detail MUST offer a control to play and stop the learner’s full recording take associated with that result, distinct from the model “pronounce” control.
- **FR-002**: Full-take playback MUST start from the beginning of the take by default and MUST stop on user stop, natural end, or when the result surface is dismissed.
- **FR-003**: When per-word timing data is available for the assessment, full-take playback MUST drive a karaoke-style highlight on the words list so the word whose time interval contains the current playback position is emphasized.
- **FR-004**: Karaoke highlighting MUST clear or leave the live current-word state when full-take playback stops or completes.
- **FR-005**: Selecting a word in the result MUST continue to show that word’s detail feedback and MUST keep the existing model pronunciation control for the selected word.
- **FR-006**: For a selected word with usable timing, the result MUST offer a control to play only that word’s interval from the learner’s recording (the word clip).
- **FR-007**: Model pronunciation and learner recording audio (full take or word clip) MUST be clearly distinguishable in labeling and placement so learners can tell “standard” from “my recording.”
- **FR-008**: At most one of model pronunciation, full-take playback, or word-clip playback from the assessment result surface MAY be audible at a time; starting one MUST stop the others.
- **FR-009**: Changing the selected word MUST stop any in-progress model or clip playback tied to the previous word and retarget controls to the new word.
- **FR-010**: When recording audio or word timing is unavailable, the product MUST degrade gracefully: hide or disable the affected play controls with a non-blocking explanation; scores and readable feedback remain available.
- **FR-011**: Play controls for the take and word clip MUST expose accessibility labels / tooltips that distinguish play vs stop and “my recording” vs “standard pronunciation” (localized).
- **FR-012**: Word-clip playback MUST use the assessment’s per-word time bounds for that word; it MUST NOT play an unrelated segment or the entire take unless the word’s interval effectively covers the whole take.

### Key Entities

- **Assessment result**: Saved scoring outcome for one take (aggregate scores plus per-word detail), shown in the detail result surface.
- **Assessment take audio**: The learner’s recorded audio for that take; source for full replay and word clips.
- **Timed assessed word**: A word in the result with optional start/end timing relative to the take, accuracy/feedback fields, and selection state in the UI.
- **Word clip**: The portion of take audio bounded by a timed assessed word’s start and end.
- **Karaoke playback position**: The current time within full-take playback used to choose which timed word is highlighted.
- **Model pronunciation**: Reference speech of the selected word (existing capability); not the learner’s take.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In moderated usability checks, at least 9 of 10 learners find and successfully play their full take from the assessment result on the first try without help.
- **SC-002**: During full-take playback with complete per-word timings, observers agree the karaoke highlight matches the audible word for at least 90% of words in a short practice sentence (subjective sync check on a typical device).
- **SC-003**: For a timed word, learners can play their word clip and the model pronunciation in either order within 30 seconds and correctly identify which control is “mine” vs “standard” in at least 9 of 10 quick preference checks.
- **SC-004**: Zero overlapping audio streams (model + take, or two take streams) in acceptance testing of the result surface across play, stop, word change, and dismiss.
- **SC-005**: Missing audio or missing word timings never block viewing scores; affected play actions are unavailable without a stuck loading state in manual or automated regression of the result surface.
- **SC-006**: From tap to audible start for a local full take or word clip, playback feels immediate: under 1 second on a typical device when the take file is already on disk.

## Assumptions

- Per-word timestamps already available from the pronunciation assessment outcome are sufficient to drive karaoke highlighting and word clips; this feature does not invent a separate timing pipeline.
- “Standard pronounce” on the selected word remains the existing model-pronunciation behavior; this feature adds learner take replay and clips alongside it.
- Default full-take play starts at the beginning (no resume-across-sessions requirement for v1).
- Karaoke highlighting applies while full-take playback is active; tapping a word primarily opens word detail (and enables clip/model listen). Seeking the full take by tapping a word during karaoke is out of scope unless added later.
- When the learner opens word detail during full-take playback, full-take playback **stops** so attention shifts to A/B listening on the selected word (avoids competing highlight vs detail focus).
- Word clips use the assessment-provided interval; no manual trim UI in this slice.
- Out of scope: editing/deleting takes from the result surface, exporting clips, changing assessment scoring, new languages, and playing the source media cue from this surface.
- Interaction pattern matches the product’s tap-to-play / tap-to-stop convention used by model pronounce.
- Result detail means the existing assessment result dialog/sheet after run or when viewing a saved score.
