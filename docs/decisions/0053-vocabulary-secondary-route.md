# ADR-0053: Vocabulary secondary route

## Status

Accepted

## Context

Vocabulary P1 needs a browsable destination (stats, Review, All Words) and a
fullscreen review session. The adaptive shell already has four primary
destinations (Home / Discover / Library / Profile). Enjoy web exposes
Vocabulary as a sidebar item; Flutter open decision was shell tab vs secondary
entry ([docs/features/vocabulary.md](../features/vocabulary.md)).

Craft, Credits, and Subscription already use push routes under `ShellRoute`
without claiming a primary tab.

## Decision

1. Register **`/vocabulary`** and **`/vocabulary/review`** as `ShellRoute`
   siblings (same pattern as `/craft`, `/credits`).
2. Enter Vocabulary from a **Profile** `SettingsRow` via `context.push`.
3. Do **not** add a primary bottom-nav / rail destination for Vocabulary.
4. Review session keyboard shortcuts stay **in-session only** (not global
   `AppHotkeys`).

## Consequences

- Learners reach Vocabulary in one tap from Profile; IA stays uncluttered.
- Deep links and widget tests can target `/vocabulary` without shell tab
  index changes.
- A future home due nudge can still `push('/vocabulary')` without this ADR
  changing.
- Supersedes the open navigation decision in the vocabulary feature doc for
  P1; does not rewrite ADR-0009 shell structure.

## Clarification (immersive review chrome)

`/vocabulary/review` remains a `ShellRoute` sibling. Immersion is achieved by a
`RootShell` path flag (`path.startsWith('/vocabulary/review')`) that hides the
sidebar / bottom nav and the mini `GlobalTransportBar` for the duration of the
session — the same path-flag family as `/player/` nav hiding. Leaving the route
restores chrome automatically (path-derived; no sticky flag). See
`specs/033-immersive-flashcard-review/`.

## References

- Feature: [docs/features/vocabulary.md](../features/vocabulary.md)
- Spec: `specs/022-vocabulary-screen-review/`
- Immersive chrome: `specs/033-immersive-flashcard-review/`
- Related: [ADR-0009](0009-platform-adaptive-shell.md), [ADR-0052](0052-vocabulary-local-first-schema.md)
