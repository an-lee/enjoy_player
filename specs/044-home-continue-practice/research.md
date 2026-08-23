# Research: Home Continue Practice

**Date**: 2026-08-23  
**Feature**: [spec.md](./spec.md) | [plan.md](./plan.md)

Phase 0 resolves the technical unknowns behind “Continue practicing on Home” and “no mini player off the player route.” No `[NEEDS CLARIFICATION]` items remain in Technical Context.

## 1. Resume data source

**Decision**: Derive the Continue card from the most recently active `echo_sessions` row (`last_active_at` desc), joined to a still-present library `Media` item. Skip rows whose `target_id` no longer exists. Do **not** use `libraryHomeRecentsProvider` (that list is `Media.updatedAt`, which also moves on import/metadata/touch).

**Rationale**: `PlaybackSessionPersister` already writes `current_time_ms`, `echo_active` / echo window, `blur_active`, and `last_active_at` on the existing `echo_sessions` table. Spec FR-011 requires last **practiced** item, not last library touch. Opening the player already restores position + Echo from that row (`docs/features/player.md`). Surfacing the same row avoids a second progress store (spec assumption).

**Alternatives considered**:

- **First recents tile as Continue** — rejected; import/browse would steal the hero from the last practice item.
- **Live `PlayerController` session** — rejected; after leave-player we clear the live session, so Home would be empty until the next open.
- **New `continue_practice` table** — rejected; duplicates `echo_sessions` with no extra product fields.

## 2. Leave-player lifecycle: `clear()`, not pause-and-keep

**Decision**: When the route leaves `/player/` (collapse, system back, or any navigation), flush the persister then call `PlayerController.clear()` unless vocabulary clip practice currently owns the video stage (`practiceOwnsVideoStage`). Do not keep a paused engine under Home/Discover/Library.

**Rationale**: Spec FR-008 / FR-015 forbid background audio and a live now-playing session off the player. `clear()` already flushes the last ~450 ms of position (swipe-to-dismiss path) and runs `teardownAfterClear`. Pause-and-keep would retain engine, hotkeys, and most of today’s mini-player complexity while only hiding a widget.

**Catch-all**: `collapseExpandedPlayer` should clear **before** `context.pop()`. `RootShell` also listens so Android back / `go_router` pops that skip collapse cannot leak playback.

**Alternatives considered**:

- **Pause, keep `PlaybackSession`** — rejected; hotkeys (`player.togglePlay`) still bind whenever `session != null`, and engines may keep OS now-playing. Spec wants no hidden remote.
- **`clear()` only from swipe-down** — rejected; collapse/back would still leave a live session (today’s mini-player model).

## 3. Mini transport: never mount, then delete mini-only chrome

**Decision**: `RootShell` never sets `showMiniTransport`. `GlobalTransportBar` remains **only** as the player-route `Scaffold.bottomNavigationBar`. In the same feature, remove mini-only behavior: swipe-down dismiss, neutral-area tap-to-expand, expand-icon packing, `PlayerChromeMode.mini` as a reason to show a bar. Keep ADR-0035 **in-player** narrow packing (always-on play / echo / blur / CC / speed).

**Rationale**: Spec FR-007 is a UI guarantee even if a session leaked. Deleting mini branches is the complexity win the product review asked for. `PlayerSurfaceHost` (ADR-0057) is independent and stays.

**Alternatives considered**:

- **Hide mini bar but keep dual-mode widget** — rejected; leaves ADR-0035 expand recovery, snack inset `kRootShellTransportSnackClearance`, and tests that encode the old product.
- **Remove `GlobalTransportBar` entirely** — rejected; spec FR-009 keeps full transport on `/player/`.

## 4. Vocabulary clip exception

**Decision**: Do **not** `clear()` while `vocabularyReviewSession.practiceOwnsVideoStage` is true. Immersive review (`/vocabulary/review`) already hides shell chrome (spec 033); it does not need a mini bar. Clip practice may use the engine off `/player/` and must keep that session.

**Rationale**: Today’s `suppressTransportForVocabularyPractice` exists because clip practice owns the stage. Removing the mini bar must not teardown that engine. After this feature, the suppress flag is unused for chrome (no mini bar) but still gates leave-player `clear()`.

## 5. Language pair and source labels

**Decision**:

- **Content language**: `Media.language` via existing `focusLanguageLabel`.
- **Native / translation side**: `AppPreferencesState.nativeLanguage` (or signed-in profile native when that is the effective pref). Omit the pair when content language is unknown (`und`) **and** native is missing; show a single content label when only one side is known.
- **Source**: existing provider labels (YouTube / Craft) plus `Media.source` when present — not a hard-coded “TED-Ed” string.

**Rationale**: Spec wants a recognizable pair without new persistence. Recents tiles already show a content-language badge; Continue adds native when known so the hero is not a duplicate poster.

## 6. Progress when duration is unknown

**Decision**: `progress = currentTimeMs / durationMs` only when `durationMs > 0`. Otherwise omit the determinate bar (title + artwork still show). Clamp to `[0, 1]`. Completed / near-end items still appear (spec edge case); open uses existing restore rules (ADR-0044).

## 7. Codegen and schema

**Decision**: No Drift schema change. Add DAO **watch/query methods** on existing `EchoSessionDao`. Prefer a **manual** `StreamProvider` (same pattern as `libraryHomeRecentsProvider`) so this feature does not require `build_runner` unless a `@Riverpod` API is introduced. If a generated provider is added, run `dart run build_runner build` and commit `*.g.dart`.

## 8. Related ADRs / specs

**Decision**: New **ADR-0082** records “no global mini player; resume via Home Continue; leave player clears live session.” ADR-0035 remains for **in-player** packing; its collapsed-expand recovery (E1–E7) is superseded. Spec 007 mini-bar stories no longer apply. Spec 033 review chrome is unchanged.

**Alternatives considered**: Rewrite ADR-0035 in place — rejected (ADRs are immutable; supersede).
