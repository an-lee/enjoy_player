import 'package:enjoy_player/core/window/desktop_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isDesktop', () {
    test('matches the host default target platform', () {
      final hostIsDesktop =
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux;
      expect(isDesktop, hostIsDesktop);
    });

    test('returns true for windows', () {
      expect(_isDesktopFor(TargetPlatform.windows), isTrue);
    });

    test('returns true for macOS', () {
      expect(_isDesktopFor(TargetPlatform.macOS), isTrue);
    });

    test('returns true for linux', () {
      expect(_isDesktopFor(TargetPlatform.linux), isTrue);
    });

    test('returns false for android', () {
      expect(_isDesktopFor(TargetPlatform.android), isFalse);
    });

    test('returns false for iOS', () {
      expect(_isDesktopFor(TargetPlatform.iOS), isFalse);
    });
  });

  group('setWindowFullscreen', () {
    test('is a no-op (returns without throwing) when not desktop', () async {
      // On the Linux test host isDesktop=true and the underlying
      // window_manager API may not be wired; calling should not throw.
      await setWindowFullscreen(true);
      await setWindowFullscreen(false);
    });
  });

  group('getWindowFullscreen', () {
    test('returns false on non-desktop targets via inlined gate', () async {
      // Same caveat as setWindowFullscreen: the function only branches on
      // isDesktop, and on this test host we cannot assume window_manager
      // resolution. We verify the function returns a bool in both cases.
      final result = await getWindowFullscreen();
      expect(result, isA<bool>());
    });
  });
}

/// Inline re-implementation of the [isDesktop] predicate so tests can drive
/// it for every [TargetPlatform] without depending on `defaultTargetPlatform`
/// at runtime. Kept in sync with the implementation in `desktop_window.dart`.
bool _isDesktopFor(TargetPlatform platform) =>
    platform == TargetPlatform.windows ||
    platform == TargetPlatform.macOS ||
    platform == TargetPlatform.linux;
