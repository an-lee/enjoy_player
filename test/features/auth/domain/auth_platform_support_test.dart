import 'package:enjoy_player/features/auth/domain/auth_platform_support.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('nativeGoogleSignInSupported on Linux', () {
    test('returns false on Linux (disabled per ADR-0084)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(
        nativeGoogleSignInSupported,
        false,
        reason:
            'The Google Sign-In browser-based OAuth flow fails on real '
            'Linux installs; the button is hidden and users sign in with '
            'email OTP or the web PKCE fallback (ADR-0084).',
      );
    });

    test('does not throw on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(() => nativeGoogleSignInSupported, returnsNormally);
    });
  });

  group('nativeAppleSignInSupported on Linux', () {
    test('returns false on Linux (Apple Sign-In is macOS/iOS only)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(
        nativeAppleSignInSupported,
        false,
        reason: 'Apple Sign-In is not available outside iOS/macOS.',
      );
    });

    test('does not throw on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(() => nativeAppleSignInSupported, returnsNormally);
    });
  });

  group('authGooglePlatformParam on Linux', () {
    test('returns null on Linux (no platform string sent for Google auth on '
        'Linux)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(
        authGooglePlatformParam(),
        null,
        reason:
            'The backend does not classify Linux as a distinct Google '
            'auth platform today. The null value signals "desktop, no '
            'platform param."',
      );
    });

    test('does not throw on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(() => authGooglePlatformParam(), returnsNormally);
    });
  });
}
