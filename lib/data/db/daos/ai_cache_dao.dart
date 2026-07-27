part of '../app_database.dart';

@DriftAccessor(tables: [AiCache])
class AiCacheDao extends DatabaseAccessor<AppDatabase> with _$AiCacheDaoMixin {
  AiCacheDao(super.db);

  static final _log = logNamed('ai_cache');

  Future<AiCacheRow?> read(String kind, String key) async {
    try {
      return await (select(aiCache)
            ..where((t) => t.kind.equals(kind) & t.key.equals(key)))
          .getSingleOrNull();
    } on Object catch (e, st) {
      _log.warning('ai_cache read failed kind=$kind key=$key', e, st);
      return null;
    }
  }

  Future<void> upsert(
    String kind,
    String key,
    String payloadJson,
    DateTime updatedAt,
  ) async {
    try {
      await into(aiCache).insert(
        AiCacheRow(
          kind: kind,
          key: key,
          payloadJson: payloadJson,
          updatedAt: updatedAt.millisecondsSinceEpoch,
        ),
        mode: InsertMode.insertOrReplace,
      );
    } on Object catch (e, st) {
      _log.warning('ai_cache upsert failed kind=$kind key=$key', e, st);
    }
  }

  Future<void> deleteRow(String kind, String key) async {
    try {
      await (delete(
        aiCache,
      )..where((t) => t.kind.equals(kind) & t.key.equals(key))).go();
    } on Object catch (e, st) {
      _log.warning('ai_cache deleteRow failed kind=$kind key=$key', e, st);
    }
  }

  Future<int> evictOldestExcept(String kind, int keep) async {
    if (keep < 0) return 0;
    try {
      final total =
          await (selectOnly(aiCache)
                ..addColumns([aiCache.key.count()])
                ..where(aiCache.kind.equals(kind)))
              .map((row) => row.read<int>(aiCache.key.count()) ?? 0)
              .getSingle();
      if (total <= keep) return 0;
      final toDelete = total - keep;
      // Single-statement bulk DELETE (issue #478): avoids N round-trips
      // and N fsyncs when evicting many keys.
      await customStatement(
        'DELETE FROM ai_cache WHERE kind = ? AND key IN '
        '(SELECT key FROM ai_cache WHERE kind = ? ORDER BY updated_at ASC LIMIT ?)',
        [kind, kind, toDelete],
      );
      return toDelete;
    } on Object catch (e, st) {
      _log.warning('ai_cache evictOldestExcept failed kind=$kind', e, st);
      return -1;
    }
  }

  Future<int> pruneOlderThan(String kind, DateTime cutoff) async {
    try {
      final before =
          await (selectOnly(aiCache)
                ..addColumns([aiCache.key.count()])
                ..where(
                  aiCache.kind.equals(kind) &
                      aiCache.updatedAt.isSmallerThanValue(
                        cutoff.millisecondsSinceEpoch,
                      ),
                ))
              .map((row) => row.read<int>(aiCache.key.count()) ?? 0)
              .getSingle();
      await (delete(aiCache)..where(
            (t) =>
                t.kind.equals(kind) &
                t.updatedAt.isSmallerThanValue(cutoff.millisecondsSinceEpoch),
          ))
          .go();
      return before;
    } on Object catch (e, st) {
      _log.warning('ai_cache pruneOlderThan failed kind=$kind', e, st);
      return -1;
    }
  }

  Future<void> deleteForKind(String kind) async {
    try {
      await (delete(aiCache)..where((t) => t.kind.equals(kind))).go();
    } on Object catch (e, st) {
      _log.warning('ai_cache deleteForKind failed kind=$kind', e, st);
    }
  }

  /// Bulk-deletes every row whose `payload_json` matches both LIKE patterns
  /// in a single SQL statement (issue #478). Returns the number of deleted
  /// rows.
  Future<int> deleteByPayloadLike(String pattern1, String pattern2) async {
    try {
      final count =
          await (selectOnly(aiCache)
                ..addColumns([aiCache.key.count()])
                ..where(
                  aiCache.payloadJson.like(pattern1) &
                      aiCache.payloadJson.like(pattern2),
                ))
              .map((row) => row.read<int>(aiCache.key.count()) ?? 0)
              .getSingle();
      await customStatement(
        'DELETE FROM ai_cache WHERE payload_json LIKE ? AND payload_json LIKE ?',
        [pattern1, pattern2],
      );
      return count;
    } on Object catch (e, st) {
      _log.warning('ai_cache deleteByPayloadLike failed', e, st);
      return -1;
    }
  }

  Stream<List<AiCacheRow>> readAllForKind(String kind) {
    return (select(aiCache)..where((t) => t.kind.equals(kind))).watch();
  }

  Future<int> countForKind(String kind) async {
    try {
      return await (selectOnly(aiCache)
            ..addColumns([aiCache.key.count()])
            ..where(aiCache.kind.equals(kind)))
          .map((row) => row.read<int>(aiCache.key.count()) ?? 0)
          .getSingle();
    } on Object catch (e, st) {
      _log.warning('ai_cache countForKind failed kind=$kind', e, st);
      return 0;
    }
  }
}
