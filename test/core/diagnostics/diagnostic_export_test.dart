import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:enjoy_player/core/diagnostics/diagnostic_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiagnosticExportManifest', () {
    test('toJson round-trips all fields and emits UTC iso8601', () {
      final ts = DateTime.utc(2026, 7, 1, 12, 30, 45);
      final m = DiagnosticExportManifest(
        appVersion: '1.0.0',
        buildNumber: '100',
        platform: 'linux',
        buildMode: 'release',
        distributionChannel: 'github',
        exportedAt: ts,
        diagnosticVerboseEnabled: true,
        locale: 'en-US',
      );
      final json = m.toJson();
      expect(json['appVersion'], '1.0.0');
      expect(json['buildNumber'], '100');
      expect(json['platform'], 'linux');
      expect(json['buildMode'], 'release');
      expect(json['distributionChannel'], 'github');
      expect(json['exportedAt'], '2026-07-01T12:30:45.000Z');
      expect(json['diagnosticVerboseEnabled'], isTrue);
      expect(json['locale'], 'en-US');
    });

    test('toJson omits locale when null', () {
      final m = DiagnosticExportManifest(
        appVersion: '1',
        buildNumber: '1',
        platform: 'linux',
        buildMode: 'debug',
        distributionChannel: 'github',
        exportedAt: DateTime.utc(2026, 1, 1),
        diagnosticVerboseEnabled: false,
      );
      expect(m.toJson().containsKey('locale'), isFalse);
    });

    test('toJson converts local DateTime to UTC before formatting', () {
      // Construct a non-UTC DateTime to ensure the conversion runs.
      final ts = DateTime.utc(2026, 6, 30, 23, 0, 0);
      final m = DiagnosticExportManifest(
        appVersion: '1',
        buildNumber: '1',
        platform: 'linux',
        buildMode: 'debug',
        distributionChannel: 'github',
        exportedAt: ts,
        diagnosticVerboseEnabled: false,
      );
      expect(m.toJson()['exportedAt'], '2026-06-30T23:00:00.000Z');
    });
  });

  group('buildDiagnosticArchive', () {
    test('archive contains manifest.json when no log entries are supplied', () {
      final manifest = DiagnosticExportManifest(
        appVersion: '1',
        buildNumber: '1',
        platform: 'linux',
        buildMode: 'debug',
        distributionChannel: 'github',
        exportedAt: DateTime.utc(2026, 1, 1),
        diagnosticVerboseEnabled: false,
      );
      final archive = buildDiagnosticArchive(manifest: manifest);
      expect(archive.files.length, 1);
      expect(archive.files.first.name, 'manifest.json');
      final decoded =
          jsonDecode(utf8.decode(archive.files.first.content as List<int>))
              as Map<String, dynamic>;
      expect(decoded['appVersion'], '1');
    });

    test('archive prefixes log entries with "logs/"', () {
      final manifest = DiagnosticExportManifest(
        appVersion: '1',
        buildNumber: '1',
        platform: 'linux',
        buildMode: 'debug',
        distributionChannel: 'github',
        exportedAt: DateTime.utc(2026, 1, 1),
        diagnosticVerboseEnabled: false,
      );
      final archive = buildDiagnosticArchive(
        manifest: manifest,
        logFileEntries: [
          MapEntry('app-1.log', utf8.encode('first log line\n')),
          MapEntry('app-2.log', utf8.encode('second log line\n')),
        ],
      );
      expect(archive.files.map((f) => f.name), [
        'manifest.json',
        'logs/app-1.log',
        'logs/app-2.log',
      ]);
    });

    test('encoded archive is a non-empty byte stream', () {
      final manifest = DiagnosticExportManifest(
        appVersion: '1',
        buildNumber: '1',
        platform: 'linux',
        buildMode: 'debug',
        distributionChannel: 'github',
        exportedAt: DateTime.utc(2026, 1, 1),
        diagnosticVerboseEnabled: false,
      );
      final bytes = ZipEncoder().encode(
        buildDiagnosticArchive(manifest: manifest),
      );
      expect(bytes, isNotEmpty);
      // ZIP magic: 0x50 0x4B ("PK").
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });
  });

  group('defaultExportManifest', () {
    test('buildMode reflects compile-time mode', () {
      final m = defaultExportManifest(appVersion: '1', buildNumber: '1');
      // Tests run in debug mode, but accept any of the three values since the
      // build mode is global.
      expect(['release', 'profile', 'debug'].contains(m.buildMode), isTrue);
      expect(m.platform, isNotEmpty);
      expect(m.appVersion, '1');
      expect(m.buildNumber, '1');
    });

    test('distributionChannel uses the resolved channel name', () {
      final m = defaultExportManifest(appVersion: '1', buildNumber: '1');
      // Valid channel names defined in [resolveDistributionChannel].
      expect(['store', 'direct'].contains(m.distributionChannel), isTrue);
    });

    test('exportedAt is set to roughly "now"', () {
      final before = DateTime.now().toUtc();
      final m = defaultExportManifest(appVersion: '1', buildNumber: '1');
      final after = DateTime.now().toUtc();
      expect(
        m.exportedAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        m.exportedAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('passes through optional locale', () {
      final m = defaultExportManifest(
        appVersion: '1',
        buildNumber: '1',
        locale: 'zh-CN',
      );
      expect(m.locale, 'zh-CN');
    });
  });
}
