# Tasks: Immersive Flashcard Review

**Input**: Design documents from `/specs/033-immersive-flashcard-review/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required by constitution + plan (widget coverage for shell chrome matrix). Include failing tests before implementation where noted.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Shell**: `lib/features/player/presentation/root_shell.dart`
- **Review UI**: `lib/features/vocabulary/presentation/vocabulary_review_session_screen.dart`
- **Routing**: `lib/core/routing/app_router.dart` (prefer unchanged path `/vocabulary/review`)
- **Tests**: `test/features/player/presentation/root_shell_test.dart`, `test/features/vocabulary/presentation/`
- **Docs**: `docs/features/vocabulary.md`, `docs/decisions/0053-vocabulary-secondary-route.md` (or thin follow-on ADR)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm touch points and implementation branch before code changes

- [x] T001 Confirm plan touch points against tree: `lib/features/player/presentation/root_shell.dart` (`onPlayer` / `showMiniTransport` / `useSidebar`), `lib/features/vocabulary/presentation/vocabulary_review_session_screen.dart`, `lib/core/routing/app_router.dart` (`/vocabulary/review`), `test/features/player/presentation/root_shell_test.dart`, `docs/features/vocabulary.md`, ADR-0053
- [x] T002 [P] Create/switch git branch `033-immersive-flashcard-review` from current base when ready to implement (spec dir already exists)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Test harness + chrome contract readiness that ALL stories share

**⚠️ CRITICAL**: No user story implementation in `root_shell.dart` until this phase is complete

- [x] T003 Extend `_router` in `test/features/player/presentation/root_shell_test.dart` with `GoRoute` stubs for `/vocabulary` and `/vocabulary/review` (placeholder `Scaffold` bodies labeled `vocabulary-page` / `vocabulary-review-page`)
- [x] T004 Add an active-session player stub (pattern from `test/features/player/global_transport_bar_test.dart` `_SessionPlayerController`) and optional override hook in `_shellOverrides` in `test/features/player/presentation/root_shell_test.dart` so mini `GlobalTransportBar` can be asserted present/absent when a session is active
- [x] T005 [P] Re-read [contracts/immersive-review-shell.md](contracts/immersive-review-shell.md) chrome matrix and map each fixture row to planned test names in `root_shell_test.dart` (checklist comment or group title `RootShell immersive vocabulary review`)

**Checkpoint**: Harness can pump `/vocabulary/review` with/without player session — story work can begin

---

## Phase 3: User Story 1 - Enter distraction-free full-window review (Priority: P1) 🎯 MVP

**Goal**: Active `/vocabulary/review` fills the window with no sidebar, bottom nav, or mini player bar

**Independent Test**: Start (or pump) review at `/vocabulary/review` on a wide surface; assert no sidebar search icon, no bottom-nav home icon, no mini-transport play icon — only review content

### Tests for User Story 1

> Write these FIRST; they MUST fail before `RootShell` chrome changes

- [x] T006 [P] [US1] Add wide-surface widget test: `/vocabulary/review` hides `AppSidebar` (`Icons.search_rounded` findsNothing) in `test/features/player/presentation/root_shell_test.dart`
- [x] T007 [P] [US1] Add narrow-surface widget test: `/vocabulary/review` hides bottom nav (`Icons.home_outlined` findsNothing) in `test/features/player/presentation/root_shell_test.dart`
- [x] T008 [P] [US1] Add widget test: `/vocabulary/review` with active player session still hides mini transport (`Icons.play_arrow_rounded` findsNothing) in `test/features/player/presentation/root_shell_test.dart`
- [x] T009 [P] [US1] Add control fixture: `/vocabulary` (hub) with active session still shows mini transport on narrow or wide as today in `test/features/player/presentation/root_shell_test.dart`

### Implementation for User Story 1

- [x] T010 [US1] Add `onReview = path.startsWith('/vocabulary/review')` in `lib/features/player/presentation/root_shell.dart` and fold into `useSidebar` / `bottomNav` / `showMiniTransport` / `bottomClearance` predicates per [contracts/immersive-review-shell.md](contracts/immersive-review-shell.md) and [research.md](research.md) R1
- [x] T011 [US1] Re-run US1 widget tests in `test/features/player/presentation/root_shell_test.dart` until green; confirm `/player/` existing cases still pass

**Checkpoint**: MVP — review route is visually immersive (chrome hidden). Demo-ready.

---

## Phase 4: User Story 2 - Leave review and regain the normal app shell (Priority: P1)

**Goal**: Exiting review restores sidebar/bottom nav and mini transport without a stuck immersive state

**Independent Test**: From `/vocabulary/review`, navigate to `/vocabulary` (or pop); assert chrome returns for the destination

### Tests for User Story 2

- [x] T012 [P] [US2] Add widget test: start at `/vocabulary/review`, `go`/`push` then land on `/vocabulary` (or `/library`), expect sidebar or bottom nav restored in `test/features/player/presentation/root_shell_test.dart`
- [x] T013 [P] [US2] Add widget test: leave `/vocabulary/review` for a non-player shell path with active player session → mini transport visible again in `test/features/player/presentation/root_shell_test.dart`

### Implementation for User Story 2

- [x] T014 [US2] Verify no sticky immersive flag exists — chrome is path-derived only in `lib/features/player/presentation/root_shell.dart` (fix if any local state was introduced); confirm route `onExit` in `lib/core/routing/app_router.dart` still clears session without blocking chrome restore
- [x] T015 [US2] Manually smoke Esc / close → Vocabulary per [quickstart.md](quickstart.md) desktop steps 6–7; note result in PR or task checkbox

**Checkpoint**: Enter + exit immersion both covered

---

## Phase 5: User Story 3 - Keep the learning loop usable while immersed (Priority: P1)

**Goal**: Flip / rate / skip / undo / pronunciation / in-session practice still work without the global player bar

**Independent Test**: Existing review session + Esc tests stay green; clip-practice smoke still viable

### Tests for User Story 3

- [x] T016 [P] [US3] Run `flutter test test/features/vocabulary/presentation/vocabulary_review_escape_test.dart` and fix only if immersion broke Esc/`onExit`
- [x] T017 [P] [US3] Run `flutter test test/features/vocabulary/presentation/vocabulary_review_session_screen_test.dart` and fix only immersion-related regressions (do not change SRS semantics)

### Implementation for User Story 3

- [x] T018 [US3] Confirm `PlayerSurfaceHost` + `practiceOwnsVideoStage` path in `lib/features/player/presentation/root_shell.dart` still parks/attaches during review without requiring mini transport; adjust only if practice smoke fails (see [research.md](research.md) R2)
- [x] T019 [US3] Manual smoke: in-session card actions (flip/rate/skip/pronounce/practice if available) per [quickstart.md](quickstart.md) learning-loop + clip-practice sections

**Checkpoint**: Immersion does not regress the review learning loop

---

## Phase 6: User Story 4 - Immersion works across supported layouts (Priority: P2)

**Goal**: Full-bleed immersion on phone-class, tablet, and desktop widths; resize does not reveal shell chrome mid-session

**Independent Test**: Pump review at narrow and wide surfaces; optionally resize mid-test and assert chrome stays hidden

### Tests for User Story 4

- [x] T020 [P] [US4] Add/extend widget test: `/vocabulary/review` at phone-class size (~400×900) and desktop size (≥ rail breakpoint) both hide nav chrome in `test/features/player/presentation/root_shell_test.dart` (may merge with T006/T007 if already covered — then only add resize case)
- [x] T021 [P] [US4] Add widget test: while on `/vocabulary/review`, change surface size (narrow↔wide) and assert chrome remains hidden in `test/features/player/presentation/root_shell_test.dart`

### Implementation for User Story 4

- [x] T022 [US4] Optional polish: improve card stage use of freed height in `lib/features/vocabulary/presentation/vocabulary_review_session_screen.dart` without reintroducing shell chrome or inventing new max-width tokens beyond existing theme tokens ([research.md](research.md) R3)
- [x] T023 [US4] Manual phone-class + desktop resize check per [quickstart.md](quickstart.md)

**Checkpoint**: All four user stories independently verifiable

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Docs, ADR note, gates

- [x] T024 [P] Update `docs/features/vocabulary.md` so fullscreen/modal review means shell-covering immersion (nav + mini transport hidden for `/vocabulary/review`)
- [x] T025 [P] Add Clarification / Consequences note to `docs/decisions/0053-vocabulary-secondary-route.md` (or add a thin follow-on ADR) documenting path-flag chrome hide while staying under `ShellRoute` ([research.md](research.md) R5)
- [x] T026 Run `flutter analyze` and targeted tests: `root_shell_test.dart`, vocabulary review presentation tests; fix format via `bash .github/scripts/validate_ci_gates.sh --fix` if needed
- [x] T027 Execute remaining [quickstart.md](quickstart.md) checklist and mark done items

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup — **BLOCKS** all user stories that touch tests/`RootShell`
- **US1 (Phase 3)**: Depends on Foundational — **MVP**
- **US2 (Phase 4)**: Depends on US1 chrome flag (path-derived hide/show)
- **US3 (Phase 5)**: Depends on US1 (immersion present); mostly regression
- **US4 (Phase 6)**: Depends on US1; can parallelize with US2/US3 after T010
- **Polish (Phase 7)**: After desired stories complete (minimum US1+US2)

### User Story Dependencies

- **US1**: Foundational only → delivers immersion
- **US2**: Needs US1 `onReview` flag so restore can be proven
- **US3**: Needs US1; no SRS changes
- **US4**: Needs US1; layout polish optional and independent of US2/US3 docs

### Within Each User Story

- Tests (T006–T009, T012–T013, T020–T021) before or with implementation; US1 tests should fail until T010
- `RootShell` change (T010) before exit/layout polish stories that assume immersion

### Parallel Opportunities

- T002 || T001 (setup)
- T006 || T007 || T008 || T009 (US1 tests, same file — serialize if one agent, parallel if careful merge)
- T012 || T013 (US2 tests)
- T016 || T017 (US3 test runs)
- T020 || T021 (US4 tests)
- T024 || T025 (docs)
- After T010: US2 tests, US3 regression runs, and US4 tests can proceed in parallel

---

## Parallel Example: User Story 1

```bash
# After foundational harness (T003–T005), add failing chrome tests together:
# - wide: no AppSidebar on /vocabulary/review
# - narrow: no bottom nav on /vocabulary/review
# - active session: no mini transport on /vocabulary/review
# - control: /vocabulary still shows mini transport with active session

