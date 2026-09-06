import 'package:drift/native.dart';
import 'package:enjoy_player/core/cache/lru_store.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/ai/application/ai_kind_policies.dart';
import 'package:enjoy_player/features/ai/application/ai_result_cache.dart';
import 'package:enjoy_player/features/ai/domain/ai_kind.dart';
import 'package:flutter_test/flutter_test.dart';

AiResultCache<String> _stringCache(AppDatabase db) {
  return AiResultCache<String>(
    dao: db.aiCacheDao,
    l1: L1Store<String, String>(capacity: 8, ttl: const Duration(seconds: 1)),
    policies: defaultAiKindPolicies,
    fromJson: (json) => json['v'] as String,
    toJson: (value) => {'v': value},
  );
}

void main() {
  group('AiResultCache', () {
    late AppDatabase db;
    late AiResultCache<String> cache;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      cache = _stringCache(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('lookup writes L1 and L2 on miss', () async {
      var loaderCalls = 0;
      Future<String> loader() async {
        loaderCalls += 1;
        return 'result-A';
      }

      final result = await cache.lookup(
        kind: AiKind.translation,
        key: 'k1',
        loader: loader,
      );

      expect(result, 'result-A');
      expect(loaderCalls, 1);
      expect(cache.peek(kind: AiKind.translation, key: 'k1'), 'result-A');

      final l2 = await db.aiCacheDao.read('translation', 'k1');
      expect(l2, isNotNull);
      expect(l2!.payloadJson, '{"v":"result-A"}');
    });

    test('L1 hit skips loader on second lookup', () async {
      var loaderCalls = 0;
      Future<String> loader() async {
        loaderCalls += 1;
        return 'result-A';
      }

      await cache.lookup(kind: AiKind.translation, key: 'k1', loader: loader);
      final second = await cache.lookup(
        kind: AiKind.translation,
        key: 'k1',
        loader: loader,
      );
      expect(second, 'result-A');
      expect(loaderCalls, 1, reason: 'L1 should short-circuit the loader');
    });

    test('L2 hit returns persisted and backfills L1', () async {
      // Seed L2 directly.
      await db.aiCacheDao.upsert(
        'translation',
        'k1',
        '{"v":"persisted"}',
        DateTime.now(),
      );

      var loaderCalls = 0;
      Future<String> loader() async {
        loaderCalls += 1;
        return 'should-not-be-called';
      }

      final result = await cache.lookup(
        kind: AiKind.translation,
        key: 'k1',
        loader: loader,
      );
      expect(result, 'persisted');
      expect(loaderCalls, 0);
      // L1 should now have it.
      expect(cache.peek(kind: AiKind.translation, key: 'k1'), 'persisted');
    });

    test('forceRefresh busts both tiers', () async {
      var loaderCalls = 0;
      Future<String> loader() async {
        loaderCalls += 1;
        return 'fresh-$loaderCalls';
      }

      await cache.lookup(kind: AiKind.translation, key: 'k1', loader: loader);
      // L1 has 'fresh-1', L2 has 'fresh-1'.
      final second = await cache.lookup(
        kind: AiKind.translation,
        key: 'k1',
        loader: loader,
        forceRefresh: true,
      );
      expect(second, 'fresh-2');
      expect(loaderCalls, 2);
    });

    test('forceRefresh propagates loader error and does not cache', () async {
      Future<String> loader() async {
        throw StateError('boom');
      }

      await expectLater(
        () => cache.lookup(
          kind: AiKind.translation,
          key: 'k1',
          loader: loader,
          forceRefresh: true,
        ),
        throwsA(isA<StateError>()),
      );
      // Nothing should be cached.
      expect(cache.peek(kind: AiKind.translation, key: 'k1'), isNull);
      final l2 = await db.aiCacheDao.read('translation', 'k1');
      expect(l2, isNull);
    });

    test('loader error on miss does not poison cache', () async {
      Future<String> loader() async {
        throw StateError('boom');
      }

      await expectLater(
        () => cache.lookup(kind: AiKind.translation, key: 'k1', loader: loader),
        throwsA(isA<StateError>()),
      );
      expect(cache.peek(kind: AiKind.translation, key: 'k1'), isNull);
      final l2 = await db.aiCacheDao.read('translation', 'k1');
      expect(l2, isNull);
    });

    test('invalidate removes from both tiers', () async {
      await cache.remember(kind: AiKind.translation, key: 'k1', value: 'v');
      expect(cache.peek(kind: AiKind.translation, key: 'k1'), 'v');
      expect((await db.aiCacheDao.read('translation', 'k1')), isNotNull);

      await cache.invalidate(kind: AiKind.translation, key: 'k1');
      expect(cache.peek(kind: AiKind.translation, key: 'k1'), isNull);
      expect((await db.aiCacheDao.read('translation', 'k1')), isNull);
    });

    test('kinds do not collide', () async {
      // Same key for two kinds must produce independent entries.
      await cache.remember(
        kind: AiKind.translation,
        key: 'same',
        value: 'translation-value',
      );
      await cache.remember(
        kind: AiKind.dictionary,
        key: 'same',
        value: 'dictionary-value',
      );

      expect(
        cache.peek(kind: AiKind.translation, key: 'same'),
        'translation-value',
      );
      expect(
        cache.peek(kind: AiKind.dictionary, key: 'same'),
        'dictionary-value',
      );

      final tRow = await db.aiCacheDao.read('translation', 'same');
      final dRow = await db.aiCacheDao.read('dictionary', 'same');
      expect(tRow!.payloadJson, '{"v":"translation-value"}');
      expect(dRow!.payloadJson, '{"v":"dictionary-value"}');
    });

    test('evictForPair clears L2 rows for the pair', () async {
      await db.aiCacheDao.upsert(
        'translation',
        'a',
        '{"v":"a-val","sourceLanguage":"en","targetLanguage":"es"}',
        DateTime.now(),
      );
      await db.aiCacheDao.upsert(
        'translation',
        'b',
        '{"v":"b-val","sourceLanguage":"en","targetLanguage":"fr"}',
        DateTime.now(),
      );
      await db.aiCacheDao.upsert(
        'dictionary',
        'c',
        '{"v":"c-val","sourceLanguage":"en","targetLanguage":"es"}',
        DateTime.now(),
      );

      await cache.evictForPair(sourceLanguage: 'en', targetLanguage: 'es');

      expect(await db.aiCacheDao.read('translation', 'a'), isNull);
      expect(await db.aiCacheDao.read('translation', 'b'), isNotNull);
      expect(await db.aiCacheDao.read('dictionary', 'c'), isNull);
    });

    test('clear drops both tiers', () async {
      await cache.remember(kind: AiKind.translation, key: 'k1', value: 'v');
      await cache.remember(kind: AiKind.dictionary, key: 'k2', value: 'v');
      await cache.clear();
      expect(cache.peek(kind: AiKind.translation, key: 'k1'), isNull);
      expect(cache.peek(kind: AiKind.dictionary, key: 'k2'), isNull);
      expect(await db.aiCacheDao.countForKind('translation'), 0);
      expect(await db.aiCacheDao.countForKind('dictionary'), 0);
    });

    test('prune applies per-kind caps', () async {
      // Bypass the cache and seed L2 directly so we can hit the cap.
      for (var i = 0; i < 50; i++) {
        await db.aiCacheDao.upsert(
          'translation',
          'k$i',
          '{"v":"v$i"}',
          DateTime.now().subtract(Duration(seconds: i)),
        );
      }
      final before = await db.aiCacheDao.countForKind('translation');
      expect(before, 50);

      // Translation's default cap is 4096; that's higher than 50, so prune
      // should be a no-op here. To exercise the eviction path, lower the
      // cap by constructing a custom policies map.
      final tightCache = AiResultCache<String>(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 4,
          ttl: const Duration(seconds: 1),
        ),
        policies: {
          AiKind.translation: const AiKindPolicy(
            ttl: Duration(minutes: 30),
            l2RowCap: 5,
            l2AgeCutoff: Duration(days: 30),
          ),
        },
        fromJson: (json) => json['v'] as String,
        toJson: (value) => {'v': value},
      );
      await tightCache.prune();
      final after = await db.aiCacheDao.countForKind('translation');
      expect(after, 5);
    });

    test('L2 I/O failure degrades gracefully on lookup', () async {
      // Seed a row with invalid JSON in L2.
      await db.aiCacheDao.upsert(
        'translation',
        'k1',
        'not-valid-json',
        DateTime.now(),
      );

      var loaderCalls = 0;
      Future<String> loader() async {
        loaderCalls += 1;
        return 'fallback';
      }

      final result = await cache.lookup(
        kind: AiKind.translation,
        key: 'k1',
        loader: loader,
      );
      // Cache should treat invalid JSON as a miss and call the loader.
      expect(result, 'fallback');
      expect(loaderCalls, 1);
    });
  });
}
