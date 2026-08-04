# Research: Immersive Flashcard Review

**Feature**: 033-immersive-flashcard-review | **Date**: 2026-08-04

No `NEEDS CLARIFICATION` markers remained in the spec. This file records technical decisions that turn the assumptions into an implementable design.

---

## R1. How to hide shell chrome for review

**Decision**: Extend `RootShell` with a path flag parallel to `onPlayer`:

```text
onReview = path.startsWith('/vocabulary/review')
useSidebar = wide && !onPlayer && !onReview
bottomNav  = !useSidebar && !onPlayer && !onReview
showMiniTransport = sessionActive && !playerWithTransport
    && !suppressTransportForVocabularyPractice
    && !onReview
```

Keep `/vocabulary/review` registered under the existing `ShellRoute` (ADR-0053).

**Rationale**: Today review is nested inside `RootShell`’s content pane, so sidebar and `GlobalTransportBar` stay visible — that is the non-immersive frame in the product screenshot. `/player/` already proves path-driven chrome hiding. Covering both nav and mini transport for the whole review session matches FR-001/FR-002 without a second navigation stack.

**Alternatives considered**:

- *Move `/vocabulary/review` outside `ShellRoute`.* Rejected: breaks `PlayerSurfaceHost` stacking / clip practice (`practiceOwnsVideoStage`), complicates Esc/`onExit`, and fights ADR-0053.
- *Full-screen `Navigator` overlay / modal route above the shell.* Rejected: duplicates session lifecycle and focus/hotkey ownership already handled by the push route; harder to keep practice video staging correct.
- *Only hide sidebar, keep player bar.* Rejected by spec (“no other things distractive” + hide persistent media player bar).
- *OS exclusive window fullscreen.* Rejected by spec assumption (app window content area only).

---

## R2. Relationship to clip-practice transport suppression

**Decision**: Keep `suppressTransportForVocabularyPractice` (`practiceOwnsVideoStage`) as-is. Immersive review adds `!onReview` so the mini bar is hidden for the **entire** session, not only while practice owns the video stage. Practice attach/park logic stays on `PlayerSurfaceHost` + session state.

**Rationale**: Spec requires no global player bar during review. Practice already needed transport hidden for clip UI; immersion makes that the default for the route. Exit review (path change) restores transport when a session is still active and not on `/player/`.

**Alternatives considered**:

- *Rely only on `practiceOwnsVideoStage`.* Rejected: leaves the mini bar visible for normal flip/rate cards (current bug relative to the immersive goal).
- *Pause/stop global media on enter review.* Rejected: out of scope; spec says playback is not newly required to stop.

---

## R3. Review screen layout polish vs chrome-only

**Decision**: **Mandatory** work is `RootShell` chrome hiding. **Optional** polish on `VocabularyReviewSessionScreen`: use more of the freed height for the card stage; do not reintroduce shell chrome. Keep custom `Scaffold` (no requirement to switch to `EnjoyPage`); page kind alone cannot hide shell chrome.

**Rationale**: Spec says visual restyling is optional; immersion via chrome removal is mandatory. Card already centers with `contentMaxWidth` clamps — widening the stage is nice-to-have once the sidebar/player gutters are gone.

**Alternatives considered**:

- *Adopt `EnjoyPageKind.playerChrome`.* Acceptable later; not required for FR-001–FR-002. Shell path flag remains necessary either way.
- *Redesign flashcard visuals.* Deferred; out of mandatory scope.

---

## R4. Exit and Esc behavior

**Decision**: No change to exit semantics. Close → `pop` (or `go('/vocabulary')`); Esc remains global `modal.close` / GoRouter pop; `onExit` on the review route continues to clear the session while context is mounted. Chrome restores automatically when `path` no longer starts with `/vocabulary/review`.

**Rationale**: Spec FR-004/FR-005 and existing tests (`vocabulary_review_escape_test.dart`) already encode this. Immersion must not add a second Esc handler in-session.

**Alternatives considered**:

- *In-session Esc handler.* Rejected previously (double-pop risk); still rejected.

---

## R5. Documentation / ADR

**Decision**: Update `docs/features/vocabulary.md` journey text so fullscreen review means shell-covering immersion (nav + mini transport hidden). Add a short note to ADR-0053 Consequences (or a thin follow-on ADR if the team prefers not to edit Accepted ADRs beyond a “Clarification” section) stating that review stays under `ShellRoute` but `RootShell` hides chrome on that path—same family as `/player/` nav hiding.

**Rationale**: Constitution V — behavior changes need feature docs; chrome policy is costly to reverse relative to “always show shell around secondary routes.”

**Alternatives considered**:

- *Docs-only, no ADR touch.* Weaker for future “why isn’t review outside the shell?” debates; prefer a one-paragraph clarification.
