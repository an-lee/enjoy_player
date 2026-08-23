# Data Model: Home Continue Practice

**Date**: 2026-08-23  
**Feature**: [spec.md](./spec.md) | [plan.md](./plan.md) | [research.md](./research.md)

No new Drift tables. Resume reads existing `echo_sessions` + library media.

## Entity: PracticeResume

UI-free domain object (library feature). One optional instance on Home.

| Field | Source | Notes |
|---|---|---|
| `media` | `videos` / `audios` via `target_id` | Full `Media` (title, artwork, duration, language, provider, source) |
| `positionMs` | `echo_sessions.current_time_ms` | Saved playhead |
| `echoActive` | `echo_sessions.echo_active` | Show Echo badge when true |
| `lastActiveAt` | `echo_sessions.last_active_at` | Ordering key; not shown |
| `sessionId` | `echo_sessions.id` | For tests / debug; not shown |

Derived (presentation, not stored):

| Field | Rule |
|---|---|
| `progress` | `positionMs / media.durationMs` when `durationMs > 0`, else `null` |
| `languagePairLabel` | Content tag + native tag when known (see research §5) |
| `sourceLabel` | YouTube / Craft / `Media.source` as available |

### Validation

- Emit **null** (hide card) when there is no `echo_sessions` row, or every recent session’s media is missing.
- Skip deleted media: walk latest sessions by `last_active_at` until a resolvable `Media` is found (cap lookback, e.g. 20 rows).
- Do not invent a placeholder TED-style item.
- `progress` omitted rather than `0` / `1` when duration is unknown.

### Relationships

```text
EchoSessionRow (1) --target_id--> Media (0..1)
Home recents (N) --updated_at--> Media   // independent of PracticeResume
PlaybackSession (live) --mediaId--> Media // exists only on /player/ (and vocab clip)
```

## Entity: Live playback session (existing)

`PlayerController` / `PlaybackSession` is **not** the Continue card source after leave-player. Leaving `/player/` flushes then `clear()`s this object (except vocabulary clip ownership). Re-open via `openPlayerRoute` restores from `echo_sessions` as today.

### State transitions

```text
[no live session]
    | open /player/:id
    v
[live session on player]  -- persist --> echo_sessions
    | leave /player/ (not vocab clip)
    v
[no live session] + echo_sessions row remains
    | Continue card / recents / Library open
    v
[live session on player] at saved position
```

```text
[live session] + practiceOwnsVideoStage
    | leave /player/ to vocabulary clip
    v
[live session kept]  // no mini bar; no clear()
```

## Persistence (existing columns used)

`echo_sessions` (no migration):

- `target_type`, `target_id` — join key  
- `current_time_ms` — progress numerator  
- `echo_active` — Echo badge  
- `last_active_at` — “last practiced”  
- `blur_active` / echo window — restored on open, not required on the card  

`videos` / `audios`: `duration`, language, title, thumbnails, provider, source.

## Recents (unchanged)

`libraryHomeRecentsProvider`: up to 12 media by `updatedAt`. May include the Continue item. Not a substitute for `PracticeResume`.
