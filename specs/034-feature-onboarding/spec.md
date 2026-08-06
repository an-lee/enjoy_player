# Feature Specification: Feature Onboarding Guides

**Feature Branch**: `034-feature-onboarding`

**Created**: 2026-08-06

**Status**: Draft

**Input**: User description: "We need to add onboarding for new users for every important features, guide user to know what Enjoy Player could do, and how to use Enjoy Player. Like on the home screen, we should introduce the craft button, import button; On player screen, if no transcript available, guide user to extract/import transcript from local video, fetch YT transcript from cloud for YT video. Then guide user to toggle echo mode, guide user to record, assess pronounce after record etc. We should build a maintainable onboarding system, follow the best practices. Do some research first, what library could we use."

**Related**: [ADR-0031 login-only access](../../docs/decisions/0031-login-only-access.md) (welcome is sign-in only — this feature is *post-sign-in* product discovery) | [029-craft-history-home](../029-craft-history-home/spec.md) | [013-client-yt-transcripts](../013-client-yt-transcripts/spec.md)

## Clarifications

### Session 2026-08-06

- Q: Which presentation toolkit should v1 use for spotlight coach marks? → A: Use a mature spotlight coach-mark overlay library; tip identity, triggers, sequencing, and progress persistence remain Enjoy-owned. Concrete package choice is recorded in the implementation plan / research (not in this stakeholder spec).
- Q: (analyze remediation) Empty-transcript progress key, local CTA target, echo soft-complete, start guards? → A: Progress per `mediaId` only; local tip spotlights Extract else Add subtitle; FR-004b echo soft-complete; skip/defer when target unpainted or blocking overlay.
- Q: After dismiss/complete of the empty-transcript tip on one video, should it stay hidden globally or show again on other no-transcript media? → A: Resolved per media item; other no-transcript media can still show the tip (until replay/reset).
- Q: While a tip highlights a control, should tapping that control perform the real action, or only tip buttons advance/dismiss? → A: Tap highlighted control runs the real action and closes/advances that tip; tip Next/Skip remain available.
- Q: Should Settings/About re-enable tips by clearing all progress or only the current surface? → A: One “Reset product tips” action clears all tip progress (Home, Player practice tips, and per-media empty-transcript records).
- Q: After echo tip finishes/skips, may record and assess tips appear in the same player visit when ready? → A: Yes — same visit chaining allowed as each practice tip’s preconditions are met (still one active overlay at a time).
- Q: Should the stakeholder specification keep naming the tip-overlay package, or leave the package choice in the plan? → A: Spec stays toolkit-agnostic (spotlight coach marks + Enjoy-owned tips/progress); package choice lives only in plan / research / ADR.

## Scope

### In scope

- A **maintainable, reusable in-app guidance system** that can introduce important product capabilities with short, contextual tips (spotlight / coach-mark style), not a separate multi-screen marketing carousel before sign-in.
- **Home** guidance for the primary **Craft** and **Import** entry points.
- **Player** guidance that appears when relevant:
  - When the current media has **no transcript**, guide the learner to obtain one (local extract/import for local video; fetch YouTube transcript for YouTube media).
  - After transcript practice is available, guide the learner to **echo mode**, then **record**, then **pronunciation assessment** after a recording.
- Clear **skip / dismiss** controls so guidance never traps the learner.
- **Persistence** of which guides the learner has completed or dismissed so tips do not reappear every session.
- A Settings/About **Reset product tips** action that clears all tip progress so guides can auto-show again, without affecting library, account, or unrelated preferences.
- Design that makes adding a new tip for a future feature a small, localized change (stable tip identities, screen/context triggers, copy), not a rewrite of unrelated UI.

### Out of scope

- Changing the **welcome / sign-in hub** into a multi-step onboarding funnel (already decided against in ADR-0031).
- Teaching every secondary control, settings page, Discover, vocabulary, Craft Studio internals, or keyboard shortcut catalog in v1.
- Forced full-app tours that must finish before the learner can use Home or Player.
- Remote A/B experimentation or server-driven tip content in v1.
- Replacing existing empty states, errors, or first-run permission dialogs; guidance complements them, does not replace them.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Discover Craft and Import on Home (Priority: P1)

A newly signed-in learner lands on Home. Short guidance highlights the **Import** control and the **Craft** control so they understand the two primary ways to get practice material: bring existing media in, or create with Craft. They can advance through the tips, skip the whole Home guide, or dismiss and keep using Home normally.

**Why this priority**: Without knowing Craft and Import, learners cannot start the core learning loop.

