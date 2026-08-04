# Feature Specification: Immersive Flashcard Review

**Feature Branch**: `033-immersive-flashcard-review`

**Created**: 2026-08-04

**Status**: Draft

**Input**: User description: "We need to improve the flash card review UX. We should make it immersive, bleed full the window, no other things disattractive."

**Related**: Builds on the flashcard session from [022-vocabulary-screen-review](../022-vocabulary-screen-review/spec.md) and the Vocabulary product contract in [docs/features/vocabulary.md](../../docs/features/vocabulary.md). This change is **presentation / chrome only** — review queue selection, SRS ratings, undo, skip, and in-session learning actions stay as today.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Enter a distraction-free full-window review (Priority: P1)

As a learner starting a flashcard review, I enter a session that fills the entire application window. App navigation (sidebar / destination rail), search, profile chrome, and the persistent media player bar are not visible so my attention stays on the card.

**Why this priority**: The current session sits inside the normal app shell, so chrome competes with the card. Immersion is the core request.

**Independent Test**: From Vocabulary, start any non-empty review session and confirm the review surface occupies the full window with no sidebar, search, or global player bar visible.

**Acceptance Scenarios**:

1. **Given** the learner is in the normal app shell (sidebar and player bar visible), **When** they start a flashcard review session, **Then** the review UI covers the full application window edge-to-edge within the window bounds.
2. **Given** a review session is active, **When** the learner looks at the window, **Then** they do not see the main navigation sidebar, global search, profile footer, or persistent media player control bar.
3. **Given** a review session is active, **When** the learner views the session, **Then** they still see only review-essential controls: close/exit, progress, skip (when available), the card, flip/rate actions, and (on desktop) shortcut hints or equivalent discoverable shortcuts.
4. **Given** review is active on a wide desktop window, **When** the session is shown, **Then** the card remains the visual focus (centered / dominant) rather than a small inset panel surrounded by empty chrome from other app regions.

---

### User Story 2 - Leave review and regain the normal app shell (Priority: P1)

As a learner who exits or finishes a session, I return to Vocabulary (or the prior destination) with the normal navigation and player chrome restored, without leftover immersive layout.

**Why this priority**: Immersion must be temporary; broken chrome after exit is a regression.

**Independent Test**: Start review, exit via close control and via Esc (desktop); also complete a short session; in each case verify the shell chrome returns.

**Acceptance Scenarios**:

1. **Given** an active immersive review, **When** the learner exits via the close control, **Then** they leave the session and the normal app shell (navigation + player bar as before) is visible again.
2. **Given** an active immersive review on desktop, **When** they press Esc, **Then** they exit review and shell chrome is restored the same way.
3. **Given** the learner finishes the queue and sees the session-complete state, **When** they leave that state, **Then** shell chrome is restored and they are back in Vocabulary (or the documented post-session destination).
4. **Given** ratings or skips already committed during the session, **When** they exit early, **Then** those committed results remain saved and only the immersive presentation ends.

---

### User Story 3 - Keep the learning loop usable while immersed (Priority: P1)

As a learner inside immersive review, I can still flip, rate, skip, undo, hear pronunciation, and use in-session practice/context actions that belong to the card — without needing the hidden global player bar.

**Why this priority**: Removing chrome must not remove the review workflow itself.

**Independent Test**: In an immersive session, flip a card, apply each rating, skip once, undo once, trigger pronunciation if available, and open any in-session context/practice affordance that already exists; confirm behavior matches pre-change review rules.

**Acceptance Scenarios**:

1. **Given** the card front is showing, **When** the learner flips (tap/click or Space on desktop), **Then** the back and rating actions appear as today.
2. **Given** the card back is showing, **When** they rate Don’t Know / Know / Know Well (or use `1` / `2` / `3` on desktop), **Then** SRS updates and the session advances as today.
3. **Given** a card, **When** they skip or undo, **Then** skip/undo behave as today.
4. **Given** in-session pronunciation or context/practice actions that already exist on the card, **When** the learner uses them, **Then** those actions still work inside the immersive session without requiring the global player bar.
5. **Given** a rating update is in flight, **When** the learner tries another rating, **Then** duplicate concurrent ratings are still blocked.

---

### User Story 4 - Immersion works across supported layouts (Priority: P2)

As a learner on phone, tablet, or desktop, immersive review always uses the full available content area for that window/screen, without leaving a “framed” app-shell look.

**Why this priority**: Vocabulary review ships on all supported native platforms; immersion should not be desktop-only.

