// Failure vocabulary mapping (spec 046 T029): every AppFailure variant maps
// into the closed AnalyticsFailureReason enum — coarse tags only, never
// payloads.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/analytics/analytics_events.dart';
import 'package:enjoy_player/core/analytics/analytics_failure_reason.dart';
import 'package:enjoy_player/core/errors/app_failure.dart';

void main() {
  group('analyticsFailureReasonFromAppFailure', () {
    test('socket-level NetworkFailure maps to network', () {
      expect(
        analyticsFailureReasonFromAppFailure(const NetworkFailure('down')),
        AnalyticsFailureReason.network,
      );
    });

    test('5xx NetworkFailure maps to server', () {
      expect(
        analyticsFailureReasonFromAppFailure(
          const NetworkFailure('boom', statusCode: 503),
        ),
        AnalyticsFailureReason.server,
      );
    });

    test('credits and BYOK billing both map to credits', () {
      expect(
        analyticsFailureReasonFromAppFailure(const CreditsFailure('402')),
        AnalyticsFailureReason.credits,
      );
      expect(
        analyticsFailureReasonFromAppFailure(
          const ProviderBillingFailure('provider 402'),
        ),
        AnalyticsFailureReason.credits,
      );
    });

    test('auth failures map to auth', () {
      expect(
        analyticsFailureReasonFromAppFailure(
          const AuthFailure('revoked', code: AuthFailureCode.sessionRevoked),
        ),
        AnalyticsFailureReason.auth,
      );
    });

    test('server-side rejections map to server', () {
      expect(
        analyticsFailureReasonFromAppFailure(
          const SubscriptionConflictFailure('409'),
        ),
        AnalyticsFailureReason.server,
      );
    });

    test('local failures map to local', () {
      const local = <AppFailure>[
        FileFailure('io'),
        UnsupportedImportFileFailure(),
        DatabaseFailure('db'),
        PlaybackFailure('playback'),
      ];
      for (final failure in local) {
        expect(
          analyticsFailureReasonFromAppFailure(failure),
          AnalyticsFailureReason.local,
          reason: failure.runtimeType.toString(),
        );
      }
    });
  });

  group('analyticsFailureReasonFromObject', () {
    test('delegates AppFailures to the typed mapping', () {
      expect(
        analyticsFailureReasonFromObject(const NetworkFailure('down')),
        AnalyticsFailureReason.network,
      );
    });

    test('timeouts are network-shaped', () {
      expect(
        analyticsFailureReasonFromObject(TimeoutException('timed out')),
        AnalyticsFailureReason.network,
      );
    });

    test('unknown exceptions stay unknown — never a fabricated payload', () {
      expect(
        analyticsFailureReasonFromObject(StateError('weird')),
        AnalyticsFailureReason.unknown,
      );
    });
  });
}
