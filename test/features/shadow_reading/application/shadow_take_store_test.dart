// Tests for ShadowTakeStore (issue #597) through its seam: in-memory Drift,
// a fake MicRecorder, a temp take directory, and a recording SyncEnqueueFn.
// The interface is the test surface — no widget tree, no platform channels.
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/shadow_reading/application/shadow_take_store.dart';
import 'package:enjoy_player/features/sync/domain/sync_types.dart';

/// Minimal RIFF PCM16 mono WAV (44-byte header + samples).
Uint8List buildPcm16Wav(List<int> samples, {int sampleRate = 16000}) {
  const bitsPerSample = 16;
  const numChannels = 1;
  final blockAlign = numChannels * bitsPerSample ~/ 8;
  final byteRate = sampleRate * blockAlign;
  final dataSize = samples.length * blockAlign;
  final data = ByteData(44 + dataSize);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, numChannels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, byteRate, Endian.little);
  data.setUint16(32, blockAlign, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

class FakeMicRecorder implements MicRecorder {
  bool permissionGranted = true;
  Object? permissionError;
  Object? startError;
  Object? stopError;
  String? Function()? stopResult;

  final startedPaths = <String>[];
  RecordConfig? lastConfig;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<bool> hasPermission() async {
    final e = permissionError;
    if (e != null) throw e;
    return permissionGranted;
  }

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    final e = startError;
    if (e != null) throw e;
    lastConfig = config;
    startedPaths.add(path);
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    final e = stopError;
    if (e != null) throw e;
    final r = stopResult;
    return r == null ? null : r();
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

const _region = TakeRegion(
  targetType: 'video',
  targetId: 'media-1',
  language: 'en',
  referenceText: 'hello world',
  startSec: 10.0,
  endSec: 12.5,
);

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late FakeMicRecorder recorder;
  late List<(SyncEntityType, String, SyncAction)> syncCalls;
  late ShadowTakeStore store;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('take_store_test');
    recorder = FakeMicRecorder();
    syncCalls = [];
    store = ShadowTakeStore(
      db: db,
      enqueueSync: (type, id, action) async {
        syncCalls.add((type, id, action));
      },
      recorderFactory: () => recorder,
      takeDirectory: tempDir,
    );
  });

  tearDown(() async {
    await store.dispose();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Starts a take and arms the fake so `stop` returns the started path.
  Future<String> startTake() async {
    await store.start(device: null);
    final path = recorder.startedPaths.last;
    recorder.stopResult = () => path;
    return path;
  }

  group('start', () {
    test(
      'captures into the take directory with 16 kHz mono WAV config',
      () async {
        await store.start(device: null);
        expect(recorder.startedPaths, hasLength(1));
        final path = recorder.startedPaths.single;
        expect(path, startsWith(tempDir.path));
        expect(path, endsWith('.wav'));
        expect(store.isActive, isTrue);
        final config = recorder.lastConfig!;
        expect(config.encoder, AudioEncoder.wav);
        expect(config.sampleRate, 16000);
        expect(config.numChannels, 1);
      },
    );

    test(
      'throws MicPermissionDeniedException when the OS denies the mic',
      () async {
        recorder.permissionGranted = false;
        await expectLater(
          store.start(device: null),
          throwsA(isA<MicPermissionDeniedException>()),
        );
        expect(recorder.startedPaths, isEmpty);
        expect(store.isActive, isFalse);
      },
    );

    test('propagates recorder start errors without going active', () async {
      recorder.startError = StateError('device busy');
      await expectLater(store.start(device: null), throwsA(isA<StateError>()));
      expect(store.isActive, isFalse);
    });
  });

  group('stopAndPersist', () {
    test(
      'persists hash, duration, reference fields and enqueues sync create',
      () async {
        final path = await startTake();
        final samples = List<int>.generate(
          1600,
          (i) => i.isEven ? 16000 : -16000,
        );
        final bytes = buildPcm16Wav(samples);
        await File(path).writeAsBytes(bytes);

        final outcome = await store.stopAndPersist(region: _region);
        final row = outcome.row;

        expect(outcome.looksSilent, isFalse);
        expect(
          row.id,
          path.split(Platform.pathSeparator).last.replaceAll('.wav', ''),
        );
        expect(row.targetType, 'video');
        expect(row.targetId, 'media-1');
        expect(row.language, 'en');
        expect(row.referenceText, 'hello world');
        expect(row.referenceStart, 10000);
        expect(row.referenceDuration, 2500);
        expect(row.duration, 100); // 1600 samples @ 16 kHz
        expect(row.md5, sha256.convert(bytes).toString());
        expect(row.localPath, path);
        expect(row.syncStatus, 'local');

        final stored = await db.recordingDao.getById(row.id);
        expect(stored, isNotNull);
        expect(stored!.id, row.id);
        expect(syncCalls, [
          (SyncEntityType.recording, row.id, SyncAction.create),
        ]);
        expect(store.isActive, isFalse);
      },
    );

    test('flags a silent WAV but still persists it', () async {
      final path = await startTake();
      await File(path).writeAsBytes(buildPcm16Wav(List.filled(1600, 0)));

      final outcome = await store.stopAndPersist(region: _region);
      expect(outcome.looksSilent, isTrue);
      expect(await db.recordingDao.getById(outcome.row.id), isNotNull);
      expect(syncCalls, hasLength(1));
    });

    test('throws TakeFileMissingException when the WAV is gone', () async {
      final path = await startTake();
      // No file written — simulates the recorder yielding nothing on disk.
      await expectLater(
        store.stopAndPersist(region: _region),
        throwsA(isA<TakeFileMissingException>()),
      );
      expect(path, isNotEmpty);
      expect(syncCalls, isEmpty);
    });

    test('throws TakeFileMissingException when stop yields no path', () async {
      await store.start(device: null);
      recorder.stopResult = null;
      await expectLater(
        store.stopAndPersist(region: _region),
        throwsA(isA<TakeFileMissingException>()),
      );
      expect(syncCalls, isEmpty);
    });

    test(
      'recreates the recorder after a persist (Windows stale-state fix)',
      () async {
        var created = 0;
        final countingStore = ShadowTakeStore(
          db: db,
          enqueueSync: (type, id, action) async {},
          recorderFactory: () {
            created++;
            return recorder;
          },
          takeDirectory: tempDir,
        );
        await countingStore.start(device: null);
        final path = recorder.startedPaths.last;
        recorder.stopResult = () => path;
        await File(path).writeAsBytes(buildPcm16Wav(List.filled(160, 8000)));
        expect(created, 1);
        await countingStore.stopAndPersist(region: _region);
        expect(created, 2);
        await countingStore.dispose();
      },
    );
  });

  group('cancel', () {
    test('deletes the captured WAV and leaves the store inactive', () async {
      final path = await startTake();
      await File(path).writeAsBytes(buildPcm16Wav(List.filled(160, 8000)));

      await store.cancel();

      expect(await File(path).exists(), isFalse);
      expect(store.isActive, isFalse);
      expect(syncCalls, isEmpty);
      await expectLater(
        store.stopAndPersist(region: _region),
        throwsA(isA<TakeFileMissingException>()),
      );
    });

    test('is a no-op when nothing is being captured', () async {
      await store.cancel();
      expect(recorder.stopCalls, 0);
      expect(store.isActive, isFalse);
    });
  });

  group('deleteTake', () {
    test('removes the file and row and enqueues sync delete', () async {
      final path = await startTake();
      final bytes = buildPcm16Wav(List.filled(160, 8000));
      await File(path).writeAsBytes(bytes);
      final outcome = await store.stopAndPersist(region: _region);
      final row = outcome.row;
      syncCalls.clear();

      await store.deleteTake(row);

      expect(await File(path).exists(), isFalse);
      expect(await db.recordingDao.getById(row.id), isNull);
      expect(syncCalls, [
        (SyncEntityType.recording, row.id, SyncAction.delete),
      ]);
    });

    test('tolerates a row whose file is already gone', () async {
      final inserted = RecordingRow(
        id: 'orphan',
        targetType: 'video',
        targetId: 'media-1',
        referenceStart: 0,
        referenceDuration: 1000,
        referenceText: '',
        language: 'en',
        duration: 100,
        localPath: '${tempDir.path}/never-there.wav',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await db.recordingDao.insertRow(inserted);

      await store.deleteTake(inserted);

      expect(await db.recordingDao.getById('orphan'), isNull);
      expect(syncCalls, [
        (SyncEntityType.recording, 'orphan', SyncAction.delete),
      ]);
    });
  });

  group('dispose', () {
    test('discards an in-flight capture', () async {
      final path = await startTake();
      await File(path).writeAsBytes(buildPcm16Wav(List.filled(160, 8000)));

      await store.dispose();

      expect(await File(path).exists(), isFalse);
      expect(store.isActive, isFalse);
    });
  });
}
