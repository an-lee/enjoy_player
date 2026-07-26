import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFailure', () {
    test('toString returns the message verbatim', () {
      const failure = FileFailure('something went wrong');
      expect(failure.toString(), 'something went wrong');
    });

    test('sealed failure subclasses are recognized as AppFailure', () {
      final f = const FileFailure('x');
      final d = const DatabaseFailure('y');
      final p = const PlaybackFailure('z');
      final n = const NetworkFailure('q', statusCode: 503);
      final c = const CreditsFailure('r');
      final s = const SubscriptionConflictFailure('s');
      final a = const AuthFailure('t', code: AuthFailureCode.rateLimited);

      expect(f, isA<AppFailure>());
      expect(d, isA<AppFailure>());
      expect(p, isA<AppFailure>());
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

  group('DatabaseFailure', () {
    test('carries message verbatim', () {
      const d = DatabaseFailure('db down');
      expect(d.message, 'db down');
    });
  });

  group('PlaybackFailure', () {
    test('carries message verbatim', () {
      const p = PlaybackFailure('codec error');
      expect(p.message, 'codec error');
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
          AuthFailureCode.networkUnreachable,
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
