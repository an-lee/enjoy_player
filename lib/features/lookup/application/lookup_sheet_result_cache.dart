/// Per-pair eviction helper for the lookup sheet's three AI sections.
///
/// The actual cache hierarchy lives in `AiResultCache` (see issue #311);
/// this class keeps the historical `evictForPair` API for callers that
/// need to clear every entry for a `(sourceLanguage, targetLanguage)` pair
/// on source / target swap.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/features/ai/application/ai_result_cache.dart';
import 'package:enjoy_player/features/ai/domain/models/contextual_translation_result.dart';
import 'package:enjoy_player/features/ai/domain/models/dictionary_result.dart';
import 'package:enjoy_player/features/ai/domain/models/translation_result.dart';

part 'lookup_sheet_result_cache.g.dart';

final class LookupSheetResultCache {
  LookupSheetResultCache(
    this._translationCache,
    this._dictionaryCache,
    this._contextualCache,
  );

  final AiResultCache<TranslationResult> _translationCache;
  final AiResultCache<DictionaryResult> _dictionaryCache;
  final AiResultCache<ContextualTranslationResult> _contextualCache;

  /// Removes every cached entry whose payload matches the given pair.
  ///
  /// Called on source / target change so stale results from the prior
  /// pair cannot be observed against the new pair's loading skeletons.
  Future<void> evictForPair({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    await _translationCache.evictForPair(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    await _dictionaryCache.evictForPair(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    await _contextualCache.evictForPair(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }

  /// Drops every cached entry for the three lookup-sheet modalities.
  Future<void> clear() async {
    await _translationCache.clear();
    await _dictionaryCache.clear();
    await _contextualCache.clear();
  }
}

@Riverpod(keepAlive: true)
LookupSheetResultCache lookupSheetResultCache(Ref ref) =>
    LookupSheetResultCache(
      ref.watch(aiTranslationCacheProvider),
      ref.watch(aiDictionaryCacheProvider),
      ref.watch(aiContextualTranslationCacheProvider),
    );
