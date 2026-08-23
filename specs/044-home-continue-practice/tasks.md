# Tasks: Home Continue Practice

**Input**: Design documents from `/specs/044-home-continue-practice/`

**Prerequisites**:
- `plan.md` (required)
- `spec.md` (required — user stories US1–US4)
- `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: Required — constitution II, `plan.md` constitution check, and `quickstart.md` enumerate automated tests. Write tests FIRST and confirm they FAIL before implementation.

**Organization**: Tasks are grouped by user story so each story can be implemented, tested, and delivered as an independent increment. Phase 3 (US1) is the MVP.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks).
- **[Story]**: US1, US2, US3, US4 — maps to `spec.md`.
- All paths are relative to the repository root.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Isolate work on the feature branch named in the plan.

- [x] T001 Create and check out git branch `044-home-continue-practice` from current `main` in the repo root (plan branch name; working tree was still `main` at planning time).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared domain, DAO query, and l10n used by Continue (US1/US3/US4). Leave-player helpers wait for US2 so US1 can ship a card without touching shell chrome.

**⚠️ CRITICAL**: No user-story implementation until this phase is complete.

- [x] T002 [P] Add UI-free `PracticeResume` in `lib/features/library/domain/practice_resume.dart` with `media`, `positionMs`, `echoActive`, `lastActiveAt`, `sessionId`, equality/`==` for stream distinct, and derived `progress` (`positionMs / durationMs` when `durationMs > 0`, else `null`) per `specs/044-home-continue-practice/data-model.md`.
- [x] T003 [P] Add `watchRecentByLastActiveAt({int limit = 20})` (and matching `listRecent…` if useful for tests) on `EchoSessionDao` in `lib/data/db/daos/echo_session_dao.dart` ordered by `last_active_at` desc — no schema migration.
- [x] T004 [P] Add ARB keys `homeContinuePracticing`, `homeContinueProgressSemantics`, `homeContinueOpenSemantics` to `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, and `lib/l10n/app_zh_CN.arb` per `specs/044-home-continue-practice/contracts/localization.md`, then run `flutter gen-l10n`.

**Checkpoint**: Foundation ready — `PracticeResume` compiles, DAO methods exist, l10n generates. User stories can start (US1 and US2 in parallel).

---

## Phase 3: User Story 1 — Resume practice from Home in one tap (Priority: P1) 🎯 MVP

**Goal**: Home shows a Continue practicing hero for the last practiced item (title, artwork, progress, Echo when relevant, language pair when known). Tapping it opens the player at the saved position with the last practice mode.

**Independent Test**: With a saved `echo_sessions` row for one library item, open Home, confirm the card, tap it, confirm `/player/:id` at saved position. `quickstart.md` Scenario A.

### Tests for User Story 1 (REQUIRED — write first, confirm they fail)

- [x] T005 [P] [US1] Extend `test/data/db/daos/echo_session_dao_test.dart` so `watchRecentByLastActiveAt` / list returns sessions by `last_active_at` desc and respects `limit`.
- [x] T006 [P] [US1] Add `test/features/library/application/home_continue_practice_provider_test.dart` covering: resume follows last session not recents `updatedAt`; `null` when no sessions; `progress` omitted when `durationMs == 0`; Echo flag mapped from `echo_active`.
- [x] T007 [P] [US1] Add `test/features/library/presentation/continue_practice_card_test.dart` covering: hidden when resume is null (widget not built / placeholder absent); title + progress when duration known; Echo when `echoActive`; tap invokes open-player for that `media.id`.

### Implementation for User Story 1

- [x] T008 [US1] Add `homeContinuePracticeProvider` in `lib/features/library/application/home_continue_practice_provider.dart` — watch latest sessions, resolve `Media` via `MediaLibraryRepository.getById`, skip missing targets (lookback cap 20), `distinctBy` equality; native language from `appPreferencesProvider` for pair labels in presentation (keep domain UI-free).
- [x] T009 [P] [US1] Add `ContinuePracticeCard` in `lib/features/library/presentation/widgets/continue_practice_card.dart` per `specs/044-home-continue-practice/contracts/continue-practice-card.md`: 16:9 hero, `EnjoyTappableSurface`, localized title, artwork (file/network/generative cover, **no** `palette_generator`), Echo + language pair + determinate progress when known, semantics, `Haptics`, `openPlayerRoute`.
- [x] T010 [US1] Insert the Continue sliver into `lib/features/library/presentation/home_screen.dart` after `_HomeInsightCards` and before recents/empty state; hide when provider is `null`; keep recents grid unchanged; do not show a fake TED hero on the loading skeleton.

**Checkpoint**: US1 independently testable. Mini bar may still exist until US2.

---

## Phase 4: User Story 2 — Leave the player without a mini bar (Priority: P1)

**Goal**: Leaving `/player/` stops playback and never shows collapsed transport on Home/Discover/Library/Profile. Full transport remains on the player route. Vocabulary clip (`practiceOwnsVideoStage`) is not cleared.

**Independent Test**: Play, leave to Home and Library — no mini bar, no audio; Continue (if US1 done) or re-open still restores position. `quickstart.md` Scenarios B and E.

