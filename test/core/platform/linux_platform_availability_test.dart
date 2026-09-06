import 'package:enjoy_player/core/platform/linux_platform_availability.dart'
    as linux_avail;
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('linux_platform_availability predicates', () {
    group('youTubeEngineOptedOutHere', () {
      tearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });

      test('is true on the Linux target while the v1 opt-out stands', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        expect(linux_avail.youTubeEngineOptedOutHere, isTrue);
      });

      test('is false on other targets', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        expect(linux_avail.youTubeEngineOptedOutHere, isFalse);
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        expect(linux_avail.youTubeEngineOptedOutHere, isFalse);
      });
    });

    test(
      'youtubeEngineAvailableOnLinux is false (v1 opt-out per ADR-0048)',
      () {
        expect(
          linux_avail.youtubeEngineAvailableOnLinux,
          false,
          reason:
              'YouTube is not yet available on Linux for v1 (webview2gtk-4.0 '
              'dependency). A follow-up ADR may flip this to true.',
        );
      },
    );

    test('googleSignInAvailableOnLinux is false (disabled per ADR-0084)', () {
      expect(
        linux_avail.googleSignInAvailableOnLinux,
        false,
        reason:
            'google_sign_in browser-based OAuth fails on real Linux installs. '
            'Linux uses email OTP + web PKCE fallback (ADR-0084).',
      );
    });
  });
}
