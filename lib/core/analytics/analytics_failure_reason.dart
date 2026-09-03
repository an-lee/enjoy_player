/// Maps typed app failures onto the coarse analytics failure vocabulary.
///
/// The mapping is the single sanctioned place where `AppFailure` variants
/// become a `reason` property value — and it can only emit the closed
/// [AnalyticsFailureReason] enum, never a message or payload (spec FR-004).
library;

import 'dart:async' show TimeoutException;

import 'package:enjoy_player/core/analytics/analytics_events.dart';
import 'package:enjoy_player/core/errors/app_failure.dart';

/// Coarse, payload-free failure category for [failure].
AnalyticsFailureReason analyticsFailureReasonFromAppFailure(
  AppFailure failure,
) => switch (failure) {
  // Socket/DNS-level breakage vs an answered-but-failed server.
  NetworkFailure(:final statusCode) =>
    statusCode != null && statusCode >= 500
        ? AnalyticsFailureReason.server
        : AnalyticsFailureReason.network,
  CreditsFailure() => AnalyticsFailureReason.credits,
  // A BYOK provider's billing rejection is still "credits" at this
  // coarseness (the Enjoy-vs-provider distinction is presentation only).
  ProviderBillingFailure() => AnalyticsFailureReason.credits,
  AuthFailure() => AnalyticsFailureReason.auth,
  SubscriptionConflictFailure() => AnalyticsFailureReason.server,
  FileFailure() ||
  UnsupportedImportFileFailure() ||
  DatabaseFailure() ||
  PlaybackFailure() => AnalyticsFailureReason.local,
};

/// Best-effort category for exceptions outside the [AppFailure] hierarchy
/// (e.g. `TimeoutException` at a journey call site).
AnalyticsFailureReason analyticsFailureReasonFromObject(Object error) {
  if (error is AppFailure) return analyticsFailureReasonFromAppFailure(error);
  if (error is TimeoutException) return AnalyticsFailureReason.network;
  return AnalyticsFailureReason.unknown;
}
