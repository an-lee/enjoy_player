import 'package:enjoy_player/features/auth/data/apple_sign_in_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubService extends AppleSignInService {}

void main() {
  group('AppleSignInCredentials', () {
    test('constructor stores all fields', () {
      const creds = AppleSignInCredentials(
        identityToken: 'id-tok',
        authorizationCode: 'auth-code',
        fullName: {'givenName': 'Ada', 'familyName': 'Lovelace'},
      );
      expect(creds.identityToken, 'id-tok');
      expect(creds.authorizationCode, 'auth-code');
      expect(creds.fullName, {'givenName': 'Ada', 'familyName': 'Lovelace'});
    });

    test('fullName defaults to null when not supplied', () {
      const creds = AppleSignInCredentials(
        identityToken: 'id',
        authorizationCode: 'auth',
      );
      expect(creds.fullName, isNull);
    });
  });

  group('appleSignInService provider', () {
    test('provides a default AppleSignInService instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(appleSignInServiceProvider);
      expect(service, isA<AppleSignInService>());
    });

    test('can be overridden with a custom service', () {
      final container = ProviderContainer(
        overrides: [
          appleSignInServiceProvider.overrideWithValue(_StubService()),
        ],
      );
      addTearDown(container.dispose);
      final service = container.read(appleSignInServiceProvider);
      expect(service, isA<_StubService>());
    });
  });
}
