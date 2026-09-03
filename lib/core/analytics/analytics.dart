/// Product analytics facade (specs/046-posthog-analytics-integration).
///
/// This is the only surface through which app code may use product
/// analytics; feature code MUST NOT import `package:posthog_flutter`.
/// Contract: specs/046-posthog-analytics-integration/contracts/analytics-facade.md.
library;

import 'package:flutter/widgets.dart' show NavigatorObserver, Route;

/// Non-blocking product analytics.
///
/// Every implementation MUST honor the facade invariants: calls never throw,
/// never block the caller, and degrade to no-ops whenever analytics is
/// unavailable (unsupported platform, missing token, opted out, or not yet
/// initialized).
abstract interface class Analytics {
  /// Captures a catalog event. [name] and [properties] must come from
  /// [AnalyticsEvents] helpers — free-form names or properties are contract
  /// violations and are additionally dropped by the vendor-side guard.
  void capture(String name, {Map<String, Object>? properties});

  /// Records a named route navigation (`$screen`). Route names are stable
  /// identifiers (see the event catalog), never content titles.
  void screen(String name);

  /// Attributes subsequent events to the signed-in account. No-op when the
  /// same [userId] is already current (prevents re-identify churn).
  /// [userProperties] is metadata only — the email must never be the ID.
  void identify(String userId, {Map<String, Object>? userProperties});

  /// Clears identity and stored context; subsequent events are anonymous.
  void reset();

  /// Applies the user's capture preference. Disabling stops all capture
  /// immediately; enabling resumes in-session.
  void setEnabled(bool enabled);

  /// Evaluates a feature flag. [fallback] is REQUIRED and is returned when
  /// analytics is unavailable, opted out, errored, or the flag is not
  /// loaded — no call site may omit a safe default (spec FR-011). The type
  /// of [fallback] selects the vendor call (bool → boolean flag, anything
  /// else → multivariate String value).
  Future<T> flag<T extends Object>({required String key, required T fallback});

  /// Best-effort delivery of queued events (teardown/testing only).
  Future<void> flush();
}

/// Null-object used wherever analytics must be inert: Windows/Linux (no
/// vendor support), missing compile-time token, opt-out, and before the
/// vendor setup completes.
final class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  void capture(String name, {Map<String, Object>? properties}) {}

  @override
  void screen(String name) {}

  @override
  void identify(String userId, {Map<String, Object>? userProperties}) {}

  @override
  void reset() {}

  @override
  void setEnabled(bool enabled) {}

  @override
  Future<T> flag<T extends Object>({
    required String key,
    required T fallback,
  }) async => fallback;

  @override
  Future<void> flush() async {}
}

/// Records named route navigations as `$screen` events. Attach to the
/// GoRouter root and ShellRoute observers lists (research D6) — root-level
/// and shell-level navigators each report their own pushes, so the observer
/// never double-fires for one navigation.
///
/// Inert wherever routes are unnamed or analytics resolves to the no-op
/// implementation.
final class AnalyticsScreenObserver extends NavigatorObserver {
  AnalyticsScreenObserver(this._analytics);

  final Analytics _analytics;

  void _record(Route? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty) return;
    _analytics.screen(name);
  }

  @override
  void didPush(Route route, Route? previousRoute) => _record(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _record(newRoute);
}
