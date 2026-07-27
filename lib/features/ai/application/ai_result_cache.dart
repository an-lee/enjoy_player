/// Two-tier AI result cache hierarchy.
///
/// L1: bounded LRU + TTL in-memory map ([L1Store]).
/// L2: Drift-backed persistent store ([AiCacheDao]).
///
/// Reads are synchronous from L1 and asynchronous from L2. Writes are
/// synchronous to L1 and asynchronous (fire-and-forget) to L2; L2 I/O
/// failures are logged and swallowed, never thrown.
///
/// The cache is keyed on `(AiKind, fingerprint)` so cross-modality
/// collisions are impossible at every layer (L1 map, L2 SQL primary key,
/// fingerprint canonical encoding).
library;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/cache/lru_store.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/ai/application/ai_kind_policies.dart';
import 'package:enjoy_player/features/ai/domain/ai_kind.dart';
import 'package:enjoy_player/features/ai/domain/models/contextual_translation_result.dart';
import 'package:enjoy_player/features/ai/domain/models/dictionary_result.dart';
import 'package:enjoy_player/features/ai/domain/models/translation_result.dart';

part 'ai_result_cache.g.dart';

/// Read-only diagnostic snapshot of [AiResultCache].
class AiCacheStats {
  const AiCacheStats({
    required this.l1Size,
    required this.l1Capacity,
    required this.l2RowCounts,
  });

  final int l1Size;
  final int l1Capacity;
  final Map<AiKind, int> l2RowCounts;

  @override
  String toString() => 'AiCacheStats(l1=$l1Size/$l1Capacity, l2=$l2RowCounts)';
}

// ignore_for_file: prefer_initializing_formals

/// Two-tier AI result cache.
///
/// Constructed by [aiResultCacheProvider] in production. Tests construct
/// it directly with an in-memory `AppDatabase`.
abstract class AiResultCache<V extends Object> {
  AiResultCache({
    required AiCacheDao dao,
    required L1Store<String, V> l1,
    required Map<AiKind, AiKindPolicy> policies,
    Logger? logger,
  }) : _dao = dao,
       _l1 = l1,
       _policies = policies,
       _log = logger ?? logNamed('ai_cache');

  final AiCacheDao _dao;
  final L1Store<String, V> _l1;
  final Map<AiKind, AiKindPolicy> _policies;
  final Logger _log;

  /// L1-only synchronous read. Returns null on miss or TTL expiry.
  V? peek({required AiKind kind, required String key}) {
    final cacheKey = _cacheKey(kind, key);
    final value = _l1.peek(cacheKey);
    if (value != null) {
      _log.finest('ai_cache hit l1 kind=${kind.wire} key=$key');
    }
    return value;
  }

