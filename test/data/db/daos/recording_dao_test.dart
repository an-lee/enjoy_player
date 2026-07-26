// Tests for `lib/data/db/daos/recording_dao.dart` (and the Recordings
// table generated accessors in `app_database.g.dart`).
import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

RecordingRow _recording({
  required String id,
  String targetType = 'Video',
  String targetId = 'm1',
  String language = 'en',
  int referenceStart = 0,
  int referenceDuration = 1500,
  String referenceText = 'hello world',
  int duration = 1500,
  DateTime? createdAt,
  DateTime? updatedAt,
  int? pronunciationScore,
  String? assessmentJson,
}) {
  final ts = createdAt ?? DateTime.utc(2026, 1, 1);
  return RecordingRow(
    id: id,
    targetType: targetType,
    targetId: targetId,
    referenceStart: referenceStart,
    referenceDuration: referenceDuration,
    referenceText: referenceText,
    language: language,
    duration: duration,
    createdAt: ts,
    updatedAt: updatedAt ?? ts,
    pronunciationScore: pronunciationScore,
    assessmentJson: assessmentJson,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('RecordingDao', () {
    test('insertRow + getById round-trip', () async {
      await db.recordingDao.insertRow(_recording(id: 'r1'));
      final row = await db.recordingDao.getById('r1');
      expect(row?.referenceText, 'hello world');
      expect(row?.language, 'en');
    });

    test('getById returns null for unknown id', () async {
      expect(await db.recordingDao.getById('missing'), isNull);
    });

    test('listByEchoRegion returns overlapping recordings', () async {
      // Echo window: 1000ms-3000ms.
      await db.recordingDao.insertRow(
        _recording(id: 'a', referenceStart: 500, referenceDuration: 1000),
      ); // [500,1500] overlaps
      await db.recordingDao.insertRow(
        _recording(id: 'b', referenceStart: 2500, referenceDuration: 1000),
      ); // [2500,3500] overlaps
      await db.recordingDao.insertRow(
        _recording(id: 'c', referenceStart: 4000, referenceDuration: 1000),
      ); // [4000,5000] no overlap
      await db.recordingDao.insertRow(
        _recording(id: 'd', referenceStart: 0, referenceDuration: 500),
      ); // [0,500] no overlap

      final list = await db.recordingDao.listByEchoRegion(
        targetType: 'Video',
        targetId: 'm1',
        language: 'en',
        echoStartMs: 1000,
        echoEndMs: 3000,
      );
      final ids = list.map((r) => r.id).toSet();
      expect(ids, {'a', 'b'});
    });

    test('listByEchoRegion orders by createdAt desc', () async {
      await db.recordingDao.insertRow(
        _recording(
          id: 'old',
          referenceStart: 500,
          referenceDuration: 1000,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await db.recordingDao.insertRow(
        _recording(
          id: 'new',
          referenceStart: 500,
          referenceDuration: 1000,
          createdAt: DateTime.utc(2026, 6, 1),
        ),
      );

      final list = await db.recordingDao.listByEchoRegion(
        targetType: 'Video',
        targetId: 'm1',
        language: 'en',
        echoStartMs: 0,
        echoEndMs: 5000,
      );
      expect(list.first.id, 'new');
      expect(list.last.id, 'old');
    });

    test('updateAssessment writes scores and resets syncStatus', () async {
      await db.recordingDao.insertRow(_recording(id: 'r1'));
      await db.recordingDao.updateAssessment(
        id: 'r1',
        pronunciationScore: 87,
        assessmentJson: '{"score":87}',
        updatedAt: DateTime.utc(2026, 6, 1),
      );
      final row = await db.recordingDao.getById('r1');
      expect(row?.pronunciationScore, 87);
      expect(row?.assessmentJson, '{"score":87}');
      expect(row?.syncStatus, 'local');
    });

    test('deleteId removes a recording', () async {
      await db.recordingDao.insertRow(_recording(id: 'r1'));
      await db.recordingDao.deleteId('r1');
      expect(await db.recordingDao.getById('r1'), isNull);
    });

    test('watchByTarget orders by createdAt desc', () async {
      await db.recordingDao.insertRow(
        _recording(id: 'old', createdAt: DateTime.utc(2026, 1, 1)),
      );
      await db.recordingDao.insertRow(
        _recording(id: 'new', createdAt: DateTime.utc(2026, 6, 1)),
      );

      final list = await db.recordingDao.watchByTarget('Video', 'm1').first;
      expect(list.first.id, 'new');
      expect(list.last.id, 'old');
    });

    test('watchByTarget ignores recordings from other targets', () async {
      await db.recordingDao.insertRow(_recording(id: 'mine', targetId: 'm1'));
      await db.recordingDao.insertRow(_recording(id: 'other', targetId: 'm2'));
      final list = await db.recordingDao.watchByTarget('Video', 'm1').first;
      expect(list.map((r) => r.id), ['mine']);
    });

    test('watchByEchoRegion streams only the matching recordings', () async {
      await db.recordingDao.insertRow(
        _recording(id: 'a', referenceStart: 1500, referenceDuration: 500),
      );
      await db.recordingDao.insertRow(
        _recording(id: 'b', referenceStart: 5000, referenceDuration: 500),
      );
      final list = await db.recordingDao
          .watchByEchoRegion(
            targetType: 'Video',
            targetId: 'm1',
            language: 'en',
            echoStartMs: 1000,
            echoEndMs: 2000,
          )
          .first;
      expect(list.map((r) => r.id), ['a']);
    });

    test('insertRow with insertOrReplace overwrites by id', () async {
      await db.recordingDao.insertRow(_recording(id: 'r1', referenceText: 'A'));
      await db.recordingDao.insertRow(_recording(id: 'r1', referenceText: 'B'));
      final row = await db.recordingDao.getById('r1');
      expect(row?.referenceText, 'B');
    });
  });

  group('recordingOverlapsEchoRegion', () {
    RecordingRow rec(int start, int duration) =>
        _recording(id: 'r', referenceStart: start, referenceDuration: duration);

    test('fully inside returns true', () {
      expect(recordingOverlapsEchoRegion(rec(1000, 1000), 0, 5000), isTrue);
    });

    test('fully outside (before) returns false', () {
      expect(recordingOverlapsEchoRegion(rec(100, 200), 1000, 2000), isFalse);
    });

    test('fully outside (after) returns false', () {
      expect(recordingOverlapsEchoRegion(rec(5000, 200), 1000, 2000), isFalse);
    });

    test('touching at boundary (end == start) returns false', () {
      // Recording [0,1000], echo [1000,2000]: overlapStart=1000, overlapEnd=1000
      // → 1000 < 1000 is false.
      expect(recordingOverlapsEchoRegion(rec(0, 1000), 1000, 2000), isFalse);
    });

    test('partial overlap on left edge', () {
      expect(recordingOverlapsEchoRegion(rec(800, 400), 1000, 2000), isTrue);
    });

    test('partial overlap on right edge', () {
      expect(recordingOverlapsEchoRegion(rec(1800, 400), 1000, 2000), isTrue);
    });
  });
}
