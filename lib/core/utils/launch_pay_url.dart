/// External checkout URL launch for purchase flows (credits + subscription).
library;

import 'package:url_launcher/url_launcher.dart';

/// Validates [url] and opens it in the external browser.
///
/// Throws [StateError] with the stable machine-readable message
/// `'missing_pay_url'`, `'invalid_pay_url'`, or `'launch_failed'` — call sites
/// match on those strings via `StateError(:final message) when`.
Future<void> launchPayUrl(String? url) async {
  if (url == null || url.isEmpty) {
    throw StateError('missing_pay_url');
  }
  final uri = Uri.tryParse(url);
  if (uri == null) {
    throw StateError('invalid_pay_url');
  }
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    throw StateError('launch_failed');
  }
}
