# Contract: Pronounce Playback Controller

**Owner**: application-layer Riverpod notifier (keepAlive)  
**Consumers**: shared pronounce button; surfaces call `stop()` on dismiss/flip/selection change

## API (conceptual)

```text
play(PronounceTarget target) → Future<void>
stop() → Future<void>
state → PronouncePlaybackState  // idle | loading | playing | error
activeTarget → PronounceTarget?
```

## Rules

1. `play` when `target.resolvedLocale == null` or text empty → no-op / assert UI disabled.
2. `play` while same target already `playing` → `stop`.
3. `play` while `loading` for same target → cancel in-flight and return to idle (or ignore); never stack players.
4. `play` for a different target → stop current, then load new.
5. Stale completions (generation mismatch) MUST NOT transition state or start audio.
6. Dispose / sign-out → `stop` and clear session URL cache.
7. Must not construct `package:media_kit` `Player`.

## Errors

Failures surface as `state == error` briefly and/or thrown `AppFailure` for the button to `AppNotice`; then return to `idle` with control enabled when target still valid.
