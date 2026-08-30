import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/features/ai/application/ai_api_failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ApiException err(int statusCode, {Object? body, bool byokProvider = false}) =>
      ApiException(
        message: 'HTTP $statusCode',
        statusCode: statusCode,
        body: body,
        byokProvider: byokProvider,
      );

  group('mapApiExceptionToAppFailure', () {
    test('Enjoy worker 402 becomes CreditsFailure with envelope fields', () {
      final failure = mapApiExceptionToAppFailure(
        err(
          402,
          body: {
            'error': 'credits_exhausted',
            'required': 750,
            'limit': {
              'used': 800,
              'limit': 1000,
              'resetAt': '2026-08-31T00:00:00.000Z',
            },
          },
        ),
      );

      expect(failure, isA<CreditsFailure>());
      final credits = failure as CreditsFailure;
      expect(credits.requiredCredits, 750);
      expect(credits.remainingCredits, 200);
      expect(credits.resetAt, DateTime.utc(2026, 8, 31));
    });

    test('Enjoy worker 402 with empty body falls back to nulls', () {
      final failure = mapApiExceptionToAppFailure(err(402));
      expect(failure, isA<CreditsFailure>());
      expect((failure as CreditsFailure).requiredCredits, isNull);
    });

    test('BYOK provider 402 becomes ProviderBillingFailure (no envelope)', () {
      final failure = mapApiExceptionToAppFailure(
        err(402, body: {'error': 'insufficient_quota'}, byokProvider: true),
      );

      expect(failure, isA<ProviderBillingFailure>());
      expect(failure, isNot(isA<CreditsFailure>()));
    });

    test('401 becomes session-revoked AuthFailure', () {
      final failure = mapApiExceptionToAppFailure(err(401));
      final auth = failure;
      expect(auth, isA<AuthFailure>());
      expect((auth as AuthFailure).isSessionRevoked, isTrue);
    });

    test('409 stays NetworkFailure at the AI seam (subscription-only)', () {
      // The 409 → SubscriptionConflictFailure mapping lives in the
      // subscription repository mapper, not the AI guard.
      expect(mapApiExceptionToAppFailure(err(409)), isA<NetworkFailure>());
    });

    test('5xx and unclassified statuses stay NetworkFailure', () {
      expect(mapApiExceptionToAppFailure(err(503)), isA<NetworkFailure>());
      final network = mapApiExceptionToAppFailure(err(429)) as NetworkFailure;
      expect(network.statusCode, 429);
    });
  });
}
