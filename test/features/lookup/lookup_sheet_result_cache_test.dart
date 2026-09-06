import 'package:drift/native.dart';
import 'package:enjoy_player/core/cache/lru_store.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/ai/application/ai_kind_policies.dart';
import 'package:enjoy_player/features/ai/application/ai_result_cache.dart';
import 'package:enjoy_player/features/ai/domain/ai_kind.dart';
import 'package:flutter_test/flutter_test.dart';

AiResultCache<String> _stringCache(
  AppDatabase db,
  L1Store<String, String> l1,
  Map<AiKind, AiKindPolicy> policies,
) {
  return AiResultCache<String>(
    dao: db.aiCacheDao,
    l1: l1,
    policies: policies,
    fromJson: (json) => json['v'] as String,
    toJson: (value) => {'v': value},
  );
}

void main() {
  group('AiResultCache evictForPair', () {
    late AppDatabase db;
    late AiResultCache<String> translationCache;
    late AiResultCache<String> dictCache;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());

      // Use custom payloads to include sourceLanguage/targetLanguage so the
      // LIKE scan finds them. Our _StringCache encodes values as {"v":"..."}
      // so we use remember to store entries. For the scan to work, we need
      // the encoded JSON to contain sourceLanguage/targetLanguage. We do
      // writes through DAO directly for the scan case, and via the cache for
      // the normal case.
      translationCache = _stringCache(
        db,
        L1Store<String, String>(capacity: 8, ttl: const Duration(seconds: 1)),
        {
          AiKind.translation: const AiKindPolicy(
            ttl: Duration(minutes: 30),
            l2RowCap: 4096,
            l2AgeCutoff: Duration(days: 30),
          ),
        },
      );
      dictCache = _stringCache(
        db,
        L1Store<String, String>(capacity: 8, ttl: const Duration(seconds: 1)),
        {
          AiKind.dictionary: const AiKindPolicy(
            ttl: Duration(minutes: 30),
            l2RowCap: 4096,
            l2AgeCutoff: Duration(days: 30),
          ),
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('clears L2 entries matching (sourceLanguage, targetLanguage)', () async {
      const pairA = ('ko-KR', 'ja-JP');

      // Seed L2 directly with payloads that contain sourceLanguage/targetLanguage.
      await db.aiCacheDao.upsert(
        'translation',
        'a',
        '{"v":"a","sourceLanguage":"ko-KR","targetLanguage":"ja-JP"}',
        DateTime.now(),
      );
      await db.aiCacheDao.upsert(
        'translation',
        'b',
        '{"v":"b","sourceLanguage":"ko-KR","targetLanguage":"es-ES"}',
        DateTime.now(),
      );
      await db.aiCacheDao.upsert(
        'translation',
        'c',
        '{"v":"c","sourceLanguage":"ja-JP","targetLanguage":"ko-KR"}',
        DateTime.now(),
      );
      await db.aiCacheDao.upsert(
        'dictionary',
        'a',
        '{"v":"a","sourceLanguage":"ko-KR","targetLanguage":"ja-JP"}',
        DateTime.now(),
      );
      await db.aiCacheDao.upsert(
        'dictionary',
        'b',
        '{"v":"b","sourceLanguage":"ko-KR","targetLanguage":"es-ES"}',
        DateTime.now(),
      );
      await db.aiCacheDao.upsert(
        'dictionary',
        'c',
        '{"v":"c","sourceLanguage":"ja-JP","targetLanguage":"ko-KR"}',
        DateTime.now(),
      );

      // Evict pair A.
      await translationCache.evictForPair(
        sourceLanguage: pairA.$1,
        targetLanguage: pairA.$2,
      );
      await dictCache.evictForPair(
        sourceLanguage: pairA.$1,
        targetLanguage: pairA.$2,
      );

      // Pair A entries should be gone.
      expect(await db.aiCacheDao.read('translation', 'a'), isNull);
      expect(await db.aiCacheDao.read('dictionary', 'a'), isNull);

      // Pair B and C should survive.
      expect(await db.aiCacheDao.read('translation', 'b'), isNotNull);
      expect(await db.aiCacheDao.read('translation', 'c'), isNotNull);
      expect(await db.aiCacheDao.read('dictionary', 'b'), isNotNull);
      expect(await db.aiCacheDao.read('dictionary', 'c'), isNotNull);
    });

    test('is a no-op when no entries match', () async {
      await db.aiCacheDao.upsert(
        'translation',
        'unique',
        '{"v":"unique","sourceLanguage":"ko-KR","targetLanguage":"ja-JP"}',
        DateTime.now(),
      );

      await translationCache.evictForPair(
        sourceLanguage: 'ko-KR',
        targetLanguage: 'es-ES',
      );

      // The existing entry should survive.
      expect(await db.aiCacheDao.read('translation', 'unique'), isNotNull);
    });
  });
}
