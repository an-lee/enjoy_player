// Tests for `lib/data/db/daos/echo_session_dao.dart` (and the EchoSessions
// table generated accessors in `app_database.g.dart`).
import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

EchoSessionRow _session({
  required String id,
  required String targetType,
  required String targetId,
  String language = 'en',
  DateTime? lastActiveAt,
}) {
  final ts = lastActiveAt ?? DateTime.utc(2026, 1, 1);
  return EchoSessionRow(
    id: id,
    targetType: targetType,
    targetId: targetId,
    language: language,
    currentTimeMs: 0,
    playbackRate: 1,
    volume: 1,
    echoStartMs: null,
    echoEndMs: null,
    transcriptId: null,
    secondaryTranscriptId: null,
    recordingsCount: 0,
    recordingsDurationMs: 0,
    lastRecordingAt: null,
    currentSegmentIndex: -1,
    echoActive: false,
    echoStartLine: -1,
    echoEndLine: -1,
    blurActive: false,
    startedAt: ts,
    lastActiveAt: ts,
    completedAt: null,
    syncStatus: null,
    serverUpdatedAt: null,
    createdAt: ts,
    updatedAt: ts,
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

  group('EchoSessionDao', () {
    test('getLatestForTarget returns null for unknown target', () async {
      expect(
        await db.echoSessionDao.getLatestForTarget('Video', 'missing'),
        isNull,
      );
    });

    test('getOrCreateLatestForTarget creates a new session', () async {
      final row = await db.echoSessionDao.getOrCreateLatestForTarget(
        'Video',
        'm1',
      );
      expect(row.targetType, 'Video');
      expect(row.targetId, 'm1');
      expect(row.id, isNotEmpty);
      // A new row should be persisted.
      final found = await db.echoSessionDao.getLatestForTarget('Video', 'm1');
      expect(found?.id, row.id);
    });

    test(
      'getOrCreateLatestForTarget returns existing session when present',
      () async {
        final first = await db.echoSessionDao.getOrCreateLatestForTarget(
          'Video',
          'm1',
        );
        final second = await db.echoSessionDao.getOrCreateLatestForTarget(
          'Video',
          'm1',
        );
        expect(second.id, first.id);
      },
    );

    test('upsert replaces existing row', () async {
      final first = await db.echoSessionDao.getOrCreateLatestForTarget(
        'Video',
        'm1',
      );
      final updated = first.copyWith(echoActive: true, recordingsCount: 3);
      await db.echoSessionDao.upsert(updated);

      final found = await db.echoSessionDao.getLatestForTarget('Video', 'm1');
      expect(found?.echoActive, isTrue);
      expect(found?.recordingsCount, 3);
    });

    test(
      'updatePrimaryTranscriptForTarget creates a session when missing',
      () async {
        await db.echoSessionDao.updatePrimaryTranscriptForTarget(
          'Video',
          'm2',
          'transcript-1',
        );
        final found = await db.echoSessionDao.getLatestForTarget('Video', 'm2');
        expect(found, isNotNull);
        expect(found!.transcriptId, 'transcript-1');
      },
    );

    test('updatePrimaryTranscriptForTarget updates existing session', () async {
      await db.echoSessionDao.getOrCreateLatestForTarget('Video', 'm1');
      await db.echoSessionDao.updatePrimaryTranscriptForTarget(
        'Video',
        'm1',
        'transcript-1',
      );
      final found = await db.echoSessionDao.getLatestForTarget('Video', 'm1');
      expect(found?.transcriptId, 'transcript-1');
    });

    test(
      'updateSecondaryTranscriptForTarget creates a session when missing',
      () async {
        await db.echoSessionDao.updateSecondaryTranscriptForTarget(
          'Video',
          'm3',
          'secondary-1',
        );
        final found = await db.echoSessionDao.getLatestForTarget('Video', 'm3');
        expect(found?.secondaryTranscriptId, 'secondary-1');
      },
    );

    test(
      'updateSecondaryTranscriptForTarget updates existing session',
      () async {
        await db.echoSessionDao.getOrCreateLatestForTarget('Video', 'm1');
        await db.echoSessionDao.updateSecondaryTranscriptForTarget(
          'Video',
          'm1',
          'secondary-1',
        );
        final found = await db.echoSessionDao.getLatestForTarget('Video', 'm1');
        expect(found?.secondaryTranscriptId, 'secondary-1');
      },
    );

    test('practiceTotals aggregates across all sessions', () async {
      await db.echoSessionDao.upsert(
        _session(
          id: 'a',
          targetType: 'Video',
          targetId: 'v1',
        ).copyWith(recordingsDurationMs: 1000),
      );
      await db.echoSessionDao.upsert(
        _session(
          id: 'b',
          targetType: 'Video',
          targetId: 'v2',
        ).copyWith(recordingsDurationMs: 2500),
      );

      final totals = await db.echoSessionDao.practiceTotals();
      expect(totals.sessionCount, 2);
      expect(totals.recordingsDurationMs, 3500);
    });

    test('practiceTotals returns 0/0 on empty DB', () async {
      final totals = await db.echoSessionDao.practiceTotals();
      expect(totals.sessionCount, 0);
      expect(totals.recordingsDurationMs, 0);
    });

    test('getLatestForTarget orders by lastActiveAt desc', () async {
      await db.echoSessionDao.upsert(
        _session(
          id: 'old',
          targetType: 'Video',
          targetId: 'm1',
          lastActiveAt: DateTime.utc(2020, 1, 1),
        ),
      );
      await db.echoSessionDao.upsert(
        _session(
          id: 'new',
          targetType: 'Video',
          targetId: 'm1',
          lastActiveAt: DateTime.utc(2030, 1, 1),
        ),
      );

      final found = await db.echoSessionDao.getLatestForTarget('Video', 'm1');
      expect(found?.id, 'new');
    });
  });
}
