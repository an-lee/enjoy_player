# Feature Specification: Home Continue Practice

**Feature Branch**: `044-home-continue-practice`

**Created**: 2026-08-23

**Status**: Draft

**Input**: User description: "Let's implement it." (Agreed product change: remove the global mini player bar and add a Home **Continue practicing** card as the resume surface.)

**Related**: [007-responsive-player-controls](../007-responsive-player-controls/spec.md) | [029-craft-history-home](../029-craft-history-home/spec.md)

## Scope

### In scope

- Add a prominent **Continue practicing** card on Home that resumes the learner’s last practice item at the saved position.
- Stop showing a **global mini player / collapsed transport bar** on Home, Discover, Library, Profile, and other non-player screens.
- Treat leaving the player as **leaving practice**: playback does not continue in the background while the learner browses the rest of the app.
- Keep the **full playback transport** on the player screen itself (play/pause, seek, echo, blur, captions, speed, and related practice controls).
- Keep Home **recents** as a browse grid, visually and functionally distinct from the Continue card.

### Out of scope

- Redesigning the rest of Home (greeting/avatar, daily-goal layout, community card, header Craft/Import).
- Changing the floating bottom navigation or desktop sidebar.
- Removing or redesigning the transport bar **on the player screen**.
- Changing how vocabulary review or vocabulary clip practice hides shell chrome.
- Adding a mini player or resume chip on Discover, Library, or Profile.
- Changing lock-screen / system media-notification policy beyond “no live playback after leaving the player.”
- New practice modes, new persistence fields, or a multi-item “Up next” queue.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Resume practice from Home in one tap (Priority: P1)

A learner practiced a video yesterday and left the player. Today they open Home and see a **Continue practicing** card for that item: title, source (for example TED-Ed or Craft), practice mode when relevant (for example Echo), language pair when known, and how far they got. They tap the card and land on the player at the saved position, ready to keep practicing. They do not hunt through recents or rely on a tiny bar at the bottom of the screen.

**Why this priority**: Resume is the primary Home job for a returning learner. The card is the replacement for the mini player as a way back into practice.

**Independent Test**: With a saved practice position for one library item, open Home, confirm the Continue card shows that item with progress, tap it, and confirm the player opens at the saved position.

**Acceptance Scenarios**:

1. **Given** the learner has previously practiced at least one item and a position was saved, **When** they open Home, **Then** they see a Continue practicing card for that last item above the recents grid.
2. **Given** the Continue card is visible, **When** they look at it, **Then** they can recognize the item (title and artwork or equivalent cover) and see progress through the item.
3. **Given** the last session used Echo mode, **When** the card is shown, **Then** Echo (or the equivalent practice-mode label) is visible on the card.
4. **Given** content and native/learning languages are known for the item, **When** the card is shown, **Then** the language pair is visible.
5. **Given** the learner activates the Continue card, **When** the player opens, **Then** they resume at the saved position with the same practice mode they last used for that item.

---

### User Story 2 - Leave the player without a mini bar (Priority: P1)

A learner is in the player, then leaves (back, collapse, or switching to Home / Discover / Library / Profile). Playback stops. No mini player bar appears above the tab bar. Home, Discover, and Library use the full content area plus the existing tab/sidebar chrome only. To resume, they open the same item again (Continue card on Home, or the item in recents / Library).

**Why this priority**: Removing the mini bar is the product rule this feature exists to enforce. Background listening is not the product; stacked bottom chrome fights the floating tab bar; practice controls on a collapsed bar cannot show transcript work.

**Independent Test**: Start playback on the player, leave to Home and to Library, confirm there is no mini transport bar, confirm audio/video is not still playing, then resume from the Continue card.

**Acceptance Scenarios**:

1. **Given** the learner is playing media on the player screen, **When** they leave the player to Home, Discover, Library, or Profile, **Then** no collapsed transport / mini player bar is shown.
2. **Given** they leave the player while audio or video was playing, **When** they arrive on a non-player screen, **Then** playback is not still audible or visible in the background.
3. **Given** they left the player, **When** they return via the Continue card (or by opening the same item from recents/Library), **Then** they resume at the position saved when they left.
4. **Given** the learner is on the player screen, **When** they look at the bottom of that screen, **Then** the full playback transport is still present and usable (this feature does not remove in-player controls).

