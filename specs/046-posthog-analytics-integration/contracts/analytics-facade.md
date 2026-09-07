# Contract: Analytics Facade

**Feature**: `046-posthog-analytics-integration` | **Date**: 2026-09-03
This is the only surface through which app code may use product analytics. Feature code MUST NOT import `package:posthog_flutter` directly.

## Interface (lib/core/analytics/analytics.dart)

```dart
/// Product analytics facade. All implementations are non-blocking: no method
/// may throw, await on network I/O from the caller's perspective, or affect
/// app behavior. Implementations: PosthogAnalytics (Android/iOS/macOS with a
/// configured token) and NoopAnalytics (everything else — see research D3).
abstract interface class Analytics {
  /// Captures a catalog event. [properties] must come from
  /// `AnalyticsEvents` helpers; free-form properties are rejected in review
  /// and dropped by the beforeSend guard.
  void capture(String name, {Map<String, Object?> properties});

  /// Attributes subsequent events to the signed-in account. No-op when the
  /// same [userId] is already current (prevents re-identify churn).
  void identify(String userId, {Map<String, Object>? userProperties});

  /// Clears identity + super properties; subsequent events are anonymous.
  void reset();

  /// Vendor-level opt-out (persists in SDK storage) + stops Dart-side capture.
  void setEnabled(bool enabled);

  /// Evaluates a feature flag. [fallback] is REQUIRED and is returned when
  /// analytics is unavailable, opted out, or the flag is not loaded. The
  /// type of [fallback] selects the vendor call (bool → boolean flag,
  /// anything else → multivariate String value).
  Future<T> flag<T extends Object>({required String key, required T fallback});

  /// Best-effort delivery of queued events (teardown/testing only).
  Future<void> flush();
}

/// Null-object used for: Windows/Linux (no vendor support), missing token,
/// debug/test builds without defines. Opt-out and not-yet-initialized are
/// handled INSIDE PosthogAnalytics (a `_ready && _enabled` gate) so the same
/// long-lived instance can be revived in-session when the user opts back in —
/// including screen autocapture, which holds the instance from router build.
final class NoopAnalytics implements Analytics { /* all no-ops; flag → fallback */ }
```

## Provider wiring (lib/core/analytics/analytics_provider.dart)

```dart
@Riverpod(keepAlive: true)
Analytics analytics(Ref ref) {
  // Gate order matters and is contract, not detail:
  // 1. platform gate  (Android | iOS | macOS)          → else Noop
  // 2. token gate     (POSTHOG_API_KEY via dart-define) → else Noop
  // 3. kDebugMode without explicit token                → Noop (D2/D10)
  // 4. user opted out (analytics.capture_enabled pref)  → Noop
  // 5. otherwise PosthogAnalytics (wraps Posthog(), all calls guarded +
  //    logged via logNamed('analytics'); construction never awaits vendor I/O)
}
```

## Lifecycle contract

| Moment | Actor | Required behavior |
|---|---|---|
| App bootstrap | `main.dart` fires `analyticsInitProvider` fire-and-forget | `Posthog().setup(config)` with `AUTO_INIT=false` platform files; registers super properties (E5); applies stored opt-out; attaches auth listener. First frame never waits on this (D8). |
| `authCtrlProvider` → `AuthSignedIn` | auth-sync listener | `identify(UserProfile.id)`; skip when id unchanged. |
| `authCtrlProvider` → `AuthSignedOut` | auth-sync listener | `reset()` before any further capture. |
| Settings toggle off | `AnalyticsCapturePref` notifier | Persist `'false'` to Drift; the analytics provider listener applies `Posthog().disable()`; captures additionally gated inside the instance (D4). |
| Settings toggle on | same | `Posthog().enable()`; capture resumes in-session. |
| Windows/Linux/tokenless/any failure | — | `NoopAnalytics` or guarded no-op; zero errors surfaced, zero log noise beyond a single init-time info line. |

## Invariants (each maps to a spec requirement and a required unit test)

1. **Inert by construction** — no call path reaches the vendor SDK on unsupported platforms or without a token (FR-008, FR-010).
2. **Never throws, never blocks** — every `Analytics` method returns synchronously (except `flush`) and swallows vendor errors into `logNamed('analytics')` (FR-009, constitution IV).
3. **No UGC** — property keys come from catalog constants only; failure reasons from the closed enum; the vendor `beforeSend` list gets our guard appended, which drops any event outside the catalog or carrying un-allowlisted properties (FR-004). The vendor's IO layer additionally converts its own channel errors to no-ops/`false`; our wrapper logs whatever else escapes.
4. **Stable, non-email identity** — `identify` receives `UserProfile.id`; email rides in person properties (FR-005).
5. **Flag reads always answer** — `flag()` returns `fallback` whenever real evaluation is impossible (FR-011).
6. **Mockability** — tests inject `Analytics` via provider override; the vendor method channel is mockable with `TestDefaultBinaryMessengerBinding.setMockMethodCallHandler` for `PosthogAnalytics`-level tests.
