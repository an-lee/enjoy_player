// Tests for `lib/data/db/daos/ai_cache_dao.dart` (and the AiCache table
// generated accessors in `app_database.g.dart`).
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

  group('AiCacheDao', () {
    test('read returns null for missing kind/key', () async {
      expect(await db.aiCacheDao.read('dictionary', 'missing'), isNull);
    });

    test('upsert + read round-trip', () async {
      await db.aiCacheDao.upsert(
        'dictionary',
        'hello',
        '{"translation":"hola"}',
        DateTime.utc(2026, 1, 1),
      );
      final row = await db.aiCacheDao.read('dictionary', 'hello');
      expect(row, isNotNull);
      expect(row!.payloadJson, '{"translation":"hola"}');
      expect(row.updatedAt, DateTime.utc(2026, 1, 1).millisecondsSinceEpoch);
    });

    test('upsert replaces existing payload', () async {
      await db.aiCacheDao.upsert(
        'dictionary',
        'hello',
        'v1',
        DateTime.utc(2026, 1, 1),
      );
      await db.aiCacheDao.upsert(
        'dictionary',
        'hello',
        'v2',
        DateTime.utc(2026, 6, 1),
      );
      final row = await db.aiCacheDao.read('dictionary', 'hello');
      expect(row!.payloadJson, 'v2');
      expect(row.updatedAt, DateTime.utc(2026, 6, 1).millisecondsSinceEpoch);
    });

    test('deleteRow removes a single kind/key', () async {
      await db.aiCacheDao.upsert('dictionary', 'a', 'A', DateTime.utc(2026));
      await db.aiCacheDao.upsert('dictionary', 'b', 'B', DateTime.utc(2026));
      await db.aiCacheDao.deleteRow('dictionary', 'a');
      expect(await db.aiCacheDao.read('dictionary', 'a'), isNull);
      expect(await db.aiCacheDao.read('dictionary', 'b'), isNotNull);
    });

    test('deleteRow on missing row is a no-op', () async {
      // Should not throw.
      await db.aiCacheDao.deleteRow('dictionary', 'missing');
    });

    test('deleteForKind removes all rows for a kind', () async {
      await db.aiCacheDao.upsert('dictionary', 'a', 'A', DateTime.utc(2026));
      await db.aiCacheDao.upsert('dictionary', 'b', 'B', DateTime.utc(2026));
      await db.aiCacheDao.upsert('translation', 'c', 'C', DateTime.utc(2026));

      await db.aiCacheDao.deleteForKind('dictionary');
      expect(await db.aiCacheDao.countForKind('dictionary'), 0);
      expect(await db.aiCacheDao.countForKind('translation'), 1);
    });

    test('countForKind counts all rows for that kind', () async {
      await db.aiCacheDao.upsert('dictionary', 'a', 'A', DateTime.utc(2026));
      await db.aiCacheDao.upsert('dictionary', 'b', 'B', DateTime.utc(2026));
      await db.aiCacheDao.upsert('translation', 'c', 'C', DateTime.utc(2026));
      expect(await db.aiCacheDao.countForKind('dictionary'), 2);
      expect(await db.aiCacheDao.countForKind('translation'), 1);
      expect(await db.aiCacheDao.countForKind('missing'), 0);
    });

    test('evictOldestExcept keeps the N most recent entries', () async {
      // Insert 4 entries in a stable order; evictOldestExcept(2) should
      // delete the 2 oldest.
      for (var i = 0; i < 4; i++) {
        await db.aiCacheDao.upsert(
          'dictionary',
          'k$i',
          '{"i":$i}',
          DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
        );
      }
      final removed = await db.aiCacheDao.evictOldestExcept('dictionary', 2);
      expect(removed, 2);
      expect(await db.aiCacheDao.countForKind('dictionary'), 2);
      // The two newest keys (k2, k3) should survive.
      expect(await db.aiCacheDao.read('dictionary', 'k0'), isNull);
      expect(await db.aiCacheDao.read('dictionary', 'k1'), isNull);
      expect(await db.aiCacheDao.read('dictionary', 'k2'), isNotNull);
      expect(await db.aiCacheDao.read('dictionary', 'k3'), isNotNull);
    });

    test('evictOldestExcept is a no-op when total <= keep', () async {
      await db.aiCacheDao.upsert('dictionary', 'a', 'A', DateTime.utc(2026));
      await db.aiCacheDao.upsert('dictionary', 'b', 'B', DateTime.utc(2026));
      expect(await db.aiCacheDao.evictOldestExcept('dictionary', 5), 0);
      expect(await db.aiCacheDao.countForKind('dictionary'), 2);
    });

    test('pruneOlderThan removes only older entries', () async {
      final cutoff = DateTime.utc(2026, 6, 1);
      await db.aiCacheDao.upsert(
        'dictionary',
        'old',
        'O',
        DateTime.utc(2026, 1, 1),
      );
      await db.aiCacheDao.upsert(
        'dictionary',
        'recent',
        'R',
        DateTime.utc(2026, 12, 1),
      );
      final removed = await db.aiCacheDao.pruneOlderThan('dictionary', cutoff);
      expect(removed, 1);
      expect(await db.aiCacheDao.read('dictionary', 'old'), isNull);
      expect(await db.aiCacheDao.read('dictionary', 'recent'), isNotNull);
    });

    test('readAllForKind streams all rows for the kind', () async {
      await db.aiCacheDao.upsert('dictionary', 'a', 'A', DateTime.utc(2026));
      await db.aiCacheDao.upsert('dictionary', 'b', 'B', DateTime.utc(2026));
      await db.aiCacheDao.upsert('translation', 'c', 'C', DateTime.utc(2026));

      final all = await db.aiCacheDao.readAllForKind('dictionary').first;
      expect(all.map((r) => r.key).toSet(), {'a', 'b'});
    });
  });
}