---

### User Story 3 - Home with nothing to resume (Priority: P2)

A new learner (or someone who cleared their library) opens Home. There is no fake Continue card. Recents, daily goal, Craft/Import, and community behave as they do today. The empty Home still offers a path to import or Craft.

**Why this priority**: A phantom TED-style hero would teach the wrong model. Hide Continue until there is a real item to resume.

**Independent Test**: Launch Home with an empty library / no saved practice position and confirm the Continue card is absent and recents empty state still works.

**Acceptance Scenarios**:

1. **Given** the learner has never practiced an item (or has no saved resume position), **When** they open Home, **Then** the Continue practicing card is not shown.
2. **Given** the last practiced item was removed from the library, **When** they open Home, **Then** the Continue card is not shown for that missing item (either hidden, or replaced by the next valid resume item if one exists).
3. **Given** Home has recents but the learner never opened the player, **When** they open Home, **Then** recents still appear and Continue remains hidden until they have a saved practice position.

---

### User Story 4 - Continue is resume; recents are browse (Priority: P2)

A learner who has several recent items sees the Continue card for **the last thing they practiced**, then a recents grid of recent library items. The same title may appear in both. Tapping Continue resumes practice; tapping a recents tile opens that item (existing library-open behavior, including saved position when one exists). The card is visually a hero, not a duplicate of a recents poster.

**Why this priority**: Without this distinction Home either duplicates the same tile twice with no extra meaning, or Continue steals the recents job.

**Independent Test**: Practice item A, then browse item B in the library without practicing, then open Home and confirm Continue still points at A (last practiced) while recents include both; tap each and confirm Continue resumes A and a recents tile opens that tile’s item.

**Acceptance Scenarios**:

1. **Given** the learner practiced item A, then only browsed or imported other items, **When** they open Home, **Then** Continue still represents A (last practiced), not necessarily the first recents tile.
2. **Given** A is both the Continue item and in recents, **When** Home renders, **Then** Continue is a distinct hero (larger, with progress and practice metadata) and recents remain a grid of browse tiles.
3. **Given** the learner taps a recents tile for a different item, **When** the player opens, **Then** that other item opens (existing open behavior) and does not silently keep playing A.

---

### Edge Cases

- **Completed item**: If the saved position is at or near the end, Continue still shows that item. Opening it uses existing end-of-item resume behavior (do not invent a new “restart vs remain at end” rule here).
- **Missing or unreadable file**: Continue must not crash Home. Activating a card whose media can no longer be opened follows existing open-media error handling (message + stay on Home or equivalent recovery).
- **No duration yet**: If progress cannot be computed (unknown length), still show the card with title/artwork and omit or show an indeterminate progress cue rather than a misleading 0% / 100%.
- **Rapid leave and return**: Leaving the player and immediately tapping Continue must not lose the position that was visible when they left.
- **Immersive vocabulary review**: Review continues to hide tab/sidebar chrome as today. This feature does not reintroduce a mini player there.
- **Desktop keyboard**: Global play/pause and seek shortcuts do not control a hidden background session while the learner is on Home/Discover/Library. They remain available on the player screen.
- **System now-playing UI**: After leaving the player, the device should not keep advertising a live now-playing session for media that is no longer playing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Home MUST show a Continue practicing card when a resumable last-practice item exists.
- **FR-002**: The Continue card MUST identify the item (title plus artwork or generated cover) and show progress through the item when duration is known.
- **FR-003**: The Continue card MUST show Echo (or the last practice-mode label) when the saved session used Echo mode.
- **FR-004**: The Continue card MUST show the content/native language pair when those languages are known for the item.
- **FR-005**: Activating the Continue card MUST open the player for that item at the saved position and restore the last practice mode for that item.
- **FR-006**: Home MUST hide the Continue card when there is no valid resumable item (never practiced, library empty, or last item gone with no fallback).
- **FR-007**: Non-player screens MUST NOT show a collapsed / mini playback transport bar.
- **FR-008**: Leaving the player MUST stop audible/visible playback. The learner MUST be able to resume later from the saved position.
- **FR-009**: The player screen MUST still present the full playback transport (practice controls remain available there).
- **FR-010**: Home recents MUST remain a separate browse grid and MUST NOT be replaced by the Continue card.
- **FR-011**: Continue MUST represent the last **practiced** item (last playback session), not merely the most recently updated library row.
- **FR-012**: Opening an item from recents or Library MUST still work without a mini bar (existing open-player path).
- **FR-013**: Home MUST remain usable if Continue artwork or progress cannot load (title still shown; progress omitted if unknown).
- **FR-014**: User-visible strings for the card (title, empty-adjacent copy if any, practice-mode labels) MUST be localized.
- **FR-015**: After leaving the player, the app MUST NOT keep a live now-playing session that the learner can hear or control from Home/Discover/Library without opening the player.