**Independent Test**: Start review at a phone-width, tablet-width, and desktop-width window (or device) and confirm full-bleed immersion and restored chrome on exit in each case.

**Acceptance Scenarios**:

1. **Given** a narrow (phone-class) viewport, **When** review starts, **Then** the session fills the screen’s content area with no persistent app navigation rail/bar competing for attention.
2. **Given** a tablet or desktop viewport, **When** review starts, **Then** the session fills the window the same way (no sidebar/player chrome).
3. **Given** the window is resized during an active session, **When** the size changes, **Then** the review surface continues to fill the window without revealing shell chrome underneath.

---

### Edge Cases

- What happens if the learner starts review while media is actively playing in the global player? The immersive session still covers the player bar; in-session clip/practice actions remain available. Global playback is not newly required to stop solely for this UX change unless already required by existing review behavior.
- What happens if the session queue is empty? Review does not start (existing guard); no immersive overlay appears.
- What happens if the learner uses system back / gesture back where applicable? They exit review and shell chrome restores, same as explicit close.
- What happens on session-complete? The complete state remains part of the immersive surface until the learner leaves; chrome restores only after leaving.
- How are shortcut hints shown? Desktop may keep a single, low-emphasis hint row tied to the review surface; it must not reintroduce app-shell chrome.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: While a flashcard review session is active, the product MUST present the session as a full-window immersive surface that covers the normal application shell chrome (navigation sidebar/rail, global search, profile chrome in the shell, and the persistent media player bar).
- **FR-002**: The immersive surface MUST occupy the full application window content area (edge-to-edge within the window), not a nested content pane beside the sidebar or above the player bar.
- **FR-003**: The immersive surface MUST show review-essential UI only: exit/close, session progress, card content, flip/rate (when appropriate), skip when available, undo when available, and existing in-session card actions (e.g. pronunciation, context/practice). Decorative or competing app chrome MUST NOT remain visible.
- **FR-004**: Exiting review (close control, Esc on desktop, system back where applicable) MUST dismiss the immersive surface and restore the normal app shell chrome.
- **FR-005**: Completing a session and leaving the complete state MUST likewise restore normal shell chrome.
- **FR-006**: Immersive presentation MUST NOT change review selection rules, SRS rating outcomes, skip/undo semantics, session progress counting, or keyboard shortcut mappings already defined for review.
- **FR-007**: Immersive review MUST apply on all platforms where Vocabulary review already runs (phone, tablet, and desktop window sizes).
- **FR-008**: Users MUST still be able to perform in-session learning actions that belong to the card without depending on the hidden global player bar.
- **FR-009**: The immersive session MUST remain reachable from the existing Vocabulary Review start path; this feature does not add a second parallel review product.

### Key Entities

- **Review session**: The active flashcard queue and progress state already defined by Vocabulary review; this feature only changes how that session is presented relative to app chrome.
- **App shell chrome**: Persistent navigation and global player UI that surrounds normal destinations and MUST be hidden for the duration of an immersive review session.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In usability checks on desktop and a phone-class width, 100% of reviewers agree that during an active session they cannot see the main navigation sidebar/rail or the persistent media player bar.
- **SC-002**: Starting a review reaches a usable first card in the immersive surface in under 2 seconds on a typical local vocabulary book (excluding network-bound optional enrichments).
- **SC-003**: Learners can complete a 5-card review (flip + rate each card) without needing any control that lives only in the hidden app shell.
- **SC-004**: After exit or session completion leave, shell chrome is restored on the first subsequent frame of the Vocabulary (or prior) destination — no stuck full-bleed state.
- **SC-005**: Existing desktop keyboard review shortcuts (flip, rate, skip/previous, exit) continue to work in immersive mode with no newly required mouse-only steps for those actions.

## Assumptions

- Scope is the **active flashcard review session** (including session-complete before leave), not the Vocabulary home/stats/All Words screens.
- “Bleed full the window” means the full application window content area on desktop and the full screen content area on mobile/tablet — not forcing OS-level exclusive fullscreen unless the product already does that elsewhere.
- Hiding the global player bar is intentional distraction reduction; card-local practice/clip actions that already exist in review remain the way to hear or play context during the session.
- Global media playback state is not redesigned here; if media was playing under the shell, this feature does not newly require pause/stop unless current review already does.
- Visual restyling of the card (colors, typography) is optional polish; the mandatory outcome is immersion via chrome removal and full-bleed layout.
- Localization, SRS math, sync, and Anki export are out of scope.
- Documentation in `docs/features/vocabulary.md` should be updated when behavior ships so “fullscreen / modal review” matches the immersive shell-covering experience.