**Independent Test**: Fresh account (or reset tip progress) opens Home; confirm Craft and Import tips appear in a sensible order, can be completed or skipped, and do not block opening either action.

**Acceptance Scenarios**:

1. **Given** the learner has not completed or dismissed the Home entry guide, **When** they arrive on Home with the Craft and Import controls visible, **Then** guidance introduces Import and Craft with brief explanations of what each does.
2. **Given** Home guidance is showing, **When** the learner skips or dismisses it, **Then** the overlay closes immediately and Home remains fully usable.
3. **Given** the learner completed or dismissed the Home entry guide, **When** they return to Home in a later session, **Then** that guide does not auto-show again.
4. **Given** Home guidance is highlighting Craft or Import, **When** the learner taps the highlighted control, **Then** the real Craft or Import action runs, that tip closes or advances, and the UI does not stay stuck under an overlay.

---

### User Story 2 - Get a transcript when the player has none (Priority: P1)

A learner opens a video or audio item with **no transcript** loaded. Contextual guidance explains that practice needs a transcript and points them to the correct path for that media type: for **local** media, extract or import a transcript; for **YouTube** media, fetch the transcript from the cloud. Dismissing or completing the tip for **that media item** stops re-nagging on that item; opening a **different** item that still has no transcript may show the tip again.

**Why this priority**: Echo, recording, and pronunciation depend on transcript-backed practice; learners often stall without knowing how to add one.

**Independent Test**: Open local media without a transcript and confirm local obtain-transcript guidance; dismiss it; open a second no-transcript item and confirm the tip can show again; reopen the first item and confirm it does not re-nag; open media that already has a transcript and confirm this tip does not show.

**Acceptance Scenarios**:

1. **Given** local media is open in the player with no transcript, **When** the empty-transcript guide is eligible, **Then** the learner is guided toward extracting or importing a transcript for that local file.
2. **Given** YouTube media is open in the player with no transcript, **When** the empty-transcript guide is eligible, **Then** the learner is guided toward fetching the YouTube transcript from the cloud.
3. **Given** the player already has a usable transcript, **When** the learner uses the player, **Then** the empty-transcript guide does not appear.
4. **Given** empty-transcript guidance is showing for media item A, **When** the learner dismisses it or successfully obtains a transcript for A, **Then** the tip does not auto-show again for A until replay/reset.
5. **Given** the learner already resolved empty-transcript guidance for media item A, **When** they open a different media item B that still has no transcript, **Then** empty-transcript guidance may auto-show for B.
6. **Given** empty-transcript guidance is highlighting the obtain-transcript control, **When** the learner taps that highlighted control, **Then** the real extract/import or YouTube-fetch flow starts and the tip closes or advances.

---

### User Story 3 - Learn echo, record, and pronunciation assessment (Priority: P2)

After the learner has transcript-backed practice available, the product introduces the practice loop in sequence: turn on **echo mode**, use **record**, then **assess pronunciation** after a recording exists. Tips appear only when the prior step’s context makes sense (e.g. assessment tip after the learner has recorded). Within a **single player visit**, the next practice tip MAY auto-show as soon as it is ready after the previous tip is completed or skipped (still only one overlay at a time), so the tour coaches through real use without forcing a leave/re-enter.

**Why this priority**: These are differentiating practice features; discovering them after transcript setup maximizes “aha” without front-loading complexity.

**Independent Test**: With a media item that has a transcript and reset tip progress, confirm echo → record → assess tips can appear in order under the right conditions within one player visit when each becomes ready, and each can be skipped without breaking playback.

**Acceptance Scenarios**:

1. **Given** a transcript is available and the learner has not completed the echo tip, **When** the player practice surface is ready, **Then** guidance introduces how to toggle echo mode.
2. **Given** echo guidance was completed or skipped (or echo is already understood per completion rules) and record guidance is still pending, **When** the player is ready for practice recording, **Then** guidance introduces recording.
3. **Given** the learner has completed a practice recording and assessment guidance is still pending, **When** assessment is available for that recording, **Then** guidance introduces pronunciation assessment.
4. **Given** any of these practice tips is showing, **When** the learner skips or dismisses, **Then** playback and controls remain usable and the dismissed tip does not auto-loop immediately.
5. **Given** a practice tip is highlighting echo, record, or assess, **When** the learner taps the highlighted control, **Then** the real control action runs and that tip closes or advances.
6. **Given** the echo tip was completed or skipped and record is still pending, **When** the player remains on a ready practice surface in the same visit, **Then** the record tip may auto-show without requiring the learner to leave and re-enter the player.
7. **Given** the record tip was resolved and the learner has a practice recording with assessment available, **When** still in the same player visit, **Then** the assess tip may auto-show (after any prior overlay has fully closed).
8. **Given** echo mode is already active and the echo tip is still pending, **When** practice tips would auto-show, **Then** the echo tip is marked completed without showing and the next eligible practice tip (e.g. record) may proceed in the same visit.

