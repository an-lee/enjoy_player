# Contract: Immersive Review Shell Chrome

**Feature**: 033-immersive-flashcard-review  
**Consumers**: `RootShell`; `root_shell_test.dart`; Vocabulary review UX  
**Related routes**: `/vocabulary/review` (immersive), `/vocabulary` (normal), `/player/:id` (existing player chrome)

## Path flag

```text
onReview ≡ path.startsWith('/vocabulary/review')
```

MUST use prefix match so trailing segments (if any are added later) remain immersive. MUST NOT treat `/vocabulary` alone as immersive.

## Chrome matrix

| Condition | `AppSidebar` | `EnjoyBottomNav` | Mini `GlobalTransportBar` in shell column |
|-----------|--------------|------------------|-------------------------------------------|
| `onReview == true` | not built | not built | not built |
| `onPlayer == true` | not built | not built | N/A (player uses bottomNavigationBar transport when session active) |
| else, wide ≥ rail breakpoint | built | not built | built if session active ∧ ¬practiceOwnsVideoStage |
| else, narrow | not built | built | built if session active ∧ ¬practiceOwnsVideoStage |

When `onReview`:

- Mini transport MUST be hidden even if `sessionActive` is true.
- `practiceOwnsVideoStage` MAY still be true; video staging continues via `PlayerSurfaceHost` — chrome contract does not disable practice.

## Lifecycle

| Event | Chrome expectation |
|-------|--------------------|
| `context.push('/vocabulary/review')` after non-empty `start` | Immediate immersive mode on first frame of review route |
| Close / Esc pop / system back | Shell chrome of destination restored (typically `/vocabulary` → normal) |
| Session-complete still on `/vocabulary/review` | Remains immersive until leave |
| Route `onExit` clears session | Independent of chrome; chrome follows path only |

## Explicit non-goals (contract)

- MUST NOT require pausing global media on enter.
- MUST NOT change rating key maps, flip, skip, undo, or queue selection.
- MUST NOT relocate the route outside `ShellRoute` as part of this contract.
- MUST NOT hide in-session review controls (close, progress, card actions, shortcut hints).

## Acceptance fixtures (widget tests)

Pump `RootShell` (existing test harness in `root_shell_test.dart`) with:

| Initial location | Player session | Expect |
|------------------|----------------|--------|
| `/vocabulary/review` | null | No sidebar search affordance; no mini transport play control; no bottom nav destinations |
| `/vocabulary/review` | active stub session | Same — mini transport still absent |
| `/vocabulary` | active stub session | Sidebar (wide) or bottom nav (narrow) present; mini transport present |
| `/player/<id>` | active | No sidebar (existing); transport as player bottom bar (existing) |

Wide fixture: width ≥ `breakpointRail`. Narrow fixture: width below rail breakpoint.
