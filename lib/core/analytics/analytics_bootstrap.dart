/// One-shot product analytics initialization (specs/046, research D8).
///
/// Fire-and-forget from `EnjoyApp`'s first init: vendor setup, super
/// properties, and the auth-sync listener. Nothing here is ever awaited on
/// the startup path — `runApp` and the first frame never wait for it. The
/// keepAlive provider builds exactly once, so re-reads are idempotent.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:logging/logging.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/analytics/analytics.dart';
import 'package:enjoy_player/core/analytics/analytics_config.dart';
import 'package:enjoy_player/core/analytics/analytics_events.dart';
import 'package:enjoy_player/core/analytics/analytics_provider.dart';
import 'package:enjoy_player/core/analytics/posthog_analytics.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/release/distribution_channel.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';

part 'analytics_bootstrap.g.dart';

final Logger _log = logNamed('analytics');

@Riverpod(keepAlive: true)
Future<void> analyticsInit(Ref ref) async {
  final analytics = ref.read(analyticsProvider);
  if (analytics is! PosthogAnalytics) {
    _log.info('analytics: inert (unsupported platform or no token configured)');
    // Auth sync is still attached (it all no-ops) so the wiring is identical
    // in every build and testable without a token.
    ref.read(analyticsAuthSyncProvider);
    return;
  }

  final config = PostHogConfig(kPostHogApiKey)
    ..host = kPostHogHost
    ..debug = kDebugMode
    ..onFeatureFlags = () {
      if (kDebugMode) _log.info('analytics: feature flags loaded');
    };
  await analytics.setup(config);

  await _registerSuperProperties(ref, analytics);

  ref.read(analyticsAuthSyncProvider);
}

/// Auth sync (data-model E2): events attribute to the signed-in account and
/// reset on sign-out. Attached here — outside the auth feature — so
/// `auth_controller.dart` carries no analytics code.
@Riverpod(keepAlive: true)
void analyticsAuthSync(Ref ref) {
  final analytics = ref.read(analyticsProvider);
  ref.listen<AsyncValue<AuthState>>(authCtrlProvider, (
    _,
    AsyncValue<AuthState> next,
  ) {
    _applyAuthState(analytics, next);
  });
  _applyAuthState(analytics, ref.read(authCtrlProvider));
}

Future<void> _registerSuperProperties(
  Ref ref,
  PosthogAnalytics analytics,
) async {
  try {
    final prefs = await ref.read(appPreferencesCtrlProvider.future);
    await analytics.registerSuperProperties({
      AnalyticsEvents.propDisplayLocale: prefs.effectiveDisplayLocale
          .toLanguageTag(),
      AnalyticsEvents.propLearningLanguage: prefs.effectiveLearningLanguage,
      AnalyticsEvents.propDistributionChannel:
          resolveDistributionChannel().name,
    });
  } on Object catch (error, stack) {
    _log.warning('analytics: super properties not registered', error, stack);
  }
}

/// Attribute events to the signed-in account (`UserProfile.id` — never the
/// email, spec FR-005) and reset attribution on sign-out (FR-006). In-flight
/// sign-in flows keep the current identity.
void _applyAuthState(Analytics analytics, AsyncValue<AuthState> state) {
  final auth = state.valueOrNull;
  if (auth is AuthSignedIn) {
    final profile = auth.profile;
    analytics.identify(
      profile.id,
      userProperties: {
        'email': profile.email,
        'name': profile.name,
        if (profile.learningLanguage != null)
          'learning_language': profile.learningLanguage!,
        if (profile.subscriptionTier != null)
          'subscription_tier': profile.subscriptionTier!.name,
      },
    );
  } else if (auth is AuthSignedOut) {
    analytics.reset();
  }
}
