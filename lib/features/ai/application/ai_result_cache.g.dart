// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_result_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Coalesces the startup prune pass for all AI cache kinds (issue #478).
///
/// Previously each of the four cache providers called `unawaited(cache.prune())`
/// at construction — 4 × len(policies) × 2 SQL ops against the same `ai_cache`
/// table racing on the same Drift executor. This provider runs the prune once
/// per database instance; each cache provider watches it to ensure it has
/// fired before the cache is used.

@ProviderFor(aiCacheStartupPrune)
final aiCacheStartupPruneProvider = AiCacheStartupPruneProvider._();

/// Coalesces the startup prune pass for all AI cache kinds (issue #478).
///
/// Previously each of the four cache providers called `unawaited(cache.prune())`
/// at construction — 4 × len(policies) × 2 SQL ops against the same `ai_cache`
/// table racing on the same Drift executor. This provider runs the prune once
/// per database instance; each cache provider watches it to ensure it has
/// fired before the cache is used.

final class AiCacheStartupPruneProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Coalesces the startup prune pass for all AI cache kinds (issue #478).
  ///
  /// Previously each of the four cache providers called `unawaited(cache.prune())`
  /// at construction — 4 × len(policies) × 2 SQL ops against the same `ai_cache`
  /// table racing on the same Drift executor. This provider runs the prune once
  /// per database instance; each cache provider watches it to ensure it has
  /// fired before the cache is used.
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

/// Per-user `AiMapCache` (JSON-typed payload). Cleared on sign-out /
/// user-id change.
///
/// The cache is `keepAlive` because lookup-sheet and contextual-translation
/// flows outlive any single widget mount; closing the sheet must not
/// invalidate the cache.

@ProviderFor(aiResultCache)
final aiResultCacheProvider = AiResultCacheProvider._();

/// Per-user `AiMapCache` (JSON-typed payload). Cleared on sign-out /
/// user-id change.
///
/// The cache is `keepAlive` because lookup-sheet and contextual-translation
/// flows outlive any single widget mount; closing the sheet must not
/// invalidate the cache.

final class AiResultCacheProvider
    extends $FunctionalProvider<AiMapCache, AiMapCache, AiMapCache>
    with $Provider<AiMapCache> {
  /// Per-user `AiMapCache` (JSON-typed payload). Cleared on sign-out /
  /// user-id change.
  ///
  /// The cache is `keepAlive` because lookup-sheet and contextual-translation
  /// flows outlive any single widget mount; closing the sheet must not
  /// invalidate the cache.
  AiResultCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiResultCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiResultCacheHash();

  @$internal
  @override
  $ProviderElement<AiMapCache> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiMapCache create(Ref ref) {
    return aiResultCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiMapCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiMapCache>(value),
    );
  }
}

String _$aiResultCacheHash() => r'a091f85bdab587328537b1aa67a201f36011c981';

/// Per-user `AiTranslationCache` (typed `TranslationResult`). Shares the
/// L2 Drift table with `aiResultCache` (different `AiKind.wire`).

@ProviderFor(aiTranslationCache)
final aiTranslationCacheProvider = AiTranslationCacheProvider._();

/// Per-user `AiTranslationCache` (typed `TranslationResult`). Shares the
/// L2 Drift table with `aiResultCache` (different `AiKind.wire`).

final class AiTranslationCacheProvider
    extends
        $FunctionalProvider<
          AiTranslationCache,
          AiTranslationCache,
          AiTranslationCache
        >
    with $Provider<AiTranslationCache> {
  /// Per-user `AiTranslationCache` (typed `TranslationResult`). Shares the
  /// L2 Drift table with `aiResultCache` (different `AiKind.wire`).
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
  $ProviderElement<AiTranslationCache> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiTranslationCache create(Ref ref) {
    return aiTranslationCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiTranslationCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiTranslationCache>(value),
    );
  }
}

String _$aiTranslationCacheHash() =>
    r'255329c8a3653ebc1da72377c4104f25e794e5c0';

/// Per-user `AiDictionaryCache`.

@ProviderFor(aiDictionaryCache)
final aiDictionaryCacheProvider = AiDictionaryCacheProvider._();

/// Per-user `AiDictionaryCache`.

final class AiDictionaryCacheProvider
    extends
        $FunctionalProvider<
          AiDictionaryCache,
          AiDictionaryCache,
          AiDictionaryCache
        >
    with $Provider<AiDictionaryCache> {
  /// Per-user `AiDictionaryCache`.
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
  $ProviderElement<AiDictionaryCache> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiDictionaryCache create(Ref ref) {
    return aiDictionaryCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiDictionaryCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiDictionaryCache>(value),
    );
  }
}

String _$aiDictionaryCacheHash() => r'3faf13ed889a1d005279546fa66e64256ca91d75';

/// Per-user `AiContextualTranslationCache`.

@ProviderFor(aiContextualTranslationCache)
final aiContextualTranslationCacheProvider =
    AiContextualTranslationCacheProvider._();

/// Per-user `AiContextualTranslationCache`.

final class AiContextualTranslationCacheProvider
    extends
        $FunctionalProvider<
          AiContextualTranslationCache,
          AiContextualTranslationCache,
          AiContextualTranslationCache
        >
    with $Provider<AiContextualTranslationCache> {
  /// Per-user `AiContextualTranslationCache`.
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
  $ProviderElement<AiContextualTranslationCache> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiContextualTranslationCache create(Ref ref) {
    return aiContextualTranslationCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiContextualTranslationCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiContextualTranslationCache>(value),
    );
  }
}

String _$aiContextualTranslationCacheHash() =>
    r'5429bf6ef754e46ceee108a9cb27d0c8004da09c';
