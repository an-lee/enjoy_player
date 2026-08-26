/// Self-registration of the `enjoyplayer://` URL scheme on Linux.
///
/// Browsers resolve OAuth PKCE callbacks (`enjoyplayer://auth/callback`)
/// through xdg-open, which needs a desktop entry declaring
/// `MimeType=x-scheme-handler/enjoyplayer` in the user's applications
/// directory. Plain AppImage runs and dev builds never register one by
/// themselves, so this module installs it on startup and right before a web
/// PKCE sign-in starts (ADR-0084).
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'package:enjoy_player/core/logging/log.dart';

final Logger _log = logNamed('linux.url_scheme');

const String _scheme = 'enjoyplayer';
const String _desktopFileName = 'enjoy-player-scheme.desktop';

/// `Exec=` value pointing at the running install.
///
/// Inside an AppImage [Platform.resolvedExecutable] lives in a temporary
/// mount that disappears with the process; prefer `$APPIMAGE`, which the
/// AppImage runtime sets to the actual `.AppImage` file path.
@visibleForTesting
String schemeHandlerExecValue({
  String? appImagePath,
  required String resolvedExecutablePath,
}) {
  final target = (appImagePath != null && appImagePath.isNotEmpty)
      ? appImagePath
      : resolvedExecutablePath;
  // Desktop-entry spec: quote paths (spaces are legal) and escape `%` as
  // `%%`; append `%u` so the invoked URI reaches the binary.
  final escaped = target.replaceAll('%', '%%');
  return '"$escaped" %u';
}

@visibleForTesting
String buildSchemeHandlerDesktopEntry({required String exec}) =>
    '[Desktop Entry]\n'
    'Type=Application\n'
    'Name=Enjoy Player\n'
    'Exec=$exec\n'
    'Terminal=false\n'
    'MimeType=x-scheme-handler/$_scheme;\n'
    'NoDisplay=true\n';

/// Writes the handler desktop entry into the user's applications directory
/// and makes it the default handler for the scheme. Safe to call repeatedly:
/// the file is only rewritten when its content changed, and every failure is
/// contained (the caller must never block sign-in on registration).
Future<void> ensureEnjoyplayerSchemeHandler({
  Directory? applicationsDirOverride,
  bool runDesktopIntegrationCommands = true,
}) async {
  try {
    if (!Platform.isLinux) return;
    final appsDir = applicationsDirOverride ?? _userApplicationsDir();
    await appsDir.create(recursive: true);

    final file = File(p.join(appsDir.path, _desktopFileName));
    final entry = buildSchemeHandlerDesktopEntry(
      exec: schemeHandlerExecValue(
        appImagePath: Platform.environment['APPIMAGE'],
        resolvedExecutablePath: Platform.resolvedExecutable,
      ),
    );
    final existing = await file.exists() ? await file.readAsString() : null;
    if (existing != entry) {
      await file.writeAsString(entry, flush: true);
      _log.info('wrote $_scheme handler entry: ${file.path}');
    }

    if (!runDesktopIntegrationCommands) return;
    await _runQuietly('update-desktop-database', [appsDir.path]);
    await _runQuietly('xdg-mime', [
      'default',
      _desktopFileName,
      'x-scheme-handler/$_scheme',
    ]);
  } on Object catch (e, st) {
    _log.warning('$_scheme scheme registration failed', e, st);
  }
}

/// Runs a desktop-integration helper; a missing binary or non-zero exit is
/// logged but never fatal (the desktop file alone is often enough for gio).
Future<void> _runQuietly(String executable, List<String> args) async {
  try {
    final result = await Process.run(executable, args);
    if (result.exitCode != 0) {
      _log.warning(
        '$executable failed (exit ${result.exitCode}): '
        '${'${result.stderr}'.trim()}',
      );
    }
  } on Object catch (e) {
    _log.warning('$executable unavailable: $e');
  }
}

Directory _userApplicationsDir() {
  final home = Platform.environment['HOME'] ?? '/';
  final dataHome =
      Platform.environment['XDG_DATA_HOME'] ?? p.join(home, '.local', 'share');
  return Directory(p.join(dataHome, 'applications'));
}
