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

// ignore_for_file: prefer_initializing_formals

/// Two-tier AI result cache.
///
/// One generic class for every payload type — the JSON adapter is injected
/// as `fromJson` / `toJson` converters. Constructed by the per-kind
/// providers below; tests construct it directly with an in-memory
/// `AppDatabase`.
class AiResultCache<V extends Object> {
  AiResultCache({
    required AiCacheDao dao,
    required L1Store<String, V> l1,
    required Map<AiKind, AiKindPolicy> policies,
    Logger? logger,
    required V Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(V value) toJson,
  }) : _dao = dao,
       _l1 = l1,
       _policies = policies,
       _log = logger ?? logNamed('ai_cache'),
       _fromJson = fromJson,
       _toJson = toJson;

  final AiCacheDao _dao;
  final L1Store<String, V> _l1;
  final Map<AiKind, AiKindPolicy> _policies;
  final Logger _log;
  final V Function(Map<String, dynamic> json) _fromJson;
  final Map<String, dynamic> Function(V value) _toJson;

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
      final json = jsonEncode(_toJson(value));
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

  String _cacheKey(AiKind kind, String key) => '${kind.wire}|$key';

  V _decode(String payloadJson) {
    final map = jsonDecode(payloadJson) as Map<String, dynamic>;
    return _fromJson(map);
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Coalesces the startup prune pass for all AI cache kinds (issue #478).
///
/// Previously each of the cache providers called `unawaited(cache.prune())`
/// at construction — N × len(policies) × 2 SQL ops against the same
/// `ai_cache` table racing on the same Drift executor. This provider runs
/// the prune once per database instance; each cache provider watches it to
/// ensure it has fired before the cache is used.
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

/// Shared construction for the per-kind caches: same L1 sizing (256
/// entries / 30 min TTL), same policies, and the sign-out / user-change
/// clear listener so we never serve a previous user's cached results (R7).
/// L2 is naturally scoped by the active `appDatabaseProvider`; the
/// listener ensures the in-memory L1 is also dropped.
AiResultCache<V> _buildPerUserCache<V extends Object>(
  Ref ref, {
  required V Function(Map<String, dynamic> json) fromJson,
  required Map<String, dynamic> Function(V value) toJson,
}) {
  final db = ref.watch(appDatabaseProvider);
  final cache = AiResultCache<V>(
    dao: db.aiCacheDao,
    l1: L1Store<String, V>(capacity: 256, ttl: const Duration(minutes: 30)),
    policies: defaultAiKindPolicies,
    fromJson: fromJson,
    toJson: toJson,
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

/// Per-user typed `TranslationResult` cache.
@Riverpod(keepAlive: true)
AiResultCache<TranslationResult> aiTranslationCache(Ref ref) =>
    _buildPerUserCache(
      ref,
      fromJson: TranslationResult.fromJson,
      toJson: (value) => value.toJson(),
    );

/// Per-user typed `DictionaryResult` cache.
@Riverpod(keepAlive: true)
AiResultCache<DictionaryResult> aiDictionaryCache(Ref ref) =>
    _buildPerUserCache(
      ref,
      fromJson: DictionaryResult.fromJson,
      toJson: (value) => value.toJson(),
    );

/// Per-user typed `ContextualTranslationResult` cache.
@Riverpod(keepAlive: true)
AiResultCache<ContextualTranslationResult> aiContextualTranslationCache(
  Ref ref,
) => _buildPerUserCache(
  ref,
  fromJson: ContextualTranslationResult.fromJson,
  toJson: (value) => value.toJson(),
);
