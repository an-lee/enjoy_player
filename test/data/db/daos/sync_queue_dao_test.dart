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

  group('SyncQueueDao', () {
    test('enqueue inserts a new row', () async {
      final id = await db.syncQueueDao.enqueue(
        entityType: 'audio',
        entityId: 'a-1',
        action: 'upsert',
      );
      expect(id, greaterThan(0));
      final batch = await db.syncQueueDao.peekBatch();
      expect(batch, hasLength(1));
      expect(batch.single.entityType, 'audio');
      expect(batch.single.entityId, 'a-1');
      expect(batch.single.action, 'upsert');
      expect(batch.single.payloadJson, isNull);
      expect(batch.single.retryCount, 0);
      expect(batch.single.error, isNull);
      expect(batch.single.lastAttempt, isNull);
    });

    test('enqueue accepts payloadJson', () async {
      await db.syncQueueDao.enqueue(
        entityType: 'audio',
        entityId: 'a-1',
        action: 'upsert',
        payloadJson: '{"foo":1}',
      );
      final batch = await db.syncQueueDao.peekBatch();
      expect(batch.single.payloadJson, '{"foo":1}');
    });

    test('peekBatch orders by createdAt ascending', () async {
      await db.syncQueueDao.enqueue(
        entityType: 'a',
        entityId: '1',
        action: 'upsert',
      );
      await db.syncQueueDao.enqueue(
        entityType: 'b',
        entityId: '2',
        action: 'upsert',
      );
      final batch = await db.syncQueueDao.peekBatch();
      expect(batch.map((r) => r.entityType), ['a', 'b']);
    });

    test('peekBatch honors limit parameter', () async {
      for (var i = 0; i < 5; i++) {
        await db.syncQueueDao.enqueue(
          entityType: 'a',
          entityId: '$i',
          action: 'upsert',
        );
      }
      final batch = await db.syncQueueDao.peekBatch(limit: 3);
      expect(batch, hasLength(3));
    });

    test(
      'markAttempted increments retryCount and sets lastAttempt + error',
      () async {
        final id = await db.syncQueueDao.enqueue(
          entityType: 'a',
          entityId: '1',
          action: 'upsert',
        );
        await db.syncQueueDao.markAttempted(id, error: 'boom');
        final batch = await db.syncQueueDao.peekBatch();
        expect(batch.single.retryCount, 1);
        expect(batch.single.error, 'boom');
        expect(batch.single.lastAttempt, isNotNull);
      },
    );

    test('markAttempted on missing id is a no-op', () async {
      await db.syncQueueDao.markAttempted(99999, error: 'x');
      expect(await db.syncQueueDao.peekBatch(), isEmpty);
    });

    test('markPermanentlyFailed sets retryCount to 5', () async {
      final id = await db.syncQueueDao.enqueue(
        entityType: 'a',
        entityId: '1',
        action: 'upsert',
      );
      await db.syncQueueDao.markPermanentlyFailed(id, error: 'fatal');
      final batch = await db.syncQueueDao.peekBatch();
      expect(batch.single.retryCount, 5);
      expect(batch.single.error, 'fatal');
    });

    test('markPermanentlyFailed on missing id is a no-op', () async {
      await db.syncQueueDao.markPermanentlyFailed(99999);
      expect(await db.syncQueueDao.peekBatch(), isEmpty);
    });

    test('deleteId removes the row', () async {
      final id = await db.syncQueueDao.enqueue(
        entityType: 'a',
        entityId: '1',
        action: 'upsert',
      );
      await db.syncQueueDao.enqueue(
        entityType: 'b',
        entityId: '2',
        action: 'upsert',
      );
      await db.syncQueueDao.deleteId(id);
      final batch = await db.syncQueueDao.peekBatch();
      expect(batch.map((r) => r.entityType), ['b']);
    });
  });
}
