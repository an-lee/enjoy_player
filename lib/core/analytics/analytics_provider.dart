/// Chooses the [Analytics] implementation for this environment (specs/046).
///
/// Gate order is contract, not detail:
/// 1. unsupported platform (Windows/Linux — no vendor implementation)
/// 2. missing compile-time token (dev/test/CI builds)
/// ⇒ `NoopAnalytics`; otherwise a single long-lived [PosthogAnalytics] whose
/// opt-out state is applied via [PosthogAnalytics.setEnabled] so a re-enable
/// revives the same instance in-session — including screen autocapture
/// (spec FR-007, research D3/D4).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/analytics/analytics.dart';
import 'package:enjoy_player/core/analytics/analytics_capture_pref.dart';
import 'package:enjoy_player/core/analytics/analytics_config.dart';
import 'package:enjoy_player/core/analytics/analytics_platform_gate.dart';
import 'package:enjoy_player/core/analytics/posthog_analytics.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';

part 'analytics_provider.g.dart';

@Riverpod(keepAlive: true)
Analytics analytics(Ref ref) {
  if (!analyticsSupported() || !postHogConfigured) {
    return const NoopAnalytics();
  }

  final impl = PosthogAnalytics();

  void applyPref(AsyncValue<bool> pref) {
    final value = pref.valueOrNull;
    if (value == null) return; // still loading — bootstrap applies on resolve
    impl.setEnabled(value);
  }

  applyPref(ref.read(analyticsCapturePrefProvider));
  ref.listen<AsyncValue<bool>>(analyticsCapturePrefProvider, (
    _,
    AsyncValue<bool> next,
  ) {
    applyPref(next);
  });
  return impl;
}
