import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFailure', () {
    test('toString returns the message verbatim', () {
      const failure = FileFailure('something went wrong');
      expect(failure.toString(), 'something went wrong');
    });

    test('sealed failure subclasses are recognized as AppFailure', () {
      final f = const FileFailure('x');
      final n = const NetworkFailure('q', statusCode: 503);
      final c = const CreditsFailure('r');
      final s = const SubscriptionConflictFailure('s');
      final a = const AuthFailure('t', code: AuthFailureCode.rateLimited);

      expect(f, isA<AppFailure>());
      expect(n, isA<AppFailure>());
      expect(c, isA<AppFailure>());
      expect(s, isA<AppFailure>());
      expect(a, isA<AppFailure>());
    });
  });

  group('FileFailure', () {
    test('carries message verbatim', () {
      const f = FileFailure('cannot open');
      expect(f.message, 'cannot open');
      expect(f.toString(), 'cannot open');
    });

    test('UnsupportedImportFileFailure has empty message', () {
      const u = UnsupportedImportFileFailure();
      expect(u.message, '');
      expect(u.toString(), '');
      expect(u, isA<AppFailure>());
    });
  });

  group('NetworkFailure', () {
    test('statusCode defaults to null when omitted', () {
      const n = NetworkFailure('boom');
      expect(n.statusCode, isNull);
    });

    test('statusCode is preserved when provided', () {
      const n = NetworkFailure('boom', statusCode: 503);
      expect(n.statusCode, 503);
    });
  });

  group('AuthFailure', () {
    test('defaults to AuthFailureCode.unknown', () {
      const a = AuthFailure('boom');
      expect(a.code, AuthFailureCode.unknown);
      expect(a.isSessionRevoked, isFalse);
    });

    test('isSessionRevoked true only for sessionRevoked code', () {
      const a1 = AuthFailure('boom', code: AuthFailureCode.sessionRevoked);
      const a2 = AuthFailure('boom', code: AuthFailureCode.rateLimited);
      const a3 = AuthFailure('boom', code: AuthFailureCode.unknown);
      expect(a1.isSessionRevoked, isTrue);
      expect(a2.isSessionRevoked, isFalse);
      expect(a3.isSessionRevoked, isFalse);
    });

    test('every AuthFailureCode enum value is exposed', () {
      expect(
        AuthFailureCode.values,
        containsAll(<AuthFailureCode>[
          AuthFailureCode.invalidCredentials,
          AuthFailureCode.sessionRevoked,
          AuthFailureCode.rateLimited,
          AuthFailureCode.serverError,
          AuthFailureCode.unknown,
        ]),
      );
    });
  });

  group('CreditsFailure', () {
    test('carries message verbatim', () {
      const c = CreditsFailure('out of credits');
      expect(c.message, 'out of credits');
    });

    test('const constructor leaves envelope fields null', () {
      const c = CreditsFailure('HTTP 402');
      expect(c.requiredCredits, isNull);
      expect(c.usedCredits, isNull);
      expect(c.limitCredits, isNull);
      expect(c.resetAt, isNull);
      expect(c.remainingCredits, isNull);
    });

    group('fromApiException envelope parsing', () {
      ApiException withBody(Object? body) =>
          ApiException(message: 'HTTP 402', statusCode: 402, body: body);

      test('full worker envelope populates all fields', () {
        final failure = CreditsFailure.fromApiException(
          withBody(<String, dynamic>{
            'error': 'credits_exhausted',
            'message': 'Daily credits exhausted',
            'code': 'CREDITS_EXHAUSTED',
            'required': 750,
            'limit': <String, dynamic>{
              'label': 'daily_credits',
              'used': 800,
              'limit': 1000,
              'resetAt': '2026-08-31T00:00:00.000Z',
              'window': 'daily',
            },
          }),
        );

        expect(failure.requiredCredits, 750);
        expect(failure.usedCredits, 800);
        expect(failure.limitCredits, 1000);
        expect(failure.resetAt, DateTime.utc(2026, 8, 31));
        expect(failure.remainingCredits, 200);
      });

      test('resetAt parses as UTC from an offset-bearing ISO string', () {
        final failure = CreditsFailure.fromApiException(
          withBody(<String, dynamic>{
            'required': 10,
            'limit': <String, dynamic>{'resetAt': '2026-08-31T08:00:00+08:00'},
          }),
        );
        expect(failure.resetAt, DateTime.utc(2026, 8, 31, 0, 0));
      });

      test('each envelope field may be independently absent', () {
        final failure = CreditsFailure.fromApiException(
          withBody(<String, dynamic>{'required': 50}),
        );
        expect(failure.requiredCredits, 50);
        expect(failure.usedCredits, isNull);
        expect(failure.limitCredits, isNull);
        expect(failure.resetAt, isNull);
        expect(failure.remainingCredits, isNull);
      });

      test('null body yields all-null envelope (generic fallback)', () {
        final failure = CreditsFailure.fromApiException(withBody(null));
        expect(failure.requiredCredits, isNull);
        expect(failure.limitCredits, isNull);
        expect(failure.remainingCredits, isNull);
      });

      test('raw-string body (JSON decode fallback) yields nulls', () {
        final failure = CreditsFailure.fromApiException(
          withBody('credits exhausted'),
        );
        expect(failure.requiredCredits, isNull);
        expect(failure.resetAt, isNull);
      });

      test('negative and non-numeric values are treated as absent', () {
        final failure = CreditsFailure.fromApiException(
          withBody(<String, dynamic>{
            'required': -5,
            'limit': <String, dynamic>{'used': 'many', 'limit': 12.5},
          }),
        );
        expect(failure.requiredCredits, isNull);
        expect(failure.usedCredits, isNull);
        expect(failure.limitCredits, isNull);
      });

      test('garbage resetAt string is ignored without throwing', () {
        final failure = CreditsFailure.fromApiException(
          withBody(<String, dynamic>{
            'limit': <String, dynamic>{'resetAt': 'not-a-date'},
          }),
        );
        expect(failure.resetAt, isNull);
      });

      test('non-map body typed as Map<dynamic, dynamic> yields nulls', () {
        // decodeJsonToCamel always yields Map<String, dynamic> for JSON
        // objects, but guard against other Map types reaching the parser.
        final failure = CreditsFailure.fromApiException(
          const ApiException(
            message: 'HTTP 402',
            statusCode: 402,
            body: <int, String>{1: 'x'},
          ),
        );
        expect(failure.requiredCredits, isNull);
      });
    });
  });

  group('ProviderBillingFailure', () {
    test('carries message verbatim and is an AppFailure', () {
      const p = ProviderBillingFailure('provider declined');
      expect(p.message, 'provider declined');
      expect(p, isA<AppFailure>());
    });
  });

  group('SubscriptionConflictFailure', () {
    test('carries message verbatim', () {
      const s = SubscriptionConflictFailure('already renewing');
      expect(s.message, 'already renewing');
    });
  });

  group('AuthFailureCode semantic checks', () {
    test('all distinct', () {
      final codes = AuthFailureCode.values.toSet();
      expect(codes.length, AuthFailureCode.values.length);
    });
  });
}
