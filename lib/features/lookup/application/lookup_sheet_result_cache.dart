/// Per-pair eviction helper for the lookup sheet's three AI sections.
///
/// The actual cache hierarchy lives in `AiResultCache` (see issue #311);
/// this helper fans the eviction out to the translation / dictionary /
/// contextual-translation caches so stale results from a prior
/// `(sourceLanguage, targetLanguage)` pair cannot be observed against the
/// new pair's loading skeletons.
library;

import 'package:enjoy_player/features/ai/application/ai_result_cache.dart';
import 'package:enjoy_player/features/ai/domain/models/contextual_translation_result.dart';
import 'package:enjoy_player/features/ai/domain/models/dictionary_result.dart';
import 'package:enjoy_player/features/ai/domain/models/translation_result.dart';

/// Removes every cached entry whose payload matches the given pair.
Future<void> evictLookupCaches({
  required AiResultCache<TranslationResult> translation,
  required AiResultCache<DictionaryResult> dictionary,
  required AiResultCache<ContextualTranslationResult> contextual,
  required String sourceLanguage,
  required String targetLanguage,
}) async {
  await translation.evictForPair(
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
  );
  await dictionary.evictForPair(
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
  );
  await contextual.evictForPair(
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
  );
}
