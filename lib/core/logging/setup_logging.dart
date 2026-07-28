/// Attaches [Logger.root] output to Flutter DevTools / debug console.
///
/// Mirrors [Level.INFO] and higher (and any record carrying [LogRecord.error] /
/// [LogRecord.stackTrace]) to [debugPrint] so `flutter run` and plain terminals
/// show the same lines as DevTools. In debug mode, [Level.FINE] and below are
/// also mirrored to [debugPrint].
///
/// All builds also persist redacted records to a rotating file when supported.
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'diagnostic_log_config.dart';
import 'log_file_sink.dart';

bool _loggingHooked = false;
StreamSubscription<LogRecord>? _logSubscription;

/// Resets the [Logger.root] listener so a subsequent [setupAppLogging] call
/// re-attaches logging. Safe to call even when logging was never initialized.
///
/// Tests **must** call this between test runs (typically in [tearDown]) because
/// [Logger.root] and [LogFileSink._instance] are process-global state.
@visibleForTesting
Future<void> debugResetAppLogging() async {
  await _logSubscription?.cancel();
  _logSubscription = null;
  _loggingHooked = false;
  DiagnosticLogConfig.verboseEnabled = false;
}

/// Call once after [WidgetsFlutterBinding.ensureInitialized].
///
/// Call [DiagnosticLogConfig.loadFromDeviceGlobalSettings] before this when possible.
Future<void> setupAppLogging() async {
  if (_loggingHooked) return;
  _loggingHooked = true;

  await LogFileSink.ensureInitialized();

  Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
  _logSubscription = Logger.root.onRecord.listen((record) {
    final mirrorToStdout =
        record.level >= Level.INFO ||
        record.error != null ||
        record.stackTrace != null;

    if (DiagnosticLogConfig.shouldPersistRecord(record)) {
      unawaited(LogFileSink.instance?.writeRecord(record));
    }

    if (mirrorToStdout || kDebugMode) {
      final header = '[${record.level.name}] ${record.loggerName}:';
      debugPrint('$header ${record.message}');
      if (record.error != null) {
        debugPrint('$header error: ${record.error}');
      }
      if (record.stackTrace != null) {
        debugPrint('$header stack:\n${record.stackTrace}');
      }
    }
    developer.log(
      record.message,
      name: record.loggerName,
      level: record.level.value,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
}
