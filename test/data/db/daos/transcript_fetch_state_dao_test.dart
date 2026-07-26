import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('TranscriptFetchStateDao', () {
    test('getForTarget returns null for unknown target', () async {
      expect(
        await db.transcriptFetchStateDao.getForTarget('video', 'v-1'),
        isNull,
      );
    });

    test('upsertFetched inserts a new state row with success status', () async {
      final ts = DateTime.utc(2026, 7, 1);
      await db.transcriptFetchStateDao.upsertFetched('video', 'v-1', ts);
      final row = await db.transcriptFetchStateDao.getForTarget('video', 'v-1');
      expect(row, isNotNull);
      expect(row!.lastFetchedAt.toUtc(), ts);
      expect(row.lastStatus, 'success');
      expect(row.lastError, isNull);
    });

    test('upsertFetched records optional lastError', () async {
      final ts = DateTime.utc(2026, 7, 1);
      await db.transcriptFetchStateDao.upsertFetched(
        'video',
        'v-1',
        ts,
        lastStatus: 'failed',
        lastError: 'boom',
      );
      final row = await db.transcriptFetchStateDao.getForTarget('video', 'v-1');
      expect(row!.lastStatus, 'failed');
      expect(row.lastError, 'boom');
    });

    test('upsertFetched upserts on existing target', () async {
      final first = DateTime.utc(2026, 6, 1);
      final second = DateTime.utc(2026, 7, 1);
      await db.transcriptFetchStateDao.upsertFetched('video', 'v-1', first);
      await db.transcriptFetchStateDao.upsertFetched(
        'video',
        'v-1',
        second,
        lastStatus: 'failed',
        lastError: 'again',
      );
      final row = await db.transcriptFetchStateDao.getForTarget('video', 'v-1');
      expect(row!.lastFetchedAt.toUtc(), second);
      expect(row.lastStatus, 'failed');
      expect(row.lastError, 'again');
    });

    test('upsertOutcome records arbitrary lastStatus', () async {
      await db.transcriptFetchStateDao.upsertOutcome(
        targetType: 'audio',
        targetId: 'a-1',
        lastFetchedAt: DateTime.utc(2026, 7, 1),
        lastStatus: 'partial',
      );
      final row = await db.transcriptFetchStateDao.getForTarget('audio', 'a-1');
      expect(row!.lastStatus, 'partial');
    });

    test('getForTarget isolates by targetType and targetId', () async {
      await db.transcriptFetchStateDao.upsertFetched(
        'video',
        'v-1',
        DateTime.utc(2026, 7, 1),
      );
      await db.transcriptFetchStateDao.upsertFetched(
        'audio',
        'a-1',
        DateTime.utc(2026, 7, 1),
      );
      expect(
        (await db.transcriptFetchStateDao.getForTarget(
          'video',
          'v-1',
        ))!.lastStatus,
        'success',
      );
      expect(
        (await db.transcriptFetchStateDao.getForTarget(
          'audio',
          'a-1',
        ))!.lastStatus,
        'success',
      );
      expect(
        await db.transcriptFetchStateDao.getForTarget('video', 'v-2'),
        isNull,
      );
    });

    test('clearForTarget removes a single state row', () async {
      await db.transcriptFetchStateDao.upsertFetched(
        'video',
        'v-1',
        DateTime.utc(2026, 7, 1),
      );
      await db.transcriptFetchStateDao.upsertFetched(
        'video',
        'v-2',
        DateTime.utc(2026, 7, 1),
      );
      await db.transcriptFetchStateDao.clearForTarget('video', 'v-1');
      expect(
        await db.transcriptFetchStateDao.getForTarget('video', 'v-1'),
        isNull,
      );
      expect(
        await db.transcriptFetchStateDao.getForTarget('video', 'v-2'),
        isNotNull,
      );
    });

    test('clearForTarget is a no-op for unknown target', () async {
      await db.transcriptFetchStateDao.clearForTarget('video', 'v-1');
      expect(
        await db.transcriptFetchStateDao.getForTarget('video', 'v-1'),
        isNull,
      );
    });
  });
}
