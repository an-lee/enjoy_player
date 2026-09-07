import 'package:drift/native.dart';
import 'package:enjoy_player/core/cache/lru_store.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/ai/application/ai_kind_policies.dart';
import 'package:enjoy_player/features/ai/application/ai_result_cache.dart';
import 'package:enjoy_player/features/ai/domain/ai_kind.dart';
import 'package:enjoy_player/features/ai/domain/models/contextual_translation_result.dart';
import 'package:enjoy_player/features/ai/domain/models/dictionary_result.dart';
import 'package:enjoy_player/features/ai/domain/models/translation_result.dart';
import 'package:flutter_test/flutter_test.dart';

AiResultCache<String> stringCache({
  required AiCacheDao dao,
  required L1Store<String, String> l1,
  required Map<AiKind, AiKindPolicy> policies,
}) {
  return AiResultCache<String>(
    dao: dao,
    l1: l1,
    policies: policies,
    fromJson: (json) => json['v'] as String,
    toJson: (value) => {'v': value},
  );
}

AiResultCache<String> throwingEncodeCache({
  required AiCacheDao dao,
  required L1Store<String, String> l1,
  required Map<AiKind, AiKindPolicy> policies,
}) {
  return AiResultCache<String>(
    dao: dao,
    l1: l1,
    policies: policies,
    fromJson: (json) => json['v'] as String,
    toJson: (value) => throw StateError('encode failure'),
  );
}

AiResultCache<String> throwingDecodeCache({
  required AiCacheDao dao,
  required L1Store<String, String> l1,
  required Map<AiKind, AiKindPolicy> policies,
}) {
  return AiResultCache<String>(
    dao: dao,
    l1: l1,
    policies: policies,
    fromJson: (json) => throw const FormatException('decode failure'),
    toJson: (value) => {'v': value},
  );
}

