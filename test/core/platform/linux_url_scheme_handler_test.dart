import 'dart:io';

import 'package:enjoy_player/core/platform/linux_url_scheme_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('schemeHandlerExecValue', () {
    test('prefers the AppImage file over the temporary mount', () {
      final exec = schemeHandlerExecValue(
        appImagePath: '/home/u/Downloads/enjoy-player-0.5.0-x86_64.AppImage',
        resolvedExecutablePath: '/tmp/.mount_enjoy/AppRun',
      );
      expect(exec, '"/home/u/Downloads/enjoy-player-0.5.0-x86_64.AppImage" %u');
    });

    test('falls back to the resolved executable outside AppImages', () {
      final exec = schemeHandlerExecValue(
        resolvedExecutablePath:
            '/home/u/Projects/enjoy_player/build/linux/x64/debug/bundle/enjoy_player',
      );
      expect(
        exec,
        '"/home/u/Projects/enjoy_player/build/linux/x64/debug/bundle/enjoy_player" %u',
      );
    });

    test('quotes paths with spaces and escapes percent signs', () {
      final exec = schemeHandlerExecValue(
        appImagePath: '/home/u/My Downloads/enjoy%player.AppImage',
        resolvedExecutablePath: '/unused',
      );
      expect(exec, '"/home/u/My Downloads/enjoy%%player.AppImage" %u');
    });
  });

  group('buildSchemeHandlerDesktopEntry', () {
    test('declares the enjoyplayer scheme and passes the URI via %u', () {
      final entry = buildSchemeHandlerDesktopEntry(exec: '"/opt/app" %u');
      expect(entry, contains('MimeType=x-scheme-handler/enjoyplayer;'));
      expect(entry, contains('Exec="/opt/app" %u'));
      expect(entry, contains('Type=Application'));
    });
  });

  group('ensureEnjoyplayerSchemeHandler', () {
    late Directory appsDir;

    setUp(() {
      appsDir = Directory(
        p.join(Directory.systemTemp.createTempSync().path, 'apps'),
      );
    });

    tearDown(() {
      appsDir.parent.deleteSync(recursive: true);
    });

    test('writes the desktop entry into the applications directory', () async {
      await ensureEnjoyplayerSchemeHandler(
        applicationsDirOverride: appsDir,
        runDesktopIntegrationCommands: false,
      );

      final file = File(p.join(appsDir.path, 'enjoy-player-scheme.desktop'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('MimeType=x-scheme-handler/enjoyplayer;'));
      expect(content, contains('%u'));
      expect(
        content,
        contains('"${Platform.resolvedExecutable.replaceAll('%', '%%')}"'),
      );
    });

    test('is idempotent — unchanged entries are not rewritten', () async {
      Future<void> write() => ensureEnjoyplayerSchemeHandler(
        applicationsDirOverride: appsDir,
        runDesktopIntegrationCommands: false,
      );
      await write();
      final file = File(p.join(appsDir.path, 'enjoy-player-scheme.desktop'));
      final before = file.statSync().modified;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await write();
      expect(file.statSync().modified, before);
    });
  });
}
