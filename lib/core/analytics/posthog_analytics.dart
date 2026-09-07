/// PostHog-backed implementation of the [Analytics] facade (specs/046).
///
/// Every vendor call is fire-and-forget and guarded: analytics must never
/// throw into app code, block a user-facing path, or outlive an opt-out
/// (spec FR-009, constitution IV). Captures stay inert until [setup]
/// completes AND the stored opt-out preference has been applied — startup
/// races must never leak an opted-out user's first events.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logging/logging.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'package:enjoy_player/core/analytics/analytics.dart';
import 'package:enjoy_player/core/analytics/analytics_events.dart';
import 'package:enjoy_player/core/logging/log.dart';

/// Vendor-generated event names allowed through the beforeSend guard.
/// Native-initiated lifecycle events never reach beforeSend (vendor docs),
/// but the Dart-side `$screen`/`$exception` paths do.
const Set<String> _vendorEventNames = {
  r'$screen',
  r'$exception',
  'Application Opened',
  'Application Backgrounded',
  'Application Installed',
  'Application Updated',
};

/// Catalog property keys + the one vendor-added key on Dart-side captures.
final Set<String> _allowedPropertyKeys = {
  ...AnalyticsEvents.propertyKeys,
  r'$screen_name',
};

final class PosthogAnalytics implements Analytics {
  /// [flagTimeout] bounds every flag read — a slow/hung vendor must never
  /// hold up a flag-gated decision (spec FR-011).
  PosthogAnalytics({
    this.flagTimeout = const Duration(seconds: 3),
    @visibleForTesting this.shortCircuitOnError = false,
  });

  /// When true (tests only), vendor flag reads throw instead of returning
  /// null/false — the only way to reach the fallback guard, since the
  /// vendor's IO layer converts channel errors into `false`.
  final bool shortCircuitOnError;

  @visibleForTesting
  final Duration flagTimeout;

  static final Logger _log = logNamed('analytics');

  /// Set once [setup] completes; until then every capture is dropped so a
  /// not-yet-configured native side can never surface an error.
  bool _ready = false;

  /// Starts `false` — the bootstrap/provider wiring flips it after the
  /// stored opt-out preference resolves. An opted-out user therefore never
  /// emits events, even before their preference is read from the DB.
  bool _enabled = false;

  String? _currentUserId;
  Map<String, Object> _lastUserProperties = const {};

  bool get _gated => _ready && _enabled;

  /// Configures the vendor SDK. Call once during bootstrap; captures before
  /// this are dropped silently.
  Future<void> setup(PostHogConfig config) async {
    try {
      // beforeSend is a list — append, never replace.
      config.beforeSend = [...config.beforeSend, _beforeSendGuard];
      await Posthog().setup(config);
      _ready = true;
    } on Object catch (error, stack) {
      _log.warning('analytics: setup failed — staying inert', error, stack);
    }
  }

  /// Structural enforcement of spec FR-004: drop anything outside the
  /// catalog or carrying a non-allowlisted property, so a UGC-shaped value
  /// can never reach the vendor even from a contract-violating call site.
  PostHogEvent? _beforeSendGuard(PostHogEvent event) {
    if (!AnalyticsEvents.all.contains(event.event) &&
        !_vendorEventNames.contains(event.event)) {
      return _drop(event, 'unknown event "${event.event}"');
    }
    final properties = event.properties;
    if (properties != null) {
      for (final key in properties.keys) {
        if (!_allowedPropertyKeys.contains(key)) {
          return _drop(event, 'non-catalog property "$key"');
        }
      }
    }
    return event;
  }

  PostHogEvent? _drop(PostHogEvent event, String why) {
    _log.warning('analytics: dropped event ($why)');
    return null;
  }

  @override
  void capture(String name, {Map<String, Object>? properties}) {
    if (!_gated) return;
    _run(
      Posthog().capture(eventName: name, properties: properties),
      'capture($name)',
    );
  }

  @override
  void screen(String name) {
    if (!_gated) return;
    _run(Posthog().screen(screenName: name), 'screen($name)');
  }

  @override
  void identify(String userId, {Map<String, Object>? userProperties}) {
    if (!_ready) return;
    // Re-identifying with the same id churns vendor person merges — skip
    // (data-model E2).
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    _lastUserProperties = userProperties ?? const {};
    if (!_gated) return; // identity remembered; replayed on re-enable
    _run(
      Posthog().identify(userId: userId, userProperties: userProperties),
      'identify',
    );
  }

  @override
  void reset() {
    _currentUserId = null;
    _lastUserProperties = const {};
    if (!_gated) return;
    _run(Posthog().reset(), 'reset');
  }

  @override
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!_ready) return;
    // The vendor call persists the opt-out in native storage.
    _run(
      enabled ? Posthog().enable() : Posthog().disable(),
      'setEnabled($enabled)',
    );
    if (enabled && _currentUserId != null) {
      // An identify that arrived while disabled was remembered, not sent —
      // replay it so this session's events attribute to the account (E2).
      final userId = _currentUserId!;
      final userProperties = _lastUserProperties;
      _run(
        Posthog().identify(userId: userId, userProperties: userProperties),
        'identify(replayed after enable)',
      );
    }
  }

  @override
  Future<T> flag<T extends Object>({
    required String key,
    required T fallback,
  }) async {
    if (!_gated) return fallback;
    try {
      if (shortCircuitOnError) {
        throw StateError('simulated vendor failure');
      }
      final Object? value =
          await (fallback is bool
                  ? Posthog().isFeatureEnabled(key)
                  : Posthog().getFeatureFlag(key))
              .timeout(flagTimeout);
      return value is T ? value : fallback;
    } on Object catch (error, stack) {
      _log.warning(
        'analytics: flag($key) failed — using fallback',
        error,
        stack,
      );
      return fallback;
    }
  }

  @override
  Future<void> flush() async {
    if (!_ready) return;
    try {
      await Posthog().flush();
    } on Object catch (error, stack) {
      _log.warning('analytics: flush failed', error, stack);
    }
  }

  /// Registers super properties sent with every event (data-model E5).
  Future<void> registerSuperProperties(Map<String, Object> properties) async {
    if (!_ready) return;
    for (final entry in properties.entries) {
      try {
        await Posthog().register(entry.key, entry.value);
      } on Object catch (error, stack) {
        _log.warning('analytics: register(${entry.key}) failed', error, stack);
      }
    }
  }

  /// Awaits [future], logging (never rethrowing) any vendor failure.
  void _run(Future<void> future, String op) {
    unawaited(() async {
      try {
        await future;
      } on Object catch (error, stack) {
        _log.warning('analytics: $op failed', error, stack);
      }
    }());
  }
}
