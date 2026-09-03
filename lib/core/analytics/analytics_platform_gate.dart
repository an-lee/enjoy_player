/// Platform gate for product analytics (specs/046, research D3).
library;

import 'dart:io' show Platform;

/// Whether the PostHog Flutter plugin ships a native implementation for this
/// platform (Android, iOS, macOS — the vendor's supported mobile/desktop set;
/// this app has no web target).
///
/// Windows and Linux have **no** native implementation — any vendor call
/// would throw `MissingPluginException` — so the analytics provider resolves
/// to the no-op implementation there (spec FR-008: inert by construction,
/// not by try/catch).
bool analyticsSupported() =>
    Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
