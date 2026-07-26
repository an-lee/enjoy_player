// Tests for the Riverpod families in `lookup_section_providers.dart`.
//
// The providers wrap the typed `AiTranslationCache` / `AiDictionaryCache`
// and the `TranslationService` / `DictionaryService` collaborators. We
// exercise them end-to-end through `ProviderContainer.read` to confirm
// the fingerprint, L1/L2 lookup path, and force-refresh behavior.
import 'package:drift/native.dart';
import 'package:enjoy_player/core/cache/lru_store.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/ai/application/ai_capability_providers.dart';
import 'package:enjoy_player/features/ai/application/ai_kind_policies.dart';
import 'package:enjoy_player/features/ai/application/ai_result_cache.dart';
import 'package:enjoy_player/features/ai/domain/ai_kind.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/dictionary_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/translation_capability.dart';
import 'package:enjoy_player/features/ai/domain/models/dictionary_result.dart';
import 'package:enjoy_player/features/ai/domain/models/translation_result.dart';
import 'package:enjoy_player/features/lookup/application/lookup_section_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeTranslationCapability implements TranslationCapability {
  _FakeTranslationCapability(this._result);
  final TranslationResult _result;
  int calls = 0;
  String? lastText;
  String? lastSource;
  String? lastTarget;
  bool? lastForceRefresh;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    bool? forceRefresh,
  }) async {
    calls++;
    lastText = text;
    lastSource = sourceLanguage;
    lastTarget = targetLanguage;
    lastForceRefresh = forceRefresh;
    return _result;
  }
}

final class _FakeDictionaryCapability implements DictionaryCapability {
  _FakeDictionaryCapability(this._result);
  final DictionaryResult _result;
  int calls = 0;
  String? lastWord;
  String? lastSource;
  String? lastTarget;
  bool? lastForceRefresh;

  @override
  Future<DictionaryResult> lookupDictionary({
    required String word,
    required String sourceLanguage,
    required String targetLanguage,
    bool? forceRefresh,
  }) async {
    calls++;
    lastWord = word;
    lastSource = sourceLanguage;
    lastTarget = targetLanguage;
    lastForceRefresh = forceRefresh;
    return _result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AiTranslationCache translationCache;
  late AiDictionaryCache dictionaryCache;
  late _FakeTranslationCapability translationCap;
  late _FakeDictionaryCapability dictionaryCap;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    translationCache = AiTranslationCache(
      dao: db.aiCacheDao,
      l1: L1Store<String, TranslationResult>(
        capacity: 8,
        ttl: const Duration(minutes: 30),
      ),
      policies: defaultAiKindPolicies,
    );
    dictionaryCache = AiDictionaryCache(
      dao: db.aiCacheDao,
      l1: L1Store<String, DictionaryResult>(
        capacity: 8,
        ttl: const Duration(minutes: 30),
      ),
      policies: defaultAiKindPolicies,
    );
    translationCap = _FakeTranslationCapability(
      const TranslationResult(translatedText: 'hello', targetLanguage: 'zh'),
    );
    dictionaryCap = _FakeDictionaryCapability(
      const DictionaryResult(
        word: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        senses: <DictionarySense>[],
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        aiTranslationCacheProvider.overrideWithValue(translationCache),
        aiDictionaryCacheProvider.overrideWithValue(dictionaryCache),
        translationCapabilityProvider.overrideWithValue(translationCap),
        dictionaryCapabilityProvider.overrideWithValue(dictionaryCap),
      ],
    );
  }

  test(
    'lookupSheetTranslationProvider calls capability and caches the result',
    () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      const params = LookupTranslationParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );

      final result = await container.read(
        lookupSheetTranslationProvider(params).future,
      );
      expect(result.translatedText, 'hello');
      expect(result.targetLanguage, 'zh');
      expect(translationCap.calls, 1);
      expect(translationCap.lastText, 'hello');
      expect(translationCap.lastSource, 'en');
      expect(translationCap.lastTarget, 'zh');

      // Second read: cached, no extra capability call.
      final again = await container.read(
        lookupSheetTranslationProvider(params).future,
      );
      expect(again.translatedText, 'hello');
      expect(translationCap.calls, 1);
    },
  );

  test(
    'lookupSheetTranslationProvider forceRefresh re-invokes capability (separate provider)',
    () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      const params = LookupTranslationParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );

      final first = await container.read(
        lookupSheetTranslationProvider(params).future,
      );
      expect(first.translatedText, 'hello');
      expect(translationCap.calls, 1);

      // forceRefresh creates a distinct provider instance because the
      // generated family key includes the named `forceRefresh` arg.
      final refreshed = await container.read(
        lookupSheetTranslationProvider(params, forceRefresh: true).future,
      );
      expect(refreshed.translatedText, 'hello');
      expect(translationCap.calls, 2);
    },
  );

  test(
    'lookupSheetDictionaryProvider calls capability and caches the result',
    () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      const params = LookupDictionaryParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );

      final result = await container.read(
        lookupSheetDictionaryProvider(params).future,
      );
      expect(result.word, 'hello');
      expect(result.targetLanguage, 'zh');
      expect(dictionaryCap.calls, 1);
      expect(dictionaryCap.lastWord, 'hello');

      final again = await container.read(
        lookupSheetDictionaryProvider(params).future,
      );
      expect(again.word, 'hello');
      expect(dictionaryCap.calls, 1);
    },
  );

  test(
    'lookupSheetDictionaryProvider forceRefresh re-invokes capability (separate provider)',
    () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      const params = LookupDictionaryParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );

      final first = await container.read(
        lookupSheetDictionaryProvider(params).future,
      );
      expect(first.word, 'hello');
      expect(dictionaryCap.calls, 1);

      // See note in translation test: forceRefresh is part of the family key.
      final refreshed = await container.read(
        lookupSheetDictionaryProvider(params, forceRefresh: true).future,
      );
      expect(refreshed.word, 'hello');
      expect(dictionaryCap.calls, 2);
    },
  );

  test(
    'different params produce different cache keys (separate calls)',
    () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      const a = LookupTranslationParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      const b = LookupTranslationParams(
        text: 'world',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );

      final r1 = await container.read(lookupSheetTranslationProvider(a).future);
      await container.read(lookupSheetTranslationProvider(b).future);
      expect(translationCap.calls, 2);
      expect(translationCap.lastText, 'world');
      expect(r1.translatedText, 'hello');
    },
  );

  test('AiKind wiring uses translation / dictionary wire names', () {
    expect(AiKind.translation.wire, 'translation');
    expect(AiKind.dictionary.wire, 'dictionary');
  });
}
