/// Persistence for the offline sync queue (Dexie-aligned).
library;

import 'package:drift/drift.dart';

import 'package:enjoy_player/data/db/app_database.dart';

/// Live counts + capped rows for sync status UI.
final class SyncQueueSnapshot {
  const SyncQueueSnapshot({
    required this.retryablePending,
    required this.permanentlyFailed,
    required this.detailRows,
  });

  /// Rows still eligible for retry (`retryCount < 5`).
  final int retryablePending;

  /// Exhausted retries (`retryCount >= 5`).
  final int permanentlyFailed;

  /// Oldest-first subset for expandable UI (capped).
  final List<SyncQueueRow> detailRows;

  bool get isFullyCaughtUp => retryablePending == 0 && permanentlyFailed == 0;
}

class SyncQueueRepository {
  SyncQueueRepository(this._db);

  final AppDatabase _db;

  /// Adds or refreshes a queue row for `(entityType, entityId, action)` —
  /// mirrors web [addSyncQueueItem].
  ///
  /// On an existing row, only [payloadJson] is overwritten. The
  /// `retryCount`, `lastAttempt`, and `error` columns are **preserved**
  /// so a permanently failed row stays failed even if the entity is
  /// edited locally — editing the entity should not silently re-arm
  /// a row that was rejected by the server. To re-arm failed rows
  /// use [resetFailed].
  Future<int> addOrUpsert({
    required String entityType,
    required String entityId,
    required String action,
    String? payloadJson,
  }) async {
    final existing =
        await (_db.select(_db.syncQueue)..where(
              (t) =>
                  t.entityType.equals(entityType) &
                  t.entityId.equals(entityId) &
                  t.action.equals(action),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.syncQueue)..where((t) => t.id.equals(existing.id)))
          .write(SyncQueueCompanion(payloadJson: Value(payloadJson)));
      return existing.id;
    }

    return _db
        .into(_db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            entityType: entityType,
            entityId: entityId,
            action: action,
            payloadJson: Value(payloadJson),
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Rows that may still be retried (`retryCount < 5`), oldest first.
  Future<List<SyncQueueRow>> pendingItems({int limit = 500}) {
    return (_db.select(_db.syncQueue)
          ..where((t) => t.retryCount.isSmallerThanValue(5))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Watch queue for live status (counts + capped detail list).
  Stream<SyncQueueSnapshot> watchSnapshot({int detailLimit = 50}) {
    return _db.select(_db.syncQueue).watch().map((rows) {
      var retryable = 0;
      var failed = 0;
      for (final r in rows) {
        if (r.retryCount >= 5) {
          failed++;
        } else {
          retryable++;
        }
      }
      final sorted = [...rows]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final detail = sorted.length <= detailLimit
          ? sorted
          : sorted.sublist(0, detailLimit);
      return SyncQueueSnapshot(
        retryablePending: retryable,
        permanentlyFailed: failed,
        detailRows: detail,
      );
    });
  }

  Future<void> removeById(int id) => _db.syncQueueDao.deleteId(id);

  Future<void> markAttempted(int id, {String? error}) =>
      _db.syncQueueDao.markAttempted(id, error: error);

  Future<void> markPermanentlyFailed(int id, {String? error}) =>
      _db.syncQueueDao.markPermanentlyFailed(id, error: error);

  /// Clears error state for permanently failed items so they retry again.
  ///
  /// Single bulk UPDATE instead of SELECT+loop-UPDATE (issue #468).
  Future<int> resetFailed() async {
    final failed =
        await (_db.selectOnly(_db.syncQueue)
              ..addColumns([_db.syncQueue.id.count()])
              ..where(_db.syncQueue.retryCount.isBiggerOrEqualValue(5)))
            .map((row) => row.read<int>(_db.syncQueue.id.count()) ?? 0)
            .getSingle();
    if (failed == 0) return 0;
    await (_db.update(
      _db.syncQueue,
    )..where((t) => t.retryCount.isBiggerOrEqualValue(5))).write(
      const SyncQueueCompanion(
        retryCount: Value(0),
        error: Value(null),
        lastAttempt: Value(null),
      ),
    );
    return failed;
  }
}