void main() {
  group('AiResultCache.peek', () {
    late AppDatabase db;
    late AiResultCache<String> cache;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      cache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(seconds: 30),
        ),
        policies: defaultAiKindPolicies,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('returns null on empty cache', () {
      expect(cache.peek(kind: AiKind.translation, key: 'missing'), isNull);
    });

    test('returns value after remember', () async {
      await cache.remember(kind: AiKind.translation, key: 'k', value: 'val');
      expect(cache.peek(kind: AiKind.translation, key: 'k'), 'val');
    });

    test('returns null after TTL expiry', () async {
      final shortTtl = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(capacity: 8, ttl: Duration.zero),
        policies: defaultAiKindPolicies,
      );
      await shortTtl.remember(kind: AiKind.translation, key: 'k', value: 'val');
      expect(shortTtl.peek(kind: AiKind.translation, key: 'k'), isNull);
    });

    test('returns null after invalidate', () async {
      await cache.remember(kind: AiKind.translation, key: 'k', value: 'val');
      await cache.invalidate(kind: AiKind.translation, key: 'k');
      expect(cache.peek(kind: AiKind.translation, key: 'k'), isNull);
    });
  });

  group('AiResultCache.lookup L1 TTL expiry', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('expired L1 entry falls through to L2', () async {
      final shortTtl = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(capacity: 8, ttl: Duration.zero),
        policies: defaultAiKindPolicies,
      );

      await db.aiCacheDao.upsert(
        'translation',
        'k1',
        '{"v":"from-l2"}',
        DateTime.now(),
      );

      var loaderCalls = 0;
      final result = await shortTtl.lookup(
        kind: AiKind.translation,
        key: 'k1',
        loader: () async {
          loaderCalls++;
          return 'from-loader';
        },
      );

      expect(result, 'from-l2');
      expect(loaderCalls, 0);
    });

    test('expired L1 with no L2 calls loader', () async {
      final shortTtl = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(capacity: 8, ttl: Duration.zero),
        policies: defaultAiKindPolicies,
      );

      var loaderCalls = 0;
      final result = await shortTtl.lookup(
        kind: AiKind.translation,
        key: 'k1',
        loader: () async {
          loaderCalls++;
          return 'from-loader';
        },
      );

      expect(result, 'from-loader');
      expect(loaderCalls, 1);
    });
  });

  group('AiResultCache.lookup L1 LRU eviction', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('LRU-evicted entry falls through to L2', () async {
      final tinyCache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 2,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
      );

      await tinyCache.remember(
        kind: AiKind.translation,
        key: 'k1',
        value: 'v1',
      );
      await tinyCache.remember(
        kind: AiKind.translation,
        key: 'k2',
        value: 'v2',
      );
      // This evicts k1 from L1 (capacity=2).
      await tinyCache.remember(
        kind: AiKind.translation,
        key: 'k3',
        value: 'v3',
      );

      expect(tinyCache.peek(kind: AiKind.translation, key: 'k1'), isNull);

      var loaderCalls = 0;
      final result = await tinyCache.lookup(
        kind: AiKind.translation,
        key: 'k1',
        loader: () async {
          loaderCalls++;
          return 'from-loader';
        },
      );

      expect(result, 'v1');
      expect(loaderCalls, 0, reason: 'L2 should still have the entry');
    });
  });

  group('AiResultCache.lookup L2 decode failure', () {
    late AppDatabase db;
    late AiResultCache<String> cache;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      cache = throwingDecodeCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'valid JSON but fromJson throws evicts L2 row and calls loader',
      () async {
        await db.aiCacheDao.upsert(
          'translation',
          'k1',
          '{"v":"valid-json"}',
          DateTime.now(),
        );

        var loaderCalls = 0;
        final result = await cache.lookup(
          kind: AiKind.translation,
          key: 'k1',
          loader: () async {
            loaderCalls++;
            return 'fallback';
          },
        );

        expect(result, 'fallback');
        expect(loaderCalls, 1);
        final l2Row = await db.aiCacheDao.read('translation', 'k1');
        expect(l2Row, isNotNull);
        expect(l2Row!.payloadJson, '{"v":"fallback"}');
      },
    );
  });

  group('AiResultCache.remember', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('L2 encode failure is swallowed and L1 still written', () async {
      final throwingCache = throwingEncodeCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
      );

      await throwingCache.remember(
        kind: AiKind.translation,
        key: 'k1',
        value: 'val',
      );

      expect(throwingCache.peek(kind: AiKind.translation, key: 'k1'), 'val');
      final l2 = await db.aiCacheDao.read('translation', 'k1');
      expect(l2, isNull);
    });

    test('overwrites existing L1 and L2 entries', () async {
      final cache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
      );

      await cache.remember(kind: AiKind.translation, key: 'k', value: 'old');
      await cache.remember(kind: AiKind.translation, key: 'k', value: 'new');

      expect(cache.peek(kind: AiKind.translation, key: 'k'), 'new');
      final l2 = await db.aiCacheDao.read('translation', 'k');
      expect(l2!.payloadJson, '{"v":"new"}');
    });
  });

  group('AiResultCache.invalidate', () {
    late AppDatabase db;
    late AiResultCache<String> cache;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      cache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('no-op on non-existent key', () async {
      await cache.invalidate(kind: AiKind.translation, key: 'ghost');
      expect(cache.peek(kind: AiKind.translation, key: 'ghost'), isNull);
      expect(await db.aiCacheDao.read('translation', 'ghost'), isNull);
    });

    test('does not affect other keys', () async {
      await cache.remember(kind: AiKind.translation, key: 'a', value: 'va');
      await cache.remember(kind: AiKind.translation, key: 'b', value: 'vb');
      await cache.invalidate(kind: AiKind.translation, key: 'a');

      expect(cache.peek(kind: AiKind.translation, key: 'a'), isNull);
      expect(cache.peek(kind: AiKind.translation, key: 'b'), 'vb');
    });
  });

  group('AiResultCache.evictForPair', () {
    late AppDatabase db;
    late AiResultCache<String> cache;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      cache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('no matching rows is a no-op', () async {
      await db.aiCacheDao.upsert(
        'translation',
        'a',
        '{"v":"x","sourceLanguage":"en","targetLanguage":"es"}',
        DateTime.now(),
      );

      await cache.evictForPair(sourceLanguage: 'fr', targetLanguage: 'de');

      expect(await db.aiCacheDao.read('translation', 'a'), isNotNull);
    });

    test('deletes rows across multiple kinds', () async {
      await db.aiCacheDao.upsert(
        'translation',
        't1',
        '{"v":"t","sourceLanguage":"en","targetLanguage":"ja"}',
        DateTime.now(),
      );
      await db.aiCacheDao.upsert(
        'dictionary',
        'd1',
        '{"v":"d","sourceLanguage":"en","targetLanguage":"ja"}',
        DateTime.now(),
      );
      await db.aiCacheDao.upsert(
        'contextual_translation',
        'c1',
        '{"v":"c","sourceLanguage":"en","targetLanguage":"ja"}',
        DateTime.now(),
      );
      await db.aiCacheDao.upsert(
        'translation',
        't2',
        '{"v":"other","sourceLanguage":"en","targetLanguage":"ko"}',
        DateTime.now(),
      );

      await cache.evictForPair(sourceLanguage: 'en', targetLanguage: 'ja');

      expect(await db.aiCacheDao.read('translation', 't1'), isNull);
      expect(await db.aiCacheDao.read('dictionary', 'd1'), isNull);
      expect(await db.aiCacheDao.read('contextual_translation', 'c1'), isNull);
      expect(await db.aiCacheDao.read('translation', 't2'), isNotNull);
    });

    test('empty database is a no-op', () async {
      await cache.evictForPair(sourceLanguage: 'en', targetLanguage: 'es');
      expect(await db.aiCacheDao.countForKind('translation'), 0);
    });
  });

  group('AiResultCache.clear', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('only clears kinds present in policies map', () async {
      final limitedCache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: {
          AiKind.translation: const AiKindPolicy(
            ttl: Duration(minutes: 30),
            l2RowCap: 100,
            l2AgeCutoff: Duration(days: 7),
          ),
        },
      );

      await db.aiCacheDao.upsert(
        'translation',
        't1',
        '{"v":"t"}',
        DateTime.now(),
      );
      await db.aiCacheDao.upsert(
        'dictionary',
        'd1',
        '{"v":"d"}',
        DateTime.now(),
      );

      await limitedCache.clear();

      expect(await db.aiCacheDao.countForKind('translation'), 0);
      expect(await db.aiCacheDao.countForKind('dictionary'), 1);
    });

    test('clears L1 completely', () async {
      final cache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
      );

      await cache.remember(kind: AiKind.translation, key: 'a', value: 'va');
      await cache.remember(kind: AiKind.dictionary, key: 'b', value: 'vb');
      await cache.remember(
        kind: AiKind.contextualTranslation,
        key: 'c',
        value: 'vc',
      );

      await cache.clear();

      expect(cache.peek(kind: AiKind.translation, key: 'a'), isNull);
      expect(cache.peek(kind: AiKind.dictionary, key: 'b'), isNull);
      expect(cache.peek(kind: AiKind.contextualTranslation, key: 'c'), isNull);
    });
  });

  group('AiResultCache.prune', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('age cutoff removes old rows', () async {
      final cache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: {
          AiKind.translation: const AiKindPolicy(
            ttl: Duration(minutes: 30),
            l2RowCap: 0,
            l2AgeCutoff: Duration(days: 1),
          ),
        },
      );

      final old = DateTime.now().subtract(const Duration(days: 2));
      final recent = DateTime.now();
      await db.aiCacheDao.upsert('translation', 'old', '{"v":"old"}', old);
      await db.aiCacheDao.upsert(
        'translation',
        'recent',
        '{"v":"recent"}',
        recent,
      );

      await cache.prune();

      expect(await db.aiCacheDao.read('translation', 'old'), isNull);
      expect(await db.aiCacheDao.read('translation', 'recent'), isNotNull);
    });

    test('zero row cap skips eviction', () async {
      final cache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: {
          AiKind.translation: const AiKindPolicy(
            ttl: Duration(minutes: 30),
            l2RowCap: 0,
            l2AgeCutoff: Duration.zero,
          ),
        },
      );

      for (var i = 0; i < 20; i++) {
        await db.aiCacheDao.upsert(
          'translation',
          'k$i',
          '{"v":"v$i"}',
          DateTime.now(),
        );
      }

      await cache.prune();

      expect(await db.aiCacheDao.countForKind('translation'), 20);
    });

    test('zero age cutoff skips age pruning', () async {
      final cache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: {
          AiKind.translation: const AiKindPolicy(
            ttl: Duration(minutes: 30),
            l2RowCap: 0,
            l2AgeCutoff: Duration.zero,
          ),
        },
      );

      final veryOld = DateTime.now().subtract(const Duration(days: 365));
      await db.aiCacheDao.upsert(
        'translation',
        'ancient',
        '{"v":"old"}',
        veryOld,
      );

      await cache.prune();

      expect(await db.aiCacheDao.read('translation', 'ancient'), isNotNull);
    });

    test('prunes multiple kinds independently', () async {
      final cache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: {
          AiKind.translation: const AiKindPolicy(
            ttl: Duration(minutes: 30),
            l2RowCap: 2,
            l2AgeCutoff: Duration.zero,
          ),
          AiKind.dictionary: const AiKindPolicy(
            ttl: Duration(minutes: 30),
            l2RowCap: 1,
            l2AgeCutoff: Duration.zero,
          ),
        },
      );

      for (var i = 0; i < 5; i++) {
        await db.aiCacheDao.upsert(
          'translation',
          't$i',
          '{"v":"v$i"}',
          DateTime.now().subtract(Duration(seconds: i)),
        );
        await db.aiCacheDao.upsert(
          'dictionary',
          'd$i',
          '{"v":"v$i"}',
          DateTime.now().subtract(Duration(seconds: i)),
        );
      }

      await cache.prune();

      expect(await db.aiCacheDao.countForKind('translation'), 2);
      expect(await db.aiCacheDao.countForKind('dictionary'), 1);
    });

    test('row cap and age cutoff applied together', () async {
      final cache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: {
          AiKind.translation: const AiKindPolicy(
            ttl: Duration(minutes: 30),
            l2RowCap: 10,
            l2AgeCutoff: Duration(hours: 1),
          ),
        },
      );

      final old = DateTime.now().subtract(const Duration(hours: 2));
      for (var i = 0; i < 3; i++) {
        await db.aiCacheDao.upsert(
          'translation',
          'old$i',
          '{"v":"old$i"}',
          old,
        );
      }
      for (var i = 0; i < 3; i++) {
        await db.aiCacheDao.upsert(
          'translation',
          'new$i',
          '{"v":"new$i"}',
          DateTime.now(),
        );
      }

      await cache.prune();

      expect(await db.aiCacheDao.read('translation', 'old0'), isNull);
      expect(await db.aiCacheDao.read('translation', 'new0'), isNotNull);
      expect(await db.aiCacheDao.countForKind('translation'), 3);
    });
  });

  group('Map-payload cache', () {
    late AppDatabase db;
    late AiResultCache<Map<String, dynamic>> cache;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      cache = AiResultCache<Map<String, dynamic>>(
        dao: db.aiCacheDao,
        l1: L1Store<String, Map<String, dynamic>>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
        fromJson: (json) => json,
        toJson: (value) => value,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('round-trips Map payload through L1 and L2', () async {
      final payload = <String, dynamic>{
        'translatedText': 'hola',
        'sourceLanguage': 'en',
        'targetLanguage': 'es',
        'confidence': 0.95,
      };

      await cache.remember(kind: AiKind.translation, key: 'k1', value: payload);
      expect(cache.peek(kind: AiKind.translation, key: 'k1'), payload);

      final l2 = await db.aiCacheDao.read('translation', 'k1');
      expect(l2, isNotNull);

      final freshCache = AiResultCache<Map<String, dynamic>>(
        dao: db.aiCacheDao,
        l1: L1Store<String, Map<String, dynamic>>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
        fromJson: (json) => json,
        toJson: (value) => value,
      );
      final fromL2 = await freshCache.lookup(
        kind: AiKind.translation,
        key: 'k1',
        loader: () async => throw StateError('should not call'),
      );
      expect(fromL2, payload);
    });

    test('lookup calls loader on miss and caches result', () async {
      final result = await cache.lookup(
        kind: AiKind.dictionary,
        key: 'word',
        loader: () async => {'word': 'hello', 'definition': 'a greeting'},
      );

      expect(result['word'], 'hello');
      expect(cache.peek(kind: AiKind.dictionary, key: 'word'), result);
    });
  });

  group('Translation cache', () {
    late AppDatabase db;
    late AiResultCache<TranslationResult> cache;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      cache = AiResultCache<TranslationResult>(
        dao: db.aiCacheDao,
        l1: L1Store<String, TranslationResult>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
        fromJson: TranslationResult.fromJson,
        toJson: (value) => value.toJson(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('round-trips TranslationResult through L2', () async {
      const original = TranslationResult(
        translatedText: 'bonjour',
        sourceLanguage: 'en',
        targetLanguage: 'fr',
      );

      await cache.remember(
        kind: AiKind.translation,
        key: 'k1',
        value: original,
      );

      final freshCache = AiResultCache<TranslationResult>(
        dao: db.aiCacheDao,
        l1: L1Store<String, TranslationResult>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
        fromJson: TranslationResult.fromJson,
        toJson: (value) => value.toJson(),
      );

      final fromL2 = await freshCache.lookup(
        kind: AiKind.translation,
        key: 'k1',
        loader: () async => throw StateError('should not call'),
      );

      expect(fromL2.translatedText, 'bonjour');
      expect(fromL2.sourceLanguage, 'en');
      expect(fromL2.targetLanguage, 'fr');
    });

    test('peek returns cached TranslationResult', () async {
      const result = TranslationResult(
        translatedText: 'hola',
        targetLanguage: 'es',
      );
      await cache.remember(kind: AiKind.translation, key: 'k', value: result);
      final peeked = cache.peek(kind: AiKind.translation, key: 'k');
      expect(peeked, isNotNull);
      expect(peeked!.translatedText, 'hola');
      expect(peeked.sourceLanguage, isNull);
    });
  });

  group('Dictionary cache', () {
    late AppDatabase db;
    late AiResultCache<DictionaryResult> cache;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      cache = AiResultCache<DictionaryResult>(
        dao: db.aiCacheDao,
        l1: L1Store<String, DictionaryResult>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
        fromJson: DictionaryResult.fromJson,
        toJson: (value) => value.toJson(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('round-trips DictionaryResult through L2', () async {
      const original = DictionaryResult(
        word: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'es',
        lemma: 'hello',
        ipa: '/həˈloʊ/',
        senses: [
          DictionarySense(
            definition: 'a greeting',
            translation: 'hola',
            partOfSpeech: 'noun',
            examples: [DictionaryExample(source: 'Hello!', target: '¡Hola!')],
          ),
        ],
      );

      await cache.remember(
        kind: AiKind.dictionary,
        key: 'hello',
        value: original,
      );

      final freshCache = AiResultCache<DictionaryResult>(
        dao: db.aiCacheDao,
        l1: L1Store<String, DictionaryResult>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
        fromJson: DictionaryResult.fromJson,
        toJson: (value) => value.toJson(),
      );

      final fromL2 = await freshCache.lookup(
        kind: AiKind.dictionary,
        key: 'hello',
        loader: () async => throw StateError('should not call'),
      );

      expect(fromL2.word, 'hello');
      expect(fromL2.ipa, '/həˈloʊ/');
      expect(fromL2.senses, hasLength(1));
      expect(fromL2.senses.first.translation, 'hola');
      expect(fromL2.senses.first.examples, hasLength(1));
      expect(fromL2.senses.first.examples!.first.target, '¡Hola!');
    });

    test('lookup caches loader result', () async {
      var loaderCalls = 0;
      final result = await cache.lookup(
        kind: AiKind.dictionary,
        key: 'world',
        loader: () async {
          loaderCalls++;
          return const DictionaryResult(
            word: 'world',
            sourceLanguage: 'en',
            targetLanguage: 'fr',
            senses: [DictionarySense(definition: 'the earth')],
          );
        },
      );

      expect(result.word, 'world');
      expect(loaderCalls, 1);

      final second = await cache.lookup(
        kind: AiKind.dictionary,
        key: 'world',
        loader: () async {
          loaderCalls++;
          throw StateError('should not call');
        },
      );
      expect(second.word, 'world');
      expect(loaderCalls, 1);
    });
  });

  group('Contextual translation cache', () {
    late AppDatabase db;
    late AiResultCache<ContextualTranslationResult> cache;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      cache = AiResultCache<ContextualTranslationResult>(
        dao: db.aiCacheDao,
        l1: L1Store<String, ContextualTranslationResult>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
        fromJson: ContextualTranslationResult.fromJson,
        toJson: (value) => value.toJson(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('round-trips ContextualTranslationResult through L2', () async {
      const original = ContextualTranslationResult(
        translatedText: 'The cat sat on the mat (contextual).',
      );

      await cache.remember(
        kind: AiKind.contextualTranslation,
        key: 'ctx1',
        value: original,
      );

      final freshCache = AiResultCache<ContextualTranslationResult>(
        dao: db.aiCacheDao,
        l1: L1Store<String, ContextualTranslationResult>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
        fromJson: ContextualTranslationResult.fromJson,
        toJson: (value) => value.toJson(),
      );

      final fromL2 = await freshCache.lookup(
        kind: AiKind.contextualTranslation,
        key: 'ctx1',
        loader: () async => throw StateError('should not call'),
      );

      expect(fromL2.translatedText, 'The cat sat on the mat (contextual).');
    });

    test('forceRefresh bypasses cached ContextualTranslationResult', () async {
      const first = ContextualTranslationResult(translatedText: 'first');
      const second = ContextualTranslationResult(translatedText: 'second');

      await cache.remember(
        kind: AiKind.contextualTranslation,
        key: 'ctx',
        value: first,
      );

      final result = await cache.lookup(
        kind: AiKind.contextualTranslation,
        key: 'ctx',
        forceRefresh: true,
        loader: () async => second,
      );

      expect(result.translatedText, 'second');
      expect(
        cache
            .peek(kind: AiKind.contextualTranslation, key: 'ctx')!
            .translatedText,
        'second',
      );
    });
  });

  group('AiResultCache.lookup forceRefresh edge cases', () {
    late AppDatabase db;
    late AiResultCache<String> cache;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      cache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('forceRefresh on empty cache still calls loader', () async {
      var loaderCalls = 0;
      final result = await cache.lookup(
        kind: AiKind.translation,
        key: 'fresh',
        forceRefresh: true,
        loader: () async {
          loaderCalls++;
          return 'loaded';
        },
      );

      expect(result, 'loaded');
      expect(loaderCalls, 1);
    });

    test('forceRefresh removes L2-only entry before loading', () async {
      await db.aiCacheDao.upsert(
        'translation',
        'k1',
        '{"v":"stale"}',
        DateTime.now(),
      );

      final result = await cache.lookup(
        kind: AiKind.translation,
        key: 'k1',
        forceRefresh: true,
        loader: () async => 'fresh',
      );

      expect(result, 'fresh');
      final l2 = await db.aiCacheDao.read('translation', 'k1');
      expect(l2!.payloadJson, '{"v":"fresh"}');
    });
  });

  group('AiResultCache cross-kind isolation', () {
    late AppDatabase db;
    late AiResultCache<String> cache;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      cache = stringCache(
        dao: db.aiCacheDao,
        l1: L1Store<String, String>(
          capacity: 8,
          ttl: const Duration(minutes: 5),
        ),
        policies: defaultAiKindPolicies,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('invalidate for one kind does not affect another', () async {
      await cache.remember(
        kind: AiKind.translation,
        key: 'shared',
        value: 't-val',
      );
      await cache.remember(
        kind: AiKind.dictionary,
        key: 'shared',
        value: 'd-val',
      );

      await cache.invalidate(kind: AiKind.translation, key: 'shared');

      expect(cache.peek(kind: AiKind.translation, key: 'shared'), isNull);
      expect(cache.peek(kind: AiKind.dictionary, key: 'shared'), 'd-val');
    });

    test('all four kinds coexist with same key', () async {
      for (final kind in AiKind.values) {
        await cache.remember(kind: kind, key: 'same', value: kind.wire);
      }

      for (final kind in AiKind.values) {
        expect(cache.peek(kind: kind, key: 'same'), kind.wire);
      }
    });
  });
}
