import 'dart:async';
import 'dart:ui';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kProfileMode, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/platform/device_form_factor.dart';
import 'core/platform/espeak_android_provisioner.dart';
import 'core/recovery/widget_error_surface.dart';
import 'core/logging/diagnostic_log_config.dart';
import 'core/logging/diagnostic_session_header.dart';
import 'core/logging/log.dart';
import 'core/logging/setup_logging.dart';
import 'core/webview/platform_webview_environment.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(_bootstrap, _onZoneError);
}

final Logger _bootstrapLog = logNamed('bootstrap');

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _applyDeviceOrientationPolicy();
  if (!kDebugMode) {
    installReleaseWidgetErrorBuilder();
  }
  // Device-global settings DB + per-user signed-in DB use separate files and
  // executors; Drift's runtime "multiple databases" check is a false positive.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await Future.wait([
    DiagnosticLogConfig.loadFromDeviceGlobalSettings(),
    setupAppLogging(),
    if (defaultTargetPlatform == TargetPlatform.windows)
      ensureWindowsWebViewEnvironment(),
    if (defaultTargetPlatform == TargetPlatform.android)
      _provisionAndroidEspeak(),
  ]);
  _installFrameworkErrorHandlers();
  try {
    await writeDiagnosticSessionHeader();
  } on Object catch (e, st) {
    _bootstrapLog.warning('writeDiagnosticSessionHeader failed', e, st);
  }
  MediaKit.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(880, 560));
    await windowManager.waitUntilReadyToShow(const WindowOptions(), () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  const root = ProviderScope(child: EnjoyApp());
  Widget app = root;
  // Windows AXTree sync bug (flutter/flutter#182444): semantics churn from
  // ListView/Tooltip/etc. floods the console. Per-WebView ExcludeSemantics
  // alone is not enough; skip semantics in debug/profile on Windows only.
  if (defaultTargetPlatform == TargetPlatform.windows &&
      (kDebugMode || kProfileMode)) {
    app = const ExcludeSemantics(child: root);
  }
  runApp(app);
}

/// eSpeak-NG provisioning failures must not block startup; alignment then
/// stays fail-closed (`spokenReferenceUnavailable`).
Future<void> _provisionAndroidEspeak() async {
  try {
    await ensureAndroidEspeakRuntime();
  } on Object catch (e, st) {
    _bootstrapLog.warning('eSpeak provisioning failed', e, st);
  }
}

/// Phone: portrait lock. Tablet: all orientations. Desktop: no-op.
///
/// Uses the view's [Display] shortest side (not window [FlutterView.physicalSize])
/// so a zero/letterboxed window cannot misclassify a tablet as a phone.
/// When metrics are not ready yet, defers via [onMetricsChanged] instead of
/// guessing phone — a wrong portrait lock pillarboxes tablets in landscape.
///
/// Failures are logged and must not block [runApp].
Future<void> _applyDeviceOrientationPolicy() async {
  try {
    if (await _tryApplyDeviceOrientationPolicy()) return;

    _bootstrapLog.warning(
      'orientation policy: no usable display size yet; '
      'deferring until metrics are available',
    );

    final dispatcher = PlatformDispatcher.instance;
    final previous = dispatcher.onMetricsChanged;
    dispatcher.onMetricsChanged = () {
      previous?.call();
      unawaited(_applyDeferredOrientationPolicy(previous));
    };
  } on Object catch (e, st) {
    _bootstrapLog.warning('orientation policy failed', e, st);
  }
}

/// Returns `true` when a form factor was resolved and orientations applied
/// (or desktop no-op). Returns `false` when mobile metrics are still unknown.
Future<bool> _tryApplyDeviceOrientationPolicy() async {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return false;

  final shortest = logicalShortestSideFromView(views.first);
  final formFactor = resolveDeviceFormFactor(
    platform: defaultTargetPlatform,
    shortestSideLogical: shortest,
  );
  if (formFactor == null) return false;

  await applyPreferredOrientationsForFormFactor(formFactor);
  return true;
}

Future<void> _applyDeferredOrientationPolicy(
  void Function()? previousMetricsChanged,
) async {
  final dispatcher = PlatformDispatcher.instance;
  try {
    if (await _tryApplyDeviceOrientationPolicy()) {
      dispatcher.onMetricsChanged = previousMetricsChanged;
    }
  } on Object catch (e, st) {
    dispatcher.onMetricsChanged = previousMetricsChanged;
    _bootstrapLog.warning('orientation policy failed', e, st);
  }
}

void _installFrameworkErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    _bootstrapLog.severe(
      'FlutterError: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _bootstrapLog.severe('PlatformDispatcher error', error, stack);
    return true;
  };
}

void _onZoneError(Object error, StackTrace stack) {
  _bootstrapLog.severe('Uncaught zone error', error, stack);
}
