# Implementation Plan: Immersive Flashcard Review

**Branch**: `033-immersive-flashcard-review` (spec dir; create/switch git branch when implementing) | **Date**: 2026-08-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/033-immersive-flashcard-review/spec.md`

## Summary

Make Vocabulary flashcard review a true full-window immersive session by hiding app shell chrome (sidebar / bottom nav and the persistent mini media player bar) for the duration of `/vocabulary/review`. Keep the route under the existing `ShellRoute` → `RootShell` (ADR-0053) so session lifecycle, Esc pop, and in-session clip practice via `PlayerSurfaceHost` continue to work. Extend the same path-flag pattern already used for `/player/` rather than moving review outside the shell or inventing a second overlay stack.

Optional polish: let the review stage use more of the freed vertical space (still review-essential UI only). No SRS, queue, or shortcut semantic changes.

## Technical Context

**Language/Version**: Dart / Flutter (stable channel); SDK bound in `pubspec.yaml` (`environment: sdk: ^3.12.0`). No SDK bump.

**Primary Dependencies**: Existing GoRouter `ShellRoute`, `RootShell`, Riverpod session providers (`vocabularyReviewSessionProvider`, `playerControllerProvider`). No new pub packages.

**Storage**: N/A — presentation / chrome visibility only; no Drift or preference keys.

**Testing**: `flutter test` — extend `test/features/player/presentation/root_shell_test.dart` for chrome-hidden assertions on `/vocabulary/review` (with and without an active player session); keep existing vocabulary review session / Esc tests green. Manual checks in [quickstart.md](quickstart.md). No `build_runner` expected.

**Target Platform**: Android, iOS, macOS, Windows, Linux. No Flutter web (ADR-0048).

**Project Type**: Flutter native mobile/desktop app.

**Performance Goals**: Chrome hide/restore is a single `RootShell` rebuild driven by route path (O(1)). First interactive card remains under 2s for a typical local book (SC-002); no new async work on enter.

**Constraints**: Do not relocate `/vocabulary/review` outside `ShellRoute` without rewiring practice video staging; do not change SRS / rating / skip / undo / keyboard maps; do not force OS exclusive fullscreen; no new `media_kit` `Player()`; no `print()`.

**Scale/Scope**: One route path flag + shell chrome rules; docs/ADR note; widget tests. Touch surfaces: `RootShell`, optionally `VocabularyReviewSessionScreen` layout polish, feature doc + ADR-0053 note/supersede.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Architecture and Code Quality

- ✅ Chrome policy stays in `RootShell` (shell presentation), not duplicated in vocabulary widgets.
- ✅ Review session notifier / domain / DAOs unchanged — no feature↔feature shortcuts beyond existing shell watch of `practiceOwnsVideoStage`.
- ✅ Route remains under `ShellRoute` per ADR-0053; immersion is a chrome flag, not a new navigation IA.
- ✅ No `print()`; no new `media_kit` `Player()`.

### II. Testing Defines the Contract

- ✅ Widget: `root_shell_test.dart` asserts no sidebar / bottom nav / mini transport on `/vocabulary/review`.
- ✅ Existing review session + Esc/`onExit` tests remain the contract for learning-loop behavior.
- ✅ Manual: desktop + phone-width immersion in quickstart.
- ✅ Codegen not required.

### III. User Experience Consistency

- ✅ Review-essential controls and existing Enjoy primitives on the card stay; only shell chrome hides.
- ✅ Esc / close / pop restore shell automatically when path leaves `/vocabulary/review`.
- ✅ Update `docs/features/vocabulary.md` so “fullscreen” means shell-covering immersion.
- ✅ Record chrome decision relative to ADR-0053 (amend note or thin follow-on ADR if reviewers prefer).

### IV. Performance Is a Requirement

- ✅ Path-derived boolean; no per-frame work beyond existing `RootShell` build.
- ✅ Hiding transport must not dispose the player engine; global playback may continue under the immersive surface (spec assumption).
- ✅ Clip practice (`practiceOwnsVideoStage`) continues to park/attach via existing `PlayerSurfaceHost` path.

### V. Documentation and Traceability

- ✅ Feature doc update required on ship.
- ✅ Architecture note: keep routes under shell; hide chrome via path flag (align with `/player/` pattern).
- ✅ Contracts + quickstart in this spec directory.

**Gate result (pre-research)**: PASS — no violations.

**Gate result (post-design)**: PASS — design extends `RootShell` path flags; data model is chrome visibility only; contracts document shell UI invariants; Complexity Tracking empty.

## Project Structure

### Documentation (this feature)

```text
specs/033-immersive-flashcard-review/
├── plan.md              # This file
├── spec.md
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── immersive-review-shell.md
└── tasks.md             # /speckit-tasks — NOT created here
```

### Source Code (repository root)

```text
lib/features/player/presentation/
├── root_shell.dart                    # PRIMARY: onReview path flag → hide nav + mini transport
└── widgets/
    ├── app_sidebar.dart               # unchanged; simply not mounted
    └── global_transport_bar.dart      # unchanged; simply not mounted

lib/features/vocabulary/presentation/
├── vocabulary_review_session_screen.dart  # optional full-bleed stage polish
└── vocabulary_flashcard.dart              # unchanged learning loop

lib/core/routing/
└── app_router.dart                    # unchanged path `/vocabulary/review` (preferred)

test/features/player/presentation/
└── root_shell_test.dart               # NEW cases for immersive review chrome

docs/features/vocabulary.md            # document immersive shell-covering session
docs/decisions/0053-… or follow-on     # note chrome-hiding without leaving ShellRoute
```

**Structure Decision**: Single Flutter app; change is shell presentation + optional review screen layout polish. No new packages or data layer files.

## Complexity Tracking

> Empty — no constitution violations requiring justification.
