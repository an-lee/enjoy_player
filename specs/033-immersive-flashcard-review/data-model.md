# Data Model: Immersive Flashcard Review

**Feature**: 033-immersive-flashcard-review | **Date**: 2026-08-04

This feature adds **no** Drift tables, preference keys, or domain entities. The “model” is the derived chrome-visibility state of `RootShell` while a review session route is active. Review queue / SRS entities remain those defined in vocabulary foundation + 022.

---

## ShellChromeMode (derived)

Not stored. Derived each `RootShell` build from the current GoRouter path (and existing player/practice flags).

| Mode | Path predicate | Sidebar (wide) | Bottom nav (narrow) | Mini `GlobalTransportBar` |
|------|----------------|----------------|---------------------|---------------------------|
| `normal` | other shell paths | shown when wide | shown when narrow | shown if player session active and not suppressed |
| `player` | `path.startsWith('/player/')` | hidden | hidden | shown as player transport (`Scaffold.bottomNavigationBar`) when session active |
| `vocabularyReview` | `path.startsWith('/vocabulary/review')` | **hidden** | **hidden** | **hidden** (even if player session active) |

**Inputs**:

| Field | Source | Notes |
|-------|--------|-------|
| `path` | `GoRouterState.uri.path` | Prefix match only |
| `sessionActive` | `playerControllerProvider != null` | Unchanged |
| `practiceOwnsVideoStage` | `vocabularyReviewSessionProvider` | Still suppresses transport when true; redundant with `onReview` for mini bar but kept for clarity / non-review callers |

**Validation / invariants**:

- Entering `vocabularyReview` MUST NOT clear or recreate the global playback session by itself.
- Leaving `vocabularyReview` (pop / go away) MUST recompute chrome from the new path on the next build — no sticky immersive flag.
- `/vocabulary` (hub) remains `normal` chrome.
- Session-complete UI that still lives on `/vocabulary/review` stays in `vocabularyReview` mode until the route exits.

---

## ReviewSessionPresentation (unchanged domain)

The flashcard queue, flip/rate/skip/undo, and practice ownership remain `ReviewSessionState` / `vocabularyReviewSessionProvider` as today. Immersion does not add fields.

| Concern | Persistence |
|---------|-------------|
| Queue / ratings / undo | Existing vocabulary DAOs + session notifier |
| Chrome mode | Ephemeral, route-derived |

---

## State transitions (chrome only)

```text
normal  --push /vocabulary/review-->  vocabularyReview
vocabularyReview  --pop / go /vocabulary (or other)-->  normal (or player if landing on /player/)
```

No transition table changes for SRS status machines.
