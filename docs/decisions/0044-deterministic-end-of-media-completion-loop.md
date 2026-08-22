# ADR-0044: Deterministic end-of-media handling with generation-guarded completion loop

## Status

Accepted

## Context

Before this decision the player had **no end-of-media handler at all** on the MediaKit path. The only transport-side boundary logic (echo pause-and-rewind) was reactive on position ticks, not driven by a deterministic future. When a non-echo track played to the end, nothing looped, advanced, or stopped — mpv stopped on its own and the UI froze on the last position tick with `playing: false`. `RepeatMode` was persisted but never read in the playback path (issue #307, gaps G1–G7).

The single-flight + generation-counter shape had just landed as the canonical approach via `EchoEnforcer._epoch` / `PlayerController._openGeneration` (#280 / #279-A). Generalizing it to all transport completion is the natural next step and keeps one mental model across the feature.

## Decision

Surface a `Stream<void> get completed` event through the `PlayerEngine` contract and drive transport decisions off a **deterministic await-completion loop** — the [`CompletionLoop`](../../lib/features/player/application/completion_loop.dart) module owned by `PlayerController`:

### 1. Engine contract

- **MediaKit**: forwards `Player.stream.completed`.
- **YouTube**: synthesized from the existing HTML5 `<video>` `ended` event / poll loop via `YoutubeSession.markCompleted()` — an idempotent transition guard that emits on the first `ended` and is re-armed by `resetForOpen`. EOM detection on YouTube lags media_kit by up to ~250 ms (the poll cadence), which remains acceptable per ADR-0015.

### 2. Generation-guarded completion loop

`CompletionLoop._run` mirrors the generation-counter + single-flight pattern:

```
while (gen == _playbackGen && !_disposed) {
  await engine.completed;                      // deterministic: fires on real EOM
  if (gen != _playbackGen) return;             // media switched under us → bail
  switch (repeatMode) {
    case single:  await seek(zero); await play(); break;
    case segment: await seek(echoStart); await play(); break;  // only when echo active
    case none:    return;                          // stop
  }
}
```

- **`_playbackGen`** is bumped on `openMedia`, `clear`, `abandonPendingOpen`, `seekTo`, and disposal — every event that invalidates the current playback stint. A completion handler that observes `gen != _playbackGen` is a silent no-op.
- The in-flight `engine.completed` await is **cancelable** via a `Completer<void>` that `bump()` completes, so a stale wait doesn't block until the next media's EOM.
- The single-flight marker is **keyed by generation** (`_activeLoopGen`), not a bare flag: a bumped loop that is still draining cannot block `arm()` for the new stint, and its late `finally` cannot clear a newer loop's marker. (A bare-flag marker silently wedged the loop after every bump — repeat stopped working after any seek or second open — fixed during the `CompletionLoop` extraction, #605.)
- `CompletionLoop` accepts its dependencies (engine accessor, active media id, disposed flag, `RepeatMode` resolver, echo snapshot) instead of creating them, so it is unit-testable with a fake engine and stub closures — no container, database, or real-time waits (#605).
- **Duplicate** `completed` events are a no-op: each iteration subscribes fresh via `.listen`, and the subscription is cancelled before the seek/play — a second event that lands while no subscription is active is lost (broadcast stream, no replay).
- **Late** events (a `completed` arriving after `_playbackGen` bumped) are caught by the post-await gen re-check.

### 3. RepeatMode wiring

| Mode | Behavior on completion |
|------|------------------------|
| `none` | Loop returns — media is at the end; user can press play to restart. |
| `single` | Seek to zero, play, re-await (loops the whole file). |
| `segment` | If echo is active: seek to echo window start, play, re-await. Falls back to `none` when echo is inactive. |

For the YouTube engine, `YoutubePlayerEngine.resetCompletionFlag()` is called before seek+play so `play()` drives the `<video>` directly instead of reloading the watch page (which would discard the seek position).

The `RepeatMode → next-action` mapping itself is owned by the pure-function reducer [`decideOnMediaEnd`](../../lib/features/player/domain/transport_decisions.dart) (D7 in [features/player.md § Decision reducers](../features/player.md#decision-reducers-d1d7)). Keeping the decision out of the loop body means every branch is unit-tested without a running engine, and a future repeat mode (or "advance" action once queue semantics land) is a one-line extension to the sealed `MediaEndDecision` rather than a controller edit.

`CompletionLoop` is the **single consumer** of that policy and of `engine.completed` (#605). Engine-internal watchers only *surface* the end-of-media transition: the YouTube poll loop's `MediaJustEnded` branch marks the session completed, stops polling, and emits the transport state — it never applies a repeat action itself. (Before #605 the poll loop also applied `decideOnMediaEnd` and reloaded the watch page, racing the controller loop on the same `completed` event whenever the warmed YouTube engine had a `repeatMode` resolver; engines created through the engine binding got none at all.)

## Consequences

- **Supersedes** the "Future: wire RepeatMode" note in `docs/features/player.md`.
- **YouTube repeat replays via seek+play, not watch-page reload** (#605): the loop clears the completion latch, seeks to the replay target, and plays — `play()` drives the `<video>` directly, and the explicit-play path re-arms the poll loop. Cheaper than a page reload and free of the two-mechanism race; the D8 immediate-pause retry covers page-player "corrections" of the fresh play.
- **Echo boundary** (segment-end pause-and-rewind) still runs reactively on position ticks via `EchoEnforcer`. The deterministic loop fires only on real media completion. Folding echo boundary into the same loop (so segment-end uses `await until segment end` instead of tick heuristics) is a separable follow-up — the 40 ms end-guard tick dependency (G4) for the tail-of-file case is resolved by the completion event, but mid-file segment boundaries still depend on position ticks.
- **YouTube ~250 ms poll latency** for EOM detection is documented as an accepted MVP limitation (ADR-0015).
- **Queue advance** ("next item" on `RepeatMode.none`) is explicitly out of scope — defining what "advance" means for the library queue is separate queue work.
- **Trial-listen isolation** (`_playbackSessionId`) described in the issue is deferred: the recording preview uses a separate `media_kit` `Player` instance per ADR-0003, so the shared engine is never reused for trial plays today. The API surface (`_playbackGen` is bumpable from any transport action) supports adding session isolation without restructuring if a trial-listen feature reuses the shared engine in the future.

## References

- Issue #307 — original proposal and gap analysis.
- [ADR-0003](0003-player-core-media-kit.md) — single media_kit player.
- [ADR-0015](0015-youtube-playback.md) — dual-engine stream surface, YouTube poll cadence.
- `EchoEnforcer` (`echo_enforcer.dart`) — the generation-counter + single-flight pattern this loop mirrors.
