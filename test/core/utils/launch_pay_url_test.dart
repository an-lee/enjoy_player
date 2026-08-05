// Invariants for the `launch_pay_url.dart` checkout-launch helper.
//
// The function is consumed by both the credits and subscription purchase
// sheets, which pattern-match on `StateError(:final message)` to surface a
// user-facing reason. These tests pin three things:
//
//   1. Each branch throws a `PayUrlLaunchException` carrying the right
//      `PayUrlLaunchFailure` enum value, so new call sites can switch on
//      the structured value without parsing strings.
//   2. The thrown error is still a `StateError` (and an `Exception`) with the
//      historical `'missing_pay_url'` / `'invalid_pay_url'` / `'launch_failed'`
//      message, so the existing `StateError(:final message) when` matches at
//      the call sites keep firing.
//   3. The message-key strings — the public contract consumed by the UI — are
//      pinned verbatim so a rename would break this test on purpose.
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

    test('null url throws missing as PayUrlLaunchException', () async {
      try {
        await launchPayUrl(null);
        fail('expected launchPayUrl(null) to throw');
      } on PayUrlLaunchException catch (e) {
        expect(e.failure, PayUrlLaunchFailure.missing);
        expect(e.message, 'missing_pay_url');
        expect(e, isA<StateError>());
        expect(e, isA<Exception>());
      }
    });

    test('empty url throws missing', () async {
      try {
        await launchPayUrl('');
        fail('expected launchPayUrl("") to throw');
      } on PayUrlLaunchException catch (e) {
        expect(e.failure, PayUrlLaunchFailure.missing);
        expect(e.message, 'missing_pay_url');
      }
    });

    test('unparseable url throws invalid', () async {
      // `Uri.tryParse` returns null for malformed authority / IPv6 forms.
      try {
        await launchPayUrl('http://[');
        fail('expected launchPayUrl to throw on unparseable input');
      } on PayUrlLaunchException catch (e) {
        expect(e.failure, PayUrlLaunchFailure.invalid);
        expect(e.message, 'invalid_pay_url');
      }
    });

    test('platform refusal throws launchFailed', () async {
      launcher.nextResult = false;
      try {
        await launchPayUrl('https://example.com/checkout');
        fail('expected launchPayUrl to throw when platform refuses');
      } on PayUrlLaunchException catch (e) {
        expect(e.failure, PayUrlLaunchFailure.launchFailed);
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

    test(
      'message keys are pinned for backwards-compatible StateError catch',
      () {
        // The credits + subscription sheets match on these exact strings
        // (`StateError(:final message) when message == 'missing_pay_url'`).
        // Renaming any of them is a breaking change for those call sites.
        expect(PayUrlLaunchFailure.missing.message, 'missing_pay_url');
        expect(PayUrlLaunchFailure.invalid.message, 'invalid_pay_url');
        expect(PayUrlLaunchFailure.launchFailed.message, 'launch_failed');
      },
    );

    test('every failure variant produces a non-blank message', () {
      for (final f in PayUrlLaunchFailure.values) {
        expect(f.message, isNotEmpty, reason: '${f.name} has blank message');
      }
    });
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