### Key Entities

- **Practice resume item**: The single library item the learner last practiced, plus saved position, optional duration (for progress), last practice mode (Echo or normal), and language labels when known.
- **Playback session (player screen only)**: The in-progress listening/practice session that exists while the learner is on the player. Leaving the player ends live playback; saved resume data remains.
- **Home recents**: Recently updated library items for browsing. Overlaps the resume item when that item is also recent, but is not the resume contract.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A returning learner with a saved position can get from Home to resumed playback in **one activation** (the Continue card), without using a mini player bar.
- **SC-002**: After leaving the player, **100%** of visits to Home, Discover, Library, and Profile show **no** mini transport bar and **no** continuing background audio from that session.
- **SC-003**: Learners with no practice history see Home **without** a Continue card; they are not shown a placeholder item.
- **SC-004**: On first use of Continue, **at least 90%** of test participants correctly predict that the card resumes the last practiced item (not a random recent) before tapping it.
- **SC-005**: Leaving the player and returning via Continue restores position closely enough that the learner does not hear a different line than the one they left (same cue / same saved time under existing persistence rules).
- **SC-006**: Home Continue card appears in the first screenful on phone and desktop without requiring a hunt below recents; time-to-find the resume control is under **3 seconds** for a learner who already knows Home.
- **SC-007**: Removing the mini bar does not prevent reaching the player: every existing library/recents open path still opens the player, and Continue covers the last-practiced path.

## Assumptions

- Enjoy Player is a **practice** app, not a background-music or podcast app. Leaving the player means leaving playback.
- The prototype Home “Continue learning” hero is the visual intent for this card (prominent 16:9-style hero with progress and metadata). Product copy is **Continue practicing**.
- Saved position and Echo mode already persist today when the learner uses the player; this feature **surfaces** that data on Home and **stops** live collapsed playback. It does not invent a second progress store.
- Collapse / back from the player already returns to the previous tab; after this change that return simply has no mini bar.
- Recents remain “recently updated library items” (import, metadata, last touch). Continue is “last playback session.” If those ever diverge, Continue wins for resume.
- System media controls may exist while the player is actually playing; they must not keep a ghost session after the learner leaves the player.
- Desktop learners who previously collapsed the player to keep listening accept that they now pause and resume from Home or by reopening the item.
- Spec 007’s “tap mini bar to expand” and “always show five practice controls on the mini bar” no longer apply once the mini bar is gone; the five-control guarantee remains on the **player** transport only.
- Native video/YouTube surface hosting while switching routes is an implementation concern; this spec only requires that leaving the player does not keep playing, and that returning to the player still works.

## Implications for related specs

- **007-responsive-player-controls**: Mini-bar expand recovery and mini-bar packing stories are superseded for collapsed chrome. In-player narrow packing (always-on play / echo / blur / captions / speed) remains.
- **033-immersive-flashcard-review** (and vocabulary clip practice): Continue to hide shell chrome during review; they no longer need a special “suppress mini bar” exception because the mini bar is gone app-wide off the player.
