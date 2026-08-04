/// External checkout URL launch for purchase flows (credits + subscription).
library;

import 'package:url_launcher/url_launcher.dart';

/// Stable, machine-readable failure categories for [launchPayUrl].
///
/// The `name` doubles as the persisted `StateError.message` string so the
/// existing `on StateError catch (e)` and `StateError(:final message) when`
/// pattern matches at call sites continue to work without changes.
enum PayUrlLaunchFailure {
  missing('missing_pay_url'),
  invalid('invalid_pay_url'),
  launchFailed('launch_failed');

  const PayUrlLaunchFailure(this.message);

  /// The `StateError.message` value this failure produces.
  final String message;
}

/// Typed exception thrown by [launchPayUrl].
///
/// `extends StateError` so every existing `on StateError` / `StateError(:final
/// message) when` catch site keeps working unchanged. New call sites can
/// prefer the structured [failure] enum for switch-style handling.
class PayUrlLaunchException extends StateError implements Exception {
  PayUrlLaunchException(this.failure)
      : super(
          failure.message,
        );

  /// Which checkout-launch failure category this exception represents.
  final PayUrlLaunchFailure failure;
}

/// Validates [url] and opens it in the external browser.
///
/// Throws [PayUrlLaunchException] (which `is StateError` and `is Exception`)
/// when the checkout URL is absent, unparseable, or the platform refuses to
/// launch it. The `failure` field exposes the structured category; the
/// inherited `message` keeps the historical `'missing_pay_url' /
/// 'invalid_pay_url' / 'launch_failed'` string for backwards compatibility.
Future<void> launchPayUrl(String? url) async {
  if (url == null || url.isEmpty) {
    throw PayUrlLaunchException(PayUrlLaunchFailure.missing);
  }
  final uri = Uri.tryParse(url);
  if (uri == null) {
    throw PayUrlLaunchException(PayUrlLaunchFailure.invalid);
  }
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    throw PayUrlLaunchException(PayUrlLaunchFailure.launchFailed);
  }
}