### Tests for User Story 2 (REQUIRED — write first, confirm they fail)

- [x] T011 [P] [US2] Rewrite mini-bar cases in `test/features/player/presentation/root_shell_test.dart`: no `GlobalTransportBar` on `/`, `/library`, `/vocabulary` even with an injected session; still one bar on `/player/`; review route still has no bar (former “restore mini after review” becomes “still no mini”).
- [x] T012 [P] [US2] Add `test/features/player/application/leave_player_clears_session_test.dart` covering: off-player + live session calls `clear()`; `practiceOwnsVideoStage` skips `clear()`.
- [x] T013 [P] [US2] Update `test/features/player/player_collapse_test.dart` so collapse pops the route and does not leave a live `playerControllerProvider` session.
- [x] T014 [P] [US2] Update `test/features/player/global_transport_bar_test.dart`: remove collapsed expand (US3) / mini-route groups; keep in-player always-on packing (play/echo/blur/cc/speed) and drop order for previous/next/volume.
- [x] T015 [P] [US2] Update `test/features/hotkeys/app_hotkeys_keyboard_listener_test.dart` so play/expand-from-mini do not assume mini chrome; null session off-player is a no-op.

### Implementation for User Story 2

- [x] T016 [US2] Add leave-player policy helper in `lib/features/player/application/leave_player_session.dart` — flush+`PlayerController.clear()` when leaving `/player/` unless `practiceOwnsVideoStage`, per `specs/044-home-continue-practice/contracts/leave-player-playback.md`.
- [x] T017 [US2] Call the helper from `collapseExpandedPlayer` in `lib/features/player/application/player_collapse.dart` **before** `context.pop()`.
- [x] T018 [US2] In `lib/features/player/presentation/root_shell.dart` remove `showMiniTransport` / mini `GlobalTransportBar`; stop adding `kRootShellTransportSnackClearance` when no bar; listen for `session != null && !onPlayer && !practiceOwnsVideoStage` and clear (system back). Keep player-route `bottomNavigationBar: GlobalTransportBar`.
- [x] T019 [US2] Remove mini-only chrome from `lib/features/player/presentation/widgets/global_transport_bar.dart` (swipe-down dismiss, neutral-area tap-to-expand, expand-icon packing). Keep ADR-0035 in-player narrow packing. Drop unused expand droppable from `resolveNarrowTransportBudget` if it exists only for mini.

**Checkpoint**: US2 independently testable. Player transport intact; no mini bar off-player.

---

## Phase 5: User Story 3 — Home with nothing to resume (Priority: P2)

**Goal**: No Continue card when the learner never practiced, library is empty, or the last session’s media is gone (skip to next valid session or hide). Recents empty state unchanged.

**Independent Test**: Empty library / no sessions → no Continue, existing empty Home. Deleted last item → no phantom card. `quickstart.md` Scenario C.

### Tests for User Story 3 (REQUIRED — write first, confirm they fail)

- [x] T020 [P] [US3] Extend `test/features/library/application/home_continue_practice_provider_test.dart` (or add cases): no sessions → null; session whose media is missing → skip to next valid or null; recents populated without any `echo_sessions` → Continue still null.
- [x] T021 [P] [US3] Extend `test/features/library/home_screen_test.dart`: empty recents + null Continue shows existing empty copy (`homeEmptyTitle`) and **no** Continue title; insight cards still show.

### Implementation for User Story 3

- [x] T022 [US3] Finish lookback-skip of deleted media in `lib/features/library/application/home_continue_practice_provider.dart` (and DAO list if needed) so Home never builds `ContinuePracticeCard` for a missing `Media`.
- [x] T023 [US3] Confirm `lib/features/library/presentation/home_screen.dart` loading skeleton and empty recents path never render a placeholder Continue hero.

**Checkpoint**: US1 + US3: card only when a real resume item exists.

---

## Phase 6: User Story 4 — Continue is resume; recents are browse (Priority: P2)

**Goal**: Continue is last **practiced** item; recents stay a browse grid. Same title may appear twice; hero is visually distinct (16:9, progress, Echo), not a duplicate `MediaCardTile`.

**Independent Test**: Practice A, then touch/import B so B is first recent — Continue is still A. `quickstart.md` Scenario D.

### Tests for User Story 4 (REQUIRED — write first, confirm they fail)

- [x] T024 [P] [US4] Extend `test/features/library/application/home_continue_practice_provider_test.dart`: after practicing A, bumping B’s `updatedAt` does not change Continue away from A.
- [x] T025 [P] [US4] Extend `test/features/library/home_screen_test.dart`: when both resume and recents exist, Continue hero is present **and** recents grid/`MediaCardTile` still present (not replaced).

### Implementation for User Story 4

- [x] T026 [US4] Verify `lib/features/library/presentation/home_screen.dart` keeps recents `SliverGrid` of `_HomeMediaTile` / `MediaCardTile` below Continue; do not reuse `ContinuePracticeCard` as a grid tile or omit recents when Continue is showing.
- [x] T027 [US4] Confirm `PracticeResume` equality in `lib/features/library/domain/practice_resume.dart` ignores unrelated library `updatedAt` so recents ticks do not rebuild the hero (P-1).