---

### User Story 4 - Reset product tips later (Priority: P3)

A returning learner forgot how a control works. From a discoverable place in Settings (or About), they use **Reset product tips**, which clears **all** tip progress (Home guides, Player practice tips, and per-media empty-transcript records) so eligible guides can auto-show again. Reset does not sign them out or wipe library data.

**Why this priority**: Improves long-term discoverability without nagging every launch; secondary to first-run value.

**Independent Test**: Complete Home tips and dismiss an empty-transcript tip on one media item; use Reset product tips; return to Home and that media (still without transcript) and confirm tips can show again.

**Acceptance Scenarios**:

1. **Given** the learner previously completed or dismissed any tips, **When** they choose **Reset product tips** from the designated settings surface, **Then** all tip progress is cleared and eligible guides may auto-show again on the relevant screens.
2. **Given** the learner uses Reset product tips, **When** the action finishes, **Then** their media library, account, and unrelated preferences remain intact.
3. **Given** per-media empty-transcript dismissals existed, **When** Reset product tips runs, **Then** those per-media records are cleared along with global tip progress.

---

### Edge Cases

- Guidance must not show over blocking dialogs that require an immediate decision (permissions, fatal errors, forced sign-in).
- If a highlighted control is temporarily off-screen, unavailable, or not built for the current platform/layout, that tip is skipped or deferred rather than pointing at empty space.
- Rapid navigation away from Home or Player while a tip is open closes or safely abandons the tip without crashing or freezing input.
- Multiple tip triggers must not stack into overlapping overlays; only one guidance sequence is active at a time.
- Desktop window resize / mobile rotation mid-tip must keep the highlight attached to the correct control or gracefully dismiss/reposition without trapping taps.
- Learners who already use a feature extensively before a tip fires should still be able to dismiss once; tips must not re-fire on every visit after dismiss/complete.
- Empty-transcript tip progress is **per media item**: resolving it on one item must not silence the tip for other no-transcript items.
- Tapping a highlighted control must not leave a stuck overlay if navigation away begins as part of the real action.
- Localized UI (including longer translations) must keep tip copy readable without covering the only dismiss control.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The product MUST provide contextual, step-oriented guidance that highlights real on-screen controls and briefly explains what they do and why they matter.
- **FR-002**: Home MUST be able to introduce the **Import** and **Craft** entry points to learners who have not yet completed or dismissed that guide.
- **FR-003**: When the player has no transcript, the product MUST guide the learner to obtain one using the path appropriate to the media type (local extract/import vs YouTube cloud fetch).
- **FR-004**: When transcript-backed practice is available, the product MUST be able to guide learners through **echo mode**, **recording**, and **pronunciation assessment after recording**, in an order that matches real practice readiness.
- **FR-004a**: After a practice tip is completed or skipped, the next eligible practice tip MUST be allowed to auto-show in the **same player visit** once its preconditions are met, without requiring leave/re-enter; FR-012 (single active overlay) still applies.
- **FR-004b**: If echo mode is already active when the echo tip would otherwise auto-show, the product MUST mark the echo tip completed without showing it and MAY proceed to the next eligible practice tip in the same visit.
- **FR-005**: Every guidance sequence MUST offer an obvious way to skip or dismiss without completing all steps.
- **FR-005a**: When a tip highlights a control, tapping that highlighted control MUST perform the real underlying action and MUST close or advance that tip; tip Next/Skip controls remain available as an alternative.
- **FR-006**: The product MUST remember completed and dismissed guides so they do not auto-show again on every launch (until the learner explicitly replays/resets).
- **FR-006a**: Empty-transcript tip progress MUST be scoped **per media item**: dismiss/complete (or successful transcript obtain) for one item MUST NOT prevent the tip from auto-showing on a different no-transcript item.
- **FR-007**: Guidance MUST only appear when its target context is valid (correct screen, visible relevant controls, and any stated preconditions such as “no transcript” or “recording exists”).
- **FR-008**: Guidance MUST never permanently block core actions: browsing Home, opening Craft/Import, playing media, or leaving the player.
- **FR-009**: Learners MUST be able to run a single **Reset product tips** action from a discoverable settings/about surface that clears all tip progress (including per-media empty-transcript records) without losing library or account data.
- **FR-010**: Tip copy MUST be localizable with the rest of the app’s user-visible strings.
- **FR-011**: The guidance system MUST support adding, reordering, or retiring tips for important features over time using stable tip identities and clear triggers, without redesigning unrelated screens each time.
- **FR-012**: Only one guidance overlay/sequence may be active at a time; conflicting triggers defer or cancel cleanly.
- **FR-013**: Guidance presentation MUST remain usable across supported phone, tablet, and desktop layouts used by Enjoy Player.