  /// L1 → L2 → loader chain. [forceRefresh] busts L1 + L2 for the key
  /// before invoking the loader.
  ///
  /// Loader exceptions propagate. L2 I/O failures degrade to "miss".
  Future<V> lookup({
    required AiKind kind,
    required String key,
    required Future<V> Function() loader,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(kind, key);

    if (forceRefresh) {
      _l1.invalidate(cacheKey);
      await _dao.deleteRow(kind.wire, key);
      _log.info('ai_cache force_refresh kind=${kind.wire} key=$key');
    } else {
      final hit = _l1.peek(cacheKey);
      if (hit != null) {
        _log.finest('ai_cache hit l1 kind=${kind.wire} key=$key');
        return hit;
      }
      final row = await _dao.read(kind.wire, key);
      if (row != null) {
        try {
          final decoded = _decode(row.payloadJson);
          _l1.put(cacheKey, decoded);
          _log.finest('ai_cache hit l2 kind=${kind.wire} key=$key');
          return decoded;
        } on Object catch (e, st) {
          // Stale / corrupted payload — treat as miss and evict.
          _log.warning(
            'ai_cache l2 decode failed kind=${kind.wire} key=$key',
            e,
            st,
          );
          await _dao.deleteRow(kind.wire, key);
        }
      }
    }

    _log.info('ai_cache miss kind=${kind.wire} key=$key (calling loader)');
    final result = await loader();
    await remember(kind: kind, key: key, value: result);
    return result;
  }

  /// Writes [value] to L1 (sync) and L2 (async; failure logged).
  Future<void> remember({
    required AiKind kind,
    required String key,
    required V value,
  }) async {
    final cacheKey = _cacheKey(kind, key);
    _l1.put(cacheKey, value);
    try {
      final json = jsonEncode(_encode(value));
      await _dao.upsert(kind.wire, key, json, DateTime.now());
    } on Object catch (e, st) {
      _log.warning(
        'ai_cache remember l2 failed kind=${kind.wire} key=$key',
        e,
        st,
      );
    }
  }

  /// Removes the entry from L1 and L2. No-op if not cached.
  Future<void> invalidate({required AiKind kind, required String key}) async {
    _l1.invalidate(_cacheKey(kind, key));
    await _dao.deleteRow(kind.wire, key);
    _log.info('ai_cache invalidate kind=${kind.wire} key=$key');
  }

  /// Removes every entry whose decoded JSON payload contains
  /// `sourceLanguage == X && targetLanguage == Y`. Scans L2 via SQL
  /// `LIKE` on `payload_json`.
  ///
  /// Note: because the cache key already includes `(src, tgt)`, L1 entries
  /// for a different pair cannot shadow a lookup for `(X, Y)` — they are
  /// already isolated by key. The L1 sweep below is purely opportunistic
  /// memory cleanup; the L2 sweep is the correctness guarantee.
  Future<void> evictForPair({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    // L2: single-statement bulk DELETE (issue #478) — replaces the previous
    // SELECT-then-per-row-DELETE loop.
    final srcPattern = '%"sourceLanguage":"$sourceLanguage"%';
    final tgtPattern = '%"targetLanguage":"$targetLanguage"%';
    final deleted = await _dao.deleteByPayloadLike(srcPattern, tgtPattern);
    _log.info(
      'ai_cache evict_for_pair src=$sourceLanguage tgt=$targetLanguage '
      'l2=$deleted',
    );
  }

  /// Drops L1 and every L2 row. Used on sign-out / user-id change.
  Future<void> clear() async {
    _l1.clear();
    for (final kind in _policies.keys) {
      await _dao.deleteForKind(kind.wire);
    }
    _log.info('ai_cache clear');
  }

  /// For each kind in [_policies], applies the L2 row cap and age cutoff.
  Future<void> prune() async {
    final now = DateTime.now();
    for (final entry in _policies.entries) {
      final kind = entry.key;
      final policy = entry.value;
      if (policy.l2RowCap > 0) {
        await _dao.evictOldestExcept(kind.wire, policy.l2RowCap);
      }
      if (policy.l2AgeCutoff > Duration.zero) {
        final cutoff = now.subtract(policy.l2AgeCutoff);
        await _dao.pruneOlderThan(kind.wire, cutoff);
      }
    }
    _log.info('ai_cache prune complete');
  }

  /// Read-only diagnostics snapshot.
  Future<AiCacheStats> stats() async {
    final l2Counts = <AiKind, int>{};
    for (final kind in _policies.keys) {
      l2Counts[kind] = await _dao.countForKind(kind.wire);
    }
    return AiCacheStats(
      l1Size: _l1.size,
      l1Capacity: _l1.capacity,
      l2RowCounts: l2Counts,
    );
  }

  String _cacheKey(AiKind kind, String key) => '${kind.wire}|$key';

  V _decode(String payloadJson) {
    final map = jsonDecode(payloadJson) as Map<String, dynamic>;
    return fromJson(map);
  }

  Map<String, dynamic> _encode(V value) => toJson(value);

  /// Subclass-supplied JSON adapter.
  V fromJson(Map<String, dynamic> json);

  /// Subclass-supplied JSON adapter.
  Map<String, dynamic> toJson(V value);
}

/// Typed convenience wrapper for caching [Map] payloads (e.g. plain
/// translation / dictionary). Used by the lookup sheet providers.
class AiMapCache extends AiResultCache<Map<String, dynamic>> {
  AiMapCache({
    required super.dao,
    required super.l1,
    required super.policies,
    super.logger,
  });

  @override
  Map<String, dynamic> fromJson(Map<String, dynamic> json) => json;

  @override
  Map<String, dynamic> toJson(Map<String, dynamic> value) => value;
}

/// Cache subclass for `TranslationResult` (freezed + json_serializable).
class AiTranslationCache extends AiResultCache<TranslationResult> {
  AiTranslationCache({
    required super.dao,
    required super.l1,
    required super.policies,
    super.logger,
  });

  @override
  TranslationResult fromJson(Map<String, dynamic> json) =>
      TranslationResult.fromJson(json);

  @override
  Map<String, dynamic> toJson(TranslationResult value) => value.toJson();
}

/// Cache subclass for `DictionaryResult` (already has fromJson).
class AiDictionaryCache extends AiResultCache<DictionaryResult> {
  AiDictionaryCache({
    required super.dao,
    required super.l1,
    required super.policies,
    super.logger,
  });

  @override
  DictionaryResult fromJson(Map<String, dynamic> json) =>
      DictionaryResult.fromJson(json);

  @override
  Map<String, dynamic> toJson(DictionaryResult value) => value.toJson();
}

/// Cache subclass for `ContextualTranslationResult` (added in this PR).
class AiContextualTranslationCache
    extends AiResultCache<ContextualTranslationResult> {
  AiContextualTranslationCache({
    required super.dao,
    required super.l1,
    required super.policies,
    super.logger,
  });

  @override
  ContextualTranslationResult fromJson(Map<String, dynamic> json) =>
      ContextualTranslationResult.fromJson(json);

  @override
  Map<String, dynamic> toJson(ContextualTranslationResult value) =>
      value.toJson();
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Coalesces the startup prune pass for all AI cache kinds (issue #478).
///
/// Previously each of the four cache providers called `unawaited(cache.prune())`
/// at construction — 4 × len(policies) × 2 SQL ops against the same `ai_cache`
/// table racing on the same Drift executor. This provider runs the prune once
/// per database instance; each cache provider watches it to ensure it has
/// fired before the cache is used.
@Riverpod(keepAlive: true)
void aiCacheStartupPrune(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final policies = defaultAiKindPolicies;
  unawaited(() async {
    final now = DateTime.now();
    for (final entry in policies.entries) {
      final kind = entry.key;
      final policy = entry.value;
      if (policy.l2RowCap > 0) {
        await db.aiCacheDao.evictOldestExcept(kind.wire, policy.l2RowCap);
      }
      if (policy.l2AgeCutoff > Duration.zero) {
        final cutoff = now.subtract(policy.l2AgeCutoff);
        await db.aiCacheDao.pruneOlderThan(kind.wire, cutoff);
      }
    }
  }());
}

/// Per-user `AiMapCache` (JSON-typed payload). Cleared on sign-out /
/// user-id change.
///
/// The cache is `keepAlive` because lookup-sheet and contextual-translation
/// flows outlive any single widget mount; closing the sheet must not
/// invalidate the cache.
@Riverpod(keepAlive: true)
AiMapCache aiResultCache(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final cache = AiMapCache(
    dao: db.aiCacheDao,
    l1: L1Store<String, Map<String, dynamic>>(
      capacity: 256,
      ttl: const Duration(minutes: 30),
    ),
    policies: defaultAiKindPolicies,
  );

  // Clear L1 + L2 on sign-out or user-id change so we never serve a
  // previous user's cached translations (R7). L2 is naturally scoped
  // by the active `appDatabaseProvider`; this listener ensures the
  // in-memory L1 is also dropped.
  ref.listen(authCtrlProvider, (prev, next) {
    final prevState = prev?.valueOrNull;
    final nextState = next.valueOrNull;
    final wasSignedIn = prevState is AuthSignedIn;
    final isSignedIn = nextState is AuthSignedIn;
    final userChanged =
        wasSignedIn &&
        isSignedIn &&
        prevState.profile.id != nextState.profile.id;
    if (!isSignedIn || userChanged) {
      unawaited(cache.clear());
    }
  });

  ref.watch(aiCacheStartupPruneProvider);
  return cache;
}

/// Per-user `AiTranslationCache` (typed `TranslationResult`). Shares the
/// L2 Drift table with `aiResultCache` (different `AiKind.wire`).
@Riverpod(keepAlive: true)
AiTranslationCache aiTranslationCache(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final cache = AiTranslationCache(
    dao: db.aiCacheDao,
    l1: L1Store<String, TranslationResult>(
      capacity: 256,
      ttl: const Duration(minutes: 30),
    ),
    policies: defaultAiKindPolicies,
  );
  ref.listen(authCtrlProvider, (prev, next) {
    final prevState = prev?.valueOrNull;
    final nextState = next.valueOrNull;
    final wasSignedIn = prevState is AuthSignedIn;
    final isSignedIn = nextState is AuthSignedIn;
    final userChanged =
        wasSignedIn &&
        isSignedIn &&
        prevState.profile.id != nextState.profile.id;
    if (!isSignedIn || userChanged) {
      unawaited(cache.clear());
    }
  });
  ref.watch(aiCacheStartupPruneProvider);
  return cache;
}

/// Per-user `AiDictionaryCache`.
@Riverpod(keepAlive: true)
AiDictionaryCache aiDictionaryCache(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final cache = AiDictionaryCache(
    dao: db.aiCacheDao,
    l1: L1Store<String, DictionaryResult>(
      capacity: 256,
      ttl: const Duration(minutes: 30),
    ),
    policies: defaultAiKindPolicies,
  );
  ref.listen(authCtrlProvider, (prev, next) {
    final prevState = prev?.valueOrNull;
    final nextState = next.valueOrNull;
    final wasSignedIn = prevState is AuthSignedIn;
    final isSignedIn = nextState is AuthSignedIn;
    final userChanged =
        wasSignedIn &&
        isSignedIn &&
        prevState.profile.id != nextState.profile.id;
    if (!isSignedIn || userChanged) {
      unawaited(cache.clear());
    }
  });
  ref.watch(aiCacheStartupPruneProvider);
  return cache;
}

/// Per-user `AiContextualTranslationCache`.
@Riverpod(keepAlive: true)
AiContextualTranslationCache aiContextualTranslationCache(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final cache = AiContextualTranslationCache(
    dao: db.aiCacheDao,
    l1: L1Store<String, ContextualTranslationResult>(
      capacity: 256,
      ttl: const Duration(minutes: 30),
    ),
    policies: defaultAiKindPolicies,
  );
  ref.listen(authCtrlProvider, (prev, next) {
    final prevState = prev?.valueOrNull;
    final nextState = next.valueOrNull;
    final wasSignedIn = prevState is AuthSignedIn;
    final isSignedIn = nextState is AuthSignedIn;
    final userChanged =
        wasSignedIn &&
        isSignedIn &&
        prevState.profile.id != nextState.profile.id;
    if (!isSignedIn || userChanged) {
      unawaited(cache.clear());
    }
  });
  ref.watch(aiCacheStartupPruneProvider);
  return cache;
}
