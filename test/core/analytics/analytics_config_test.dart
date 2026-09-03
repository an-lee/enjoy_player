// Verifies the structural inertness guarantees that hold on any host:
// no token in test/dev builds (config) and unsupported-platform gating.
library;

import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/analytics/analytics.dart';
import 'package:enjoy_player/core/analytics/analytics_config.dart';
import 'package:enjoy_player/core/analytics/analytics_platform_gate.dart';

void main() {
  group('analytics_config', () {
    test('test/dev builds have no compile-time token — fully inert', () {
      expect(kPostHogApiKey, isEmpty);
      expect(kPostHogHost, isEmpty);
      expect(postHogConfigured, isFalse);
    });
  });

  group('analytics_platform_gate', () {
    test('matches the vendor-supported platform list', () {
      final expected = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
      expect(analyticsSupported(), expected);
      // This suite runs on the Linux/CI host, where the vendor has no
      // native implementation — the gate must resolve false.
      if (Platform.isLinux) expect(analyticsSupported(), isFalse);
    });
  });

  group('NoopAnalytics', () {
    test('flag always returns the required fallback', () async {
      const noop = NoopAnalytics();
      expect(await noop.flag(key: 'any', fallback: true), isTrue);
      expect(await noop.flag(key: 'any', fallback: 'control'), 'control');
    });

    test('all other calls are silent no-ops', () {
      const noop = NoopAnalytics();
      expect(
        () => noop
          ..capture('anything', properties: {'x': 1})
          ..screen('anywhere')
          ..identify('u', userProperties: {'e': 'x'})
          ..reset()
          ..setEnabled(false),
        returnsNormally,
      );
      expect(noop.flush(), completes);
    });
  });
}
