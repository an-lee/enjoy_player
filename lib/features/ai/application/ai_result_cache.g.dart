// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_result_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Coalesces the startup prune pass for all AI cache kinds (issue #478).
///
/// Previously each of the cache providers called `unawaited(cache.prune())`
/// at construction — N × len(policies) × 2 SQL ops against the same
/// `ai_cache` table racing on the same Drift executor. This provider runs
/// the prune once per database instance; each cache provider watches it to
/// ensure it has fired before the cache is used.

@ProviderFor(aiCacheStartupPrune)
final aiCacheStartupPruneProvider = AiCacheStartupPruneProvider._();

/// Coalesces the startup prune pass for all AI cache kinds (issue #478).
///
/// Previously each of the cache providers called `unawaited(cache.prune())`
/// at construction — N × len(policies) × 2 SQL ops against the same
/// `ai_cache` table racing on the same Drift executor. This provider runs
/// the prune once per database instance; each cache provider watches it to
/// ensure it has fired before the cache is used.

final class AiCacheStartupPruneProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Coalesces the startup prune pass for all AI cache kinds (issue #478).
  ///
  /// Previously each of the cache providers called `unawaited(cache.prune())`
  /// at construction — N × len(policies) × 2 SQL ops against the same
  /// `ai_cache` table racing on the same Drift executor. This provider runs
  /// the prune once per database instance; each cache provider watches it to
  /// ensure it has fired before the cache is used.
  AiCacheStartupPruneProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiCacheStartupPruneProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiCacheStartupPruneHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return aiCacheStartupPrune(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$aiCacheStartupPruneHash() =>
    r'5811f5235124494ebaf5495fc005e3c96f40199a';

/// Per-user typed `TranslationResult` cache.

@ProviderFor(aiTranslationCache)
final aiTranslationCacheProvider = AiTranslationCacheProvider._();

/// Per-user typed `TranslationResult` cache.

final class AiTranslationCacheProvider
    extends
        $FunctionalProvider<
          AiResultCache<TranslationResult>,
          AiResultCache<TranslationResult>,
          AiResultCache<TranslationResult>
        >
    with $Provider<AiResultCache<TranslationResult>> {
  /// Per-user typed `TranslationResult` cache.
  AiTranslationCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiTranslationCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiTranslationCacheHash();

  @$internal
  @override
  $ProviderElement<AiResultCache<TranslationResult>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiResultCache<TranslationResult> create(Ref ref) {
    return aiTranslationCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiResultCache<TranslationResult> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiResultCache<TranslationResult>>(
        value,
      ),
    );
  }
}

String _$aiTranslationCacheHash() =>
    r'4d083bac9eeb817b17cba5ac2c39fa58c0c4bd47';

/// Per-user typed `DictionaryResult` cache.

@ProviderFor(aiDictionaryCache)
final aiDictionaryCacheProvider = AiDictionaryCacheProvider._();

/// Per-user typed `DictionaryResult` cache.

final class AiDictionaryCacheProvider
    extends
        $FunctionalProvider<
          AiResultCache<DictionaryResult>,
          AiResultCache<DictionaryResult>,
          AiResultCache<DictionaryResult>
        >
    with $Provider<AiResultCache<DictionaryResult>> {
  /// Per-user typed `DictionaryResult` cache.
  AiDictionaryCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiDictionaryCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiDictionaryCacheHash();

  @$internal
  @override
  $ProviderElement<AiResultCache<DictionaryResult>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiResultCache<DictionaryResult> create(Ref ref) {
    return aiDictionaryCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiResultCache<DictionaryResult> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiResultCache<DictionaryResult>>(
        value,
      ),
    );
  }
}

String _$aiDictionaryCacheHash() => r'88020b57cac0e22beb4ef888f2132f543e1ed986';

/// Per-user typed `ContextualTranslationResult` cache.

@ProviderFor(aiContextualTranslationCache)
final aiContextualTranslationCacheProvider =
    AiContextualTranslationCacheProvider._();

/// Per-user typed `ContextualTranslationResult` cache.

final class AiContextualTranslationCacheProvider
    extends
        $FunctionalProvider<
          AiResultCache<ContextualTranslationResult>,
          AiResultCache<ContextualTranslationResult>,
          AiResultCache<ContextualTranslationResult>
        >
    with $Provider<AiResultCache<ContextualTranslationResult>> {
  /// Per-user typed `ContextualTranslationResult` cache.
  AiContextualTranslationCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiContextualTranslationCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiContextualTranslationCacheHash();

  @$internal
  @override
  $ProviderElement<AiResultCache<ContextualTranslationResult>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiResultCache<ContextualTranslationResult> create(Ref ref) {
    return aiContextualTranslationCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiResultCache<ContextualTranslationResult> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<AiResultCache<ContextualTranslationResult>>(value),
    );
  }
}

String _$aiContextualTranslationCacheHash() =>
    r'402ac37f3c32a217b2177e184d97e9a4a68e0ca2';
