import 'dart:io' show Platform;

import 'package:enjoy_player/core/platform/linux_platform_availability.dart'
    as linux_avail;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('linux_platform_availability predicates', () {
    test('isLinux matches Platform.isLinux', () {
      expect(linux_avail.isLinux, Platform.isLinux);
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

    test('autoUpdaterAvailableOnLinux is false (auto_updater is Windows/macOS '
        'only per ADR-0048)', () {
      expect(
        linux_avail.autoUpdaterAvailableOnLinux,
        false,
        reason:
            'auto_updater: 0.2.1 is Windows/macOS-only. Linux uses '
            'direct-download updates from the landing page.',
      );
    });

    test('echoRecordingAvailableOnLinux is true (v1 default per ADR-0048)', () {
      expect(
        linux_avail.echoRecordingAvailableOnLinux,
        true,
        reason:
            'record package supports Linux. Flip to false if first smoke '
            'shows a PulseAudio/PipeWire crash.',
      );
    });

    test('nativeLinuxAsrAvailable is true (v1 default per ADR-0048)', () {
      expect(
        linux_avail.nativeLinuxAsrAvailable,
        true,
        reason:
            'ASR audio extraction falls through to system ffmpeg on '
            'non-Windows platforms.',
      );
    });
  });
}
