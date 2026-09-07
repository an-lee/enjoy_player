// Invariants for the `launch_pay_url.dart` checkout-launch helper.
//
// The function is consumed by both the credits and subscription purchase
// sheets, which pattern-match on `StateError(:final message)` to surface a
// user-facing reason. These tests pin the three message keys — the public
// contract consumed by the UI — verbatim, so a rename would break this test
// on purpose.
import 'package:enjoy_player/core/utils/launch_pay_url.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  group('launchPayUrl', () {
    late _RecordingUrlLauncher launcher;

    setUp(() {
      launcher = _RecordingUrlLauncher();
      UrlLauncherPlatform.instance = launcher;
    });

    test('null url throws missing_pay_url', () async {
      try {
        await launchPayUrl(null);
        fail('expected launchPayUrl(null) to throw');
      } on StateError catch (e) {
        expect(e.message, 'missing_pay_url');
      }
    });

    test('empty url throws missing_pay_url', () async {
      try {
        await launchPayUrl('');
        fail('expected launchPayUrl("") to throw');
      } on StateError catch (e) {
        expect(e.message, 'missing_pay_url');
      }
    });

    test('unparseable url throws invalid_pay_url', () async {
      // `Uri.tryParse` returns null for malformed authority / IPv6 forms.
      try {
        await launchPayUrl('http://[');
        fail('expected launchPayUrl to throw on unparseable input');
      } on StateError catch (e) {
        expect(e.message, 'invalid_pay_url');
      }
    });

    test('platform refusal throws launch_failed', () async {
      launcher.nextResult = false;
      try {
        await launchPayUrl('https://example.com/checkout');
        fail('expected launchPayUrl to throw when platform refuses');
      } on StateError catch (e) {
        expect(e.message, 'launch_failed');
      }
    });

    test(
      'successful launch does not throw and forwards the parsed uri',
      () async {
        launcher.nextResult = true;
        const target = 'https://example.com/checkout?plan=pro';
        await launchPayUrl(target);
        expect(launcher.lastUrl, isNotNull);
        expect(launcher.lastUrl, target);
      },
    );
  });
}

final class _RecordingUrlLauncher extends UrlLauncherPlatform {
  bool nextResult = true;
  String? lastUrl;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastUrl = url;
    return nextResult;
  }

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<void> closeWebView() async {}

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => false;
}
