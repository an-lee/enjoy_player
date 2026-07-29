# Feature Specification: Word Pronounce Playback

**Feature Branch**: `031-word-pronounce`

**Created**: 2026-07-30

**Status**: Draft

**Input**: User description: "Now let's implement it pronounce feature in the flutter client. In the lookup panel, flashcard, and the pronounce assessment result panel, user should be able to pronounce the words. Help me to well design the location of the button. Click to play, responsive, graceful."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Hear a looked-up word (Priority: P1)

A learner selects a word or short phrase in a transcript and opens the lookup panel. Next to the selected term (with the other header actions), they tap a clear “hear pronunciation” control. Playback starts quickly; while audio is loading or playing, the control shows responsive feedback so the tap never feels dead. They can tap again to stop. If they are signed out or out of credits when a new pronunciation must be generated, they see the same friendly auth/credits guidance used elsewhere in lookup—not a cryptic failure.

**Why this priority**: Lookup is the highest-frequency learning moment; hearing the selection immediately after looking it up is the core value of this feature.

**Independent Test**: Open lookup on any supported selection, tap the pronounce control, confirm audio plays for that term and the control returns to a ready state; repeat with a previously heard term and confirm it still plays without friction.

**Acceptance Scenarios**:

1. **Given** the lookup panel is open with a non-empty selected term and the user can use learning features, **When** they tap the pronounce control in the header action row, **Then** they hear the pronunciation for that term and the control shows loading then playing (or ready after finish) without blocking the rest of the sheet.
2. **Given** pronunciation audio is playing for the current term, **When** the user taps the pronounce control again, **Then** playback stops promptly and the control returns to the idle “ready to play” appearance.
3. **Given** the user is signed out (or otherwise cannot use credit-gated AI), **When** they tap pronounce and a new pronunciation would be required, **Then** they see the existing auth/credits callout pattern and no broken empty state.
4. **Given** pronunciation cannot be obtained (network or service error), **When** the tap completes unsuccessfully, **Then** the control returns to idle and the user sees a brief, non-blocking error message; the lookup content remains usable.

---

### User Story 2 - Hear the flashcard headword (Priority: P2)

During vocabulary review, the learner wants to hear the card’s headword without hunting through media clips. A compact pronounce control sits beside the headword on the card face they are studying (front and back), visually distinct from “Play segment” / echo actions that play source media. One tap plays; the control stays responsive during load and play; a second tap stops.

**Why this priority**: Review is the second major vocabulary practice loop; hearing the target word supports recall without leaving the card.

**Independent Test**: In a review session, tap pronounce on the front headword and on the back header; confirm audio matches the headword and does not start the media segment player.

**Acceptance Scenarios**:

1. **Given** a flashcard front is visible with a headword, **When** the user taps the pronounce control beside the headword, **Then** they hear that headword’s pronunciation and the card remains flippable.
2. **Given** the flashcard back is visible, **When** the user taps the pronounce control beside the back header word, **Then** they hear the same headword pronunciation, separate from Context tab media actions (“Play segment”, “Echo reading”).
3. **Given** audio is loading or playing, **When** the user flips the card or rates the card, **Then** playback stops (or is cancelled) so the next card does not keep speaking the previous word.

---

### User Story 3 - Hear the assessed word from results (Priority: P3)

After a pronunciation assessment, the learner taps a word chip in the result panel and wants a clear model pronunciation of that word—not a replay of their own take. In the selected-word detail area, a pronounce control next to the selected word plays the model pronunciation on tap, with the same responsive loading/playing/stop behavior as elsewhere.

**Why this priority**: Completes the practice loop after scoring; slightly narrower than lookup/review but high educational value when comparing to feedback.

**Independent Test**: Complete or reopen an assessment result, select a word chip, tap pronounce in the selected-word panel, confirm model audio for that word plays.

**Acceptance Scenarios**:

1. **Given** an assessment result is open and a word chip is selected, **When** the user taps pronounce beside the selected word, **Then** they hear the model pronunciation for that word.
2. **Given** the user selects a different word chip while audio for the previous word is playing, **When** the selection changes, **Then** previous playback stops and pronounce targets the newly selected word.
3. **Given** no word is selected yet, **When** the result panel is shown, **Then** the pronounce control is not offered as a misleading global action (it appears with the selected-word detail).

---

### Edge Cases

