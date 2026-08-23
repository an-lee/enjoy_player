# Implementation Plan: Home Continue Practice

**Branch**: `044-home-continue-practice` | **Date**: 2026-08-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/044-home-continue-practice/spec.md`

## Summary

Replace the global mini player with a Home **Continue practicing** hero. The card reads the latest `echo_sessions` row joined to library media (position, Echo, languages, progress). Leaving `/player/` flushes persistence and `PlayerController.clear()` so nothing plays under Home/Discover/Library. `GlobalTransportBar` stays only on the player route. `PlayerSurfaceHost` is unchanged.

This is a product-scope shell change (new ADR-0082). In-player narrow packing (ADR-0035 C1–C6) remains; mini-bar expand recovery (E1–E7) is superseded.

## Technical Context

**Language/Version**: Dart 3.x on Flutter stable (matches `pubspec.yaml` minimum SDK).

**Primary Dependencies**:

- `flutter_riverpod` — Home resume stream + leave-player listener.
- `drift` — existing `EchoSessionDao` watch/query (no schema migration).
- `go_router` — `/player/` vs shell routes.
- `package:logging` via `logNamed` (never `print`).
- No new third-party packages.

**Storage**: Local SQLite via Drift `echo_sessions` + `videos` / `audios`. No new tables or columns.

**Testing**: `flutter test` unit (DAO, resume mapping, leave-player clear) and widget (Continue card, Home, RootShell, transport bar, collapse, hotkeys). `flutter analyze`. `bash .github/scripts/validate_ci_gates.sh` before push. `dart run build_runner build` only if a `@Riverpod` / Drift annotation is added.

**Target Platform**: Android, iOS, macOS, Windows, Linux (constitution v1.2.0). No Flutter web.

**Project Type**: Cross-platform Flutter desktop + mobile app.

**Performance Goals**:

- P-1: Continue stream must not rebuild Home on every persister tick when the resume **identity** (media id, position bucket, echo flag) is unchanged — `distinctBy` / equality on `PracticeResume` (same idea as `libraryHomeRecentsProvider`).
- P-2: Card build must not run `palette_generator` (use generative cover seed / existing thumbs, same as recents tiles).
- P-3: Leave-player `clear()` must stop audible playback before the next frame of Home is interactive (flush + teardown on the existing clear path).
- P-4: Home first screenful remains scroll-smooth; one extra sliver (the hero) is in budget.

**Constraints**:

- Single `media_kit` `Player` owned only by `PlayerController` / `MediaKitPlayerEngine`.
- Vocabulary clip (`practiceOwnsVideoStage`) must not be cleared when leaving `/player/`.
- Offline/local-first: Continue is a local Drift read; no network required to show the card.
- Localization: ARB en + zh.

**Scale/Scope**:

- One optional hero on Home; recents stay ≤12 tiles.
- DAO lookback capped (~20 sessions) when skipping deleted media.
- Docs: `player.md`, `app-ui.md`, `architecture.md`, `library.md`, ADR-0082, ADR index.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Architecture & Code Quality — feature-first | **Pass** | Resume domain + provider under `lib/features/library/`; leave-player policy under `lib/features/player/`; Drift access via `EchoSessionDao`. Home already opens the player through `openPlayerRoute` (no new feature-to-feature shortcut). |
| I. — Drift DAOs + Riverpod | **Pass** | No raw SQL in widgets. Manual `StreamProvider` matching recents (or `@Riverpod` + committed codegen). |
| I. — Domain UI-free | **Pass** | `PracticeResume` has no `BuildContext`. |
| II. Testing Defines the Contract | **Pass (required tests)** | See `quickstart.md` table (DAO, provider, card, Home, RootShell, leave-player, transport, collapse, hotkeys). |
| II. — `build_runner` | **Pass** | Not required unless annotations change. |
| III. UX Consistency | **Pass** | `EnjoyTappableSurface` (or equivalent), `Haptics`, `EnjoyPage` browse gutter, ARB strings, prototype 16:9 hero intent. |
| III. — `docs/features/` | **Pass (required)** | Update player, app-ui, library; architecture mini-player sentence. |
| IV. Performance | **Pass** | P-1–P-4 stated; no per-tile palette extraction. |
| V. Documentation & Traceability | **Pass (required)** | ADR-0082 (costly product reversal: no global mini player). |

No constitution violations.

## Project Structure

### Documentation (this feature)

```text
specs/044-home-continue-practice/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── continue-practice-card.md
│   ├── leave-player-playback.md
│   └── localization.md
├── checklists/
│   └── requirements.md
└── spec.md
```

### Source Code (repository root)

```text
lib/
├── data/db/daos/echo_session_dao.dart
│     # watch/list latest sessions by last_active_at
├── features/library/
│   ├── domain/practice_resume.dart                    # NEW
│   ├── application/home_continue_practice_provider.dart  # NEW StreamProvider
│   └── presentation/
│       ├── home_screen.dart                           # insert Continue sliver
│       └── widgets/continue_practice_card.dart        # NEW hero
├── features/player/
│   ├── application/player_collapse.dart               # clear() before pop
│   ├── application/leave_player_session.dart          # NEW shared policy
│   ├── application/player_ui_provider.dart            # mini mode no longer drives a bar
│   ├── presentation/root_shell.dart                   # no showMiniTransport; leave listener
│   └── presentation/widgets/global_transport_bar.dart # delete mini-only branches
├── features/hotkeys/presentation/app_hotkeys_keyboard_listener.dart
│     # expand-from-mini path becomes unused once session is cleared
└── l10n/*.arb

test/
├── data/db/daos/echo_session_dao_test.dart            # extend
├── features/library/application/home_continue_practice_provider_test.dart
├── features/library/presentation/continue_practice_card_test.dart
├── features/library/home_screen_test.dart             # extend
├── features/player/application/leave_player_clears_session_test.dart
├── features/player/presentation/root_shell_test.dart  # rewrite mini cases
├── features/player/global_transport_bar_test.dart     # drop US3 mini expand
├── features/player/player_collapse_test.dart
└── features/hotkeys/app_hotkeys_keyboard_listener_test.dart

docs/
├── features/player.md
├── features/app-ui.md
├── features/library.md
├── architecture.md
├── tech-stack.md                                      # drop “persistent mini player”
└── decisions/0082-home-continue-no-mini-player.md     # NEW
```

**Structure Decision**: Single Flutter app, feature-first layout. No new top-level packages.

## Complexity Tracking

> **No violations to justify.**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | — | — |

## Constitution Check (post-design)

Re-evaluated after `research.md`, `data-model.md`, `contracts/*`, and `quickstart.md`.

| Principle | Status | Notes |
|---|---|---|
| I. Architecture & Code Quality | **Pass** | Library owns Continue read-model; player owns leave-player `clear()`. `PlayerSurfaceHost` untouched. |
| II. Testing Defines the Contract | **Pass** | Quickstart maps tests to FR-001–FR-015 and US1–US4. |
| III. UX Consistency | **Pass** | Card contract specifies `EnjoyTappableSurface`, semantics, ARB, 16:9 hero vs recents grid. |
| IV. Performance | **Pass** | Distinct resume stream + no `palette_generator` on the hero. |
| V. Documentation | **Pass** | ADR-0082 + feature docs listed. ADR-0035 not rewritten. |
| Flutter Quality Gates | **Pass** | `validate_ci_gates.sh`, `flutter analyze`, `flutter test`; codegen only if annotations change. |

No constitution violations. Plan is ready for `/speckit-tasks`.

## Open questions resolved during research

1. **Pause vs clear on leave** → `clear()` after persister flush. Pause-and-keep would leave hotkeys and engines live (FR-015).
2. **Continue vs recents** → `echo_sessions.last_active_at`, not `Media.updatedAt`.
3. **Schema** → none; existing columns suffice.
4. **Mini widget deletion** → same feature, not a follow-up, so complexity actually drops.
5. **Vocabulary clip** → skip `clear()` when `practiceOwnsVideoStage`.
6. **Language pair** → `Media.language` + preferences native; omit missing sides.
7. **ADR-0035** → keep in-player packing; supersede mini expand via ADR-0082.
