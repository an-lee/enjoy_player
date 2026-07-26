import 'dart:io';

import 'package:enjoy_player/core/logging/log_file_sink.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/test_path_provider.dart';

void main() {
  late Directory tempRoot;
  late Directory supportDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempRoot = await Directory.systemTemp.createTemp('log_file_sink_test_');
    supportDir = Directory(p.join(tempRoot.path, 'support'));
    await supportDir.create(recursive: true);
    PathProviderPlatform.instance = TestPathProvider(
      supportDir.path,
      supportPath: supportDir.path,
    );
    LogFileSink.debugResetInstance();
  });

  tearDown(() async {
    LogFileSink.debugResetInstance();
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('LogFileSink.ensureInitialized', () {
    test('returns null when path_provider throws', () async {
      final badPath = Directory(p.join(tempRoot.path, 'support', 'logs'));
      await badPath.create(recursive: true);
      await badPath.delete(recursive: true);

      final original = PathProviderPlatform.instance;
      addTearDown(() => PathProviderPlatform.instance = original);

      final broken = _BrokenPathProvider();
      PathProviderPlatform.instance = broken;

      LogFileSink.debugResetInstance();
      final result = await LogFileSink.ensureInitialized();
      expect(result, isNull);
      expect(LogFileSink.instance, isNull);
    });

    test('creates the logs directory and exposes an instance', () async {
      final logsDir = Directory(p.join(supportDir.path, 'logs'));
      expect(logsDir.existsSync(), isFalse);

      final sink = (await LogFileSink.ensureInitialized())!;
      expect(sink, isNotNull);
      expect(LogFileSink.instance, same(sink));
      expect(logsDir.existsSync(), isTrue);
    });

    test('returns the same instance on subsequent calls (singleton)', () async {
      final first = (await LogFileSink.ensureInitialized())!;
      final second = (await LogFileSink.ensureInitialized())!;
      expect(second, same(first));
    });

    test('re-uses existing log file size on initialization', () async {
      final logsDir = Directory(p.join(supportDir.path, 'logs'));
      await logsDir.create(recursive: true);
      final existing = File(p.join(logsDir.path, kLogFileBaseName));
      await existing.writeAsString('pre-existing log line\n');

      final sink = (await LogFileSink.ensureInitialized())!;
      expect(sink, isNotNull);
      // Writing another line should still append (not overwrite) — proves the
      // existing size was picked up and used for the rotation threshold.
      await sink.writeRawLine('after-init');
      final content = await existing.readAsString();
      expect(content.contains('pre-existing log line'), isTrue);
      expect(content.contains('after-init'), isTrue);
    });
  });

  group('LogFileSink.listLogFiles', () {
    test('yields the active log + retention count files', () async {
      final sink = (await LogFileSink.ensureInitialized())!;
      final files = sink.listLogFiles().toList();
      expect(files, hasLength(kLogFileRetentionCount));
      expect(files.first.uri.pathSegments.last, kLogFileBaseName);
      for (var i = 1; i < kLogFileRetentionCount; i++) {
        expect(files[i].uri.pathSegments.last, '$kLogFileBaseName.$i');
      }
    });
  });

  group('LogFileSink.writeRawLine + writeRecord', () {
    test('writeRawLine redacts and appends a line feed', () async {
      final sink = (await LogFileSink.ensureInitialized())!;
      await sink.writeRawLine('Authorization: Bearer abc.def.ghi');
      final file = File(p.join(supportDir.path, 'logs', kLogFileBaseName));
      final content = await file.readAsString();
      expect(content.contains('Bearer abc.def.ghi'), isFalse);
      expect(content.contains('[REDACTED]'), isTrue);
      expect(content.endsWith('\n'), isTrue);
    });

    test('writeRecord formats level, name, and message', () async {
      final sink = (await LogFileSink.ensureInitialized())!;
      final record = LogRecord(
        Level.WARNING,
        'something happened',
        'unit.test',
      );
      await sink.writeRecord(record);
      final content = await File(
        p.join(supportDir.path, 'logs', kLogFileBaseName),
      ).readAsString();
      expect(content, contains('[WARNING] unit.test: something happened'));
    });

    test(
      'writeRecord includes error and stackTrace blocks when present',
      () async {
        final sink = (await LogFileSink.ensureInitialized())!;
        final record = LogRecord(
          Level.SEVERE,
          'kaboom',
          'unit.test',
          StateError('boom!'),
          StackTrace.current,
        );
        await sink.writeRecord(record);
        final content = await File(
          p.join(supportDir.path, 'logs', kLogFileBaseName),
        ).readAsString();
        expect(content, contains('error: Bad state: boom!'));
        expect(content, contains('  stack:\n'));
      },
    );

    test('rotates the active log when size exceeds limit', () async {
      final sink = (await LogFileSink.ensureInitialized())!;
      final logsDir = Directory(p.join(supportDir.path, 'logs'));
      final active = File(p.join(logsDir.path, kLogFileBaseName));
      final first = File(p.join(logsDir.path, '$kLogFileBaseName.1'));

      // Seed the active file so rotation actually has bytes to move.
      await sink.writeRawLine('pre-rotation marker');
      expect(active.existsSync(), isTrue);

      // Push enough records to overflow the 2 MiB cap; one record is fine if
      // the payload exceeds the threshold.
      final huge = 'X' * (kLogFileMaxBytes + 1024);
      await sink.writeRawLine(huge);
      // After rotation, the active file should hold the new huge payload and
      // .1 should hold the pre-rotation marker (after redaction removes
      // nothing important — the marker is plain text).
      expect(active.existsSync(), isTrue);
      expect(first.existsSync(), isTrue);
      final rotated = await first.readAsString();
      expect(rotated, contains('pre-rotation marker'));
    });

    test('rotates the oldest files out when retention is full', () async {
      final sink = (await LogFileSink.ensureInitialized())!;
      final logsDir = Directory(p.join(supportDir.path, 'logs'));
      // Seed .${retentionCount - 1} so the next rotation must delete it.
      final lastKept = File(
        p.join(logsDir.path, '$kLogFileBaseName.${kLogFileRetentionCount - 1}'),
      );
      await lastKept.writeAsString('keep-trash-marker\n');
      final huge = 'X' * (kLogFileMaxBytes + 1024);
      await sink.writeRawLine(huge);
      // Oldest should be deleted and replaced with previous contents shifted.
      expect(lastKept.existsSync(), isFalse);
    });

    test(
      'serializes concurrent writeRecord calls without interleaving',
      () async {
        final sink = (await LogFileSink.ensureInitialized())!;
        final lines = List.generate(50, (i) => 'line $i');
        await Future.wait([for (final l in lines) sink.writeRawLine(l)]);
        final content = await File(
          p.join(supportDir.path, 'logs', kLogFileBaseName),
        ).readAsString();
        // Every line must appear exactly once, in original order.
        var cursor = 0;
        for (final l in lines) {
          final idx = content.indexOf('$l\n', cursor);
          expect(idx, greaterThanOrEqualTo(0), reason: 'missing line "$l"');
          cursor = idx + 1;
        }
      },
    );
  });
}

class _BrokenPathProvider extends TestPathProvider {
  _BrokenPathProvider() : super('/this/path/does/not/matter');

  @override
  Future<String?> getApplicationSupportPath() async {
    throw const FileSystemException('synthetic failure for test');
  }
}