### Key Entities

- **Guidance tip**: A single teachable moment with stable identity, title/body copy, target control/context, and optional preconditions (e.g. no transcript, recording present).
- **Guidance sequence**: An ordered set of tips for one surface or practice stage (e.g. Home entries, empty-transcript help, practice loop).
- **Tip progress**: Per-learner record (tied to the signed-in profile on this device — not shared across accounts on the same device) of whether a tip or sequence was completed, skipped, or is still pending; used to gate auto-show and replay/reset. For empty-transcript tips, progress is keyed by **media item identity only** (one record per `mediaId` covers local and YouTube tip variants). The tip id selects which tip UI to show; Home and practice-loop tips remain global (not per media).
- **Trigger context**: Screen + media/practice state that decides whether a sequence is eligible right now.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In moderated first-use tests, at least **80%** of new learners can correctly explain what **Craft** and **Import** do after seeing (or skipping) Home guidance, without help from a facilitator.
- **SC-002**: Among new learners who open media with no transcript, at least **75%** start a transcript obtain flow (extract/import or YouTube fetch) within **2 minutes** of the empty-transcript guidance appearing, or can dismiss and still find the action unaided afterward.
- **SC-003**: Among learners who reach transcript-backed practice with practice tips enabled, at least **70%** successfully toggle echo, complete one recording, and open pronunciation assessment within their first practice session (tips may be skipped; success is task completion).
- **SC-004**: After a learner completes or dismisses a guide for a given progress scope (global tip, or empty-transcript tip for a specific media item), that guide auto-shows again for the **same scope** in **fewer than 5%** of subsequent eligible visits unless they explicitly replay/reset.
- **SC-005**: Guidance overlay open/close does not make Home or Player feel stuck: learners can dismiss and regain full control in under **2 seconds** of intentional dismiss in manual QA on reference devices.
- **SC-006**: Product/design can add a new tip for an important control by updating guidance configuration/copy and wiring one target, without a broad rewrite of Home or Player layout (verified in planning/review checklist).

## Assumptions

- This feature is **post-sign-in feature discovery**, not a replacement for the existing welcome sign-in hub.
- **Progressive, contextual tips** are preferred over one long forced tour at first launch (aligns with common product onboarding practice and the scenarios described).
- v1 tip set is limited to: Home Craft + Import; Player empty-transcript (local vs YouTube); echo; record; assess-after-record. Other surfaces can adopt the same system later.
- Tip progress is stored with the **signed-in profile on this device** in v1 (not shared across accounts on the same device); cross-device sync of tip progress is not required initially. Storage mechanism is defined in the implementation plan.
- Empty states and existing transcript CTAs remain; guidance **points at** those actions rather than inventing a parallel hidden flow.
- “Assess pronounce after record” means guiding the learner to the existing pronunciation assessment entry that becomes relevant after a practice recording, not inventing a new assessment product.
- Learners may skip any tip; skipping counts as resolved for auto-show purposes until replay/reset (for empty-transcript tips, resolved **for that media item only**).
- Home entry tips and practice-loop tips (echo / record / assess) are **global** in v1; only empty-transcript tips use per-media progress.
- Tip interaction model is **learn-by-doing**: highlighted targets remain actionable; Next/Skip are always available for learners who prefer not to act yet.
- v1 exposes one full **Reset product tips** control (not per-surface reset or “replay without wipe”).
- Practice-loop tips may chain in one player visit as preconditions unlock; empty-transcript tips still gate practice tips until a transcript exists for the current media.
- Visual style should feel native to Enjoy Player (readable contrast, non-blocking dismiss, no playful clutter that fights video).
- Presentation will use a spotlight-style coach experience (highlight real controls with short explanations). Tip identity, triggers, sequencing, and progress persistence remain Enjoy-owned so the system stays maintainable and testable independent of the overlay toolkit. Concrete overlay package choice is deferred to the implementation plan.