**Checkpoint**: All four stories independently functional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Docs, ADR, leftover mini-player copy, quality gates.

- [x] T028 [P] Add `docs/decisions/0082-home-continue-no-mini-player.md` (leave player = `clear()`; no global mini bar; Home Continue is resume; ADR-0035 E1–E7 superseded; in-player packing remains) and index it in `docs/decisions/README.md`.
- [x] T029 [P] Update `docs/features/player.md`, `docs/features/app-ui.md`, `docs/features/library.md`, `docs/architecture.md`, and `docs/tech-stack.md` to remove “persistent mini player” / collapsed transport as product chrome; document Continue + player-only transport.
- [x] T030 [P] Trim vocabulary/review docs that only exist to “suppress mini bar” in `docs/features/vocabulary.md` if they now over-specify chrome (keep immersive review hide-nav behavior).
- [x] T031 Remove unused mini-only l10n keys from `lib/l10n/app_en.arb` (and zh / zh_CN) **only** if nothing references them; keep `miniPlayerMediaVideo` / `miniPlayerMediaAudio` used by recents in `lib/features/library/presentation/home_screen.dart`.
- [x] T032 Run `flutter analyze`, `flutter test`, and `bash .github/scripts/validate_ci_gates.sh` from repo root; fix format/codegen drift. Run `dart run build_runner build` only if a `@Riverpod` annotation was added and commit `*.g.dart`.
- [ ] T033 Manual pass of `specs/044-home-continue-practice/quickstart.md` Scenarios A–E on at least one desktop or mobile target.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS story implementation (tests for stories may be written in parallel after T002–T004 exist enough to compile against).
- **US1 (Phase 3)** and **US2 (Phase 4)**: Both depend on Phase 2; **do not depend on each other** (different files). Can run in parallel.
- **US3 (Phase 5)**: Depends on US1 provider + Home insert (T008–T010).
- **US4 (Phase 6)**: Depends on US1 card + recents remaining.
- **Polish (Phase 7)**: Depends on the stories you intend to ship (MVP = US1; full = US1–US4).

### User Story Dependencies

- **US1 (P1)**: After Phase 2. MVP.
- **US2 (P1)**: After Phase 2. Parallel with US1.
- **US3 (P2)**: After US1.
- **US4 (P2)**: After US1.

### Within Each User Story

- Tests MUST be written and FAIL before implementation.
- Domain/DAO already in Phase 2; story work is provider → widget → screen (US1) or policy → collapse → shell → transport (US2).
- Story complete before starting the next *dependent* story (US3/US4).

### Parallel Opportunities

- T002, T003, T004 in Phase 2.
- T005, T006, T007 (US1 tests).
- T011–T015 (US2 tests).
- T009 vs T008 once T002–T004 exist (card vs provider; card can take a constructed `PracticeResume`).
- After Phase 2: Developer A on US1, Developer B on US2.
- T028, T029, T030 in Polish.

---

## Parallel Example: User Story 1

```text
# After Phase 2, launch US1 tests together:
T005 echo_session_dao_test.dart
T006 home_continue_practice_provider_test.dart
T007 continue_practice_card_test.dart

# Then implementation:
T008 home_continue_practice_provider.dart
T009 continue_practice_card.dart   # [P] with T008 if card is fed a fake resume in tests
T010 home_screen.dart              # after T008 + T009
```

## Parallel Example: User Story 2

```text
T011 root_shell_test.dart
T012 leave_player_clears_session_test.dart
T013 player_collapse_test.dart
T014 global_transport_bar_test.dart
T015 app_hotkeys_keyboard_listener_test.dart

# Then:
T016 leave_player_session.dart
T017 player_collapse.dart
T018 root_shell.dart
T019 global_transport_bar.dart
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 + Phase 2
2. Phase 3 (US1) — Continue card on Home
3. **STOP and VALIDATE** with `quickstart.md` Scenario A
4. Demo: resume without needing the mini bar to exist (mini may still show until US2)

### Incremental Delivery

1. Setup + Foundational
2. US1 → Continue hero (MVP)
3. US2 → remove mini bar / clear on leave (product rule)
4. US3 → empty / missing media
5. US4 → Continue vs recents distinction tests + visual lock
6. Polish: ADR-0082 + docs + CI gates

### Parallel Team Strategy

1. Together: T001–T004
2. Then: A = US1 (T005–T010), B = US2 (T011–T019)
3. Then: US3 + US4 on the Home/provider files (serialize those)
4. Together: Phase 7

---

## Notes

- [P] = different files, no incomplete-task dependency.
- Do not instantiate `package:media_kit` `Player()` outside `PlayerController`.
- Do not remove `PlayerSurfaceHost`.
- Skip `clear()` when `practiceOwnsVideoStage` is true.
- Product copy is **Continue practicing**, not Continue learning.
- Commit after each task or logical group if the user asks for commits; otherwise leave the working tree for `/speckit-implement`.