- Empty or whitespace-only text: pronounce control is disabled or hidden; no request is made.
- Very short vs longer phrase (within the service’s length limit): both play when within limit; over-limit text shows a clear reason and does not hang on loading.
- Rapid repeated taps: only one in-flight play/load for that surface; extras are ignored or treated as stop/restart without stacking audio.
- Offline / flaky network: idle restore + brief error; no stuck spinner.
- Locale mismatch (e.g. looked-up language vs profile learning language): pronunciation uses the language context of that surface (lookup language for lookup; learning/focus language or card language for flashcards; assessment language for result words).
- Simultaneous pronounce from two surfaces: at most one pronunciation stream plays app-wide; starting a new one stops the previous.
- Credits exhausted only when a **new** pronunciation must be generated; previously heard shared pronunciations still play when the service can return them without charging the user.
- All focus learning languages and lookup-catalog languages MUST be pronounceable when the surface language matches that tag; only tags outside the published allowlist disable the control.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The product MUST offer a single, recognizable “hear pronunciation” control pattern (icon + tooltip/accessibility label) reused across lookup, flashcard, and assessment result, with a minimum comfortable tap target consistent with other icon actions in the app.
- **FR-002**: Lookup MUST place the pronounce control in the **header action row** with bookmark, copy, and close—same visual weight—so it is always visible with the selected term without scrolling into definition sections.
- **FR-003**: Flashcards MUST place the pronounce control **beside the headword** on the front and beside the headword on the back header, and MUST NOT place it inside the Context media action row (to avoid confusion with “Play segment”).
- **FR-004**: Assessment results MUST place the pronounce control in the **selected-word detail panel** next to the selected word (after a chip is chosen), not as a competing control on every chip.
- **FR-005**: A primary tap on an enabled pronounce control MUST start playback of the model pronunciation for the current target text; a tap while playing MUST stop playback.
- **FR-006**: While a pronunciation is being fetched or buffered, the control MUST show a clear busy state within one frame of the tap (or immediate disable+progress affordance) so the UI feels responsive; busy state MUST clear on success, stop, or error.
- **FR-007**: Playback MUST be graceful: no overlapping pronunciation streams; changing the target text, closing the surface, flipping/rating a card, or selecting another assessed word MUST stop the current pronunciation.
- **FR-008**: Pronounce MUST use the signed-in learning account path already expected for AI-assisted lookup features; signed-out or insufficient-credits cases MUST reuse existing user-facing guidance patterns on that surface.
- **FR-009**: Failures MUST be non-destructive: the host panel stays open and usable; the user gets a short recoverable message; the control returns to idle.
- **FR-010**: Target text for playback MUST be the surface’s primary word/phrase (lookup selection, flashcard headword, selected assessment word), not an unrelated sentence or the user’s recorded take.
- **FR-011**: The control MUST expose an accessibility label and tooltip equivalent to “Play pronunciation” / “Stop pronunciation” (localized) matching idle vs playing state.
- **FR-012**: Pronunciation language/voice context MUST follow the language of the surface’s content (lookup language picker / card language / assessment language), covering every focus learning language and lookup-catalog language the product offers (not English-only).

### Key Entities

- **Pronounce target**: The text + language context a surface wants spoken (selection, headword, or assessed word).
- **Pronounce playback session**: Idle → loading → playing → idle/error; at most one active session app-wide for this feature.
- **Model pronunciation**: Reference speech of the target text for listening/imitation—not the learner’s assessment recording.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In moderated usability checks, at least 9 of 10 learners find and successfully play pronunciation on the lookup panel on the first try without help.
- **SC-002**: From tap to audible start, cold play feels immediate: under 2 seconds on a typical connection for a short word when the pronunciation is already available to the product; under 5 seconds when a new pronunciation must be prepared—without the UI appearing frozen.
- **SC-003**: Zero instances of two pronunciations overlapping in acceptance testing across the three surfaces.
- **SC-004**: Learners can distinguish flashcard “hear the word” from “play media segment” in a quick preference test (correct identification ≥ 90%).
- **SC-005**: Error and signed-out paths never leave a stuck loading pronounce control in automated or manual regression of the three surfaces.

## Assumptions

- The backend already exposes a shared, cache-friendly pronunciation service suitable for short vocabulary/phrase text; the client consumes it through the app’s existing AI/account channel rather than inventing a separate product path.
- “Pronounce” means **model/reference** speech. Replaying the user’s assessment recording remains a separate affordance if added later.
- Craft’s longer-form TTS tools stay out of scope; this feature is word/phrase listening on learning surfaces only.
- Default interaction is **click/tap to play**, second tap **stops** (not pause-resume at position).
- Button chrome follows existing tonal icon actions (lookup header) and stays visually quieter than primary CTAs (rate buttons, flip hint).
- ADR-0019 noted lookup TTS as a follow-up; this feature is that product decision for lookup plus flashcard and assessment result.
- Out of scope for this slice: vocabulary list rows outside the flashcard, Craft studio, settings voice pickers, offline-only packs, and per-word buttons on every assessment chip.

## Placement Summary (design intent)

| Surface | Control location | Why |
|---------|------------------|-----|
| Lookup | Header action row (with bookmark / copy / close), always adjacent to the selected term | Highest visibility; matches existing chrome; avoids burying play inside expandable dictionary cards |
| Flashcard front | Beside centered headword | Word is the hero; flip CTA stays primary |
| Flashcard back | Beside header headword above tabs | Same target as front; keeps Context media chips for **source** audio only |
| Assessment result | Selected-word detail header next to the chosen chip’s word | Appears when feedback is relevant; avoids cluttering the chip row |

Shared behavior: click to play → responsive busy → playing → click to stop; one stream; graceful cancel on dismiss/navigation.