# Then implement onReview in root_shell.dart (T010) and re-run:
flutter test test/features/player/presentation/root_shell_test.dart
```

---

## Parallel Example: After MVP (US1)

```bash
# Parallel tracks:
# A: Exit restore tests T012–T013 + T014
# B: flutter test vocabulary_review_*_test.dart (T016–T017)
# C: Resize immersion tests T020–T021
# D: docs T024–T025
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup
2. Phase 2 Foundational (test harness)
3. Phase 3 US1 — failing tests → `onReview` chrome hide → green
4. **STOP and VALIDATE**: Manual start review on desktop — no sidebar, no player bar
5. Ship/demo if that alone is enough

### Incremental Delivery

1. Setup + Foundational
2. US1 → immersive enter (MVP)
3. US2 → exit restore confidence
4. US3 → learning-loop regression
5. US4 → multi-width + optional stage polish
6. Polish → docs/ADR + CI gates

### Suggested MVP scope

**T001–T011** (Setup + Foundational + US1). That alone satisfies the core product ask: full-window review without distracting shell chrome.

---

## Notes

- Do **not** move `/vocabulary/review` outside `ShellRoute` unless a superseding ADR says so
- Do **not** change SRS / shortcut maps / queue selection
- Do **not** force OS exclusive fullscreen
- `[P]` on tests in the same file means “logically parallelizable”; one agent should apply them sequentially to avoid merge conflicts
- Commit after each phase checkpoint when the user asks for commits
