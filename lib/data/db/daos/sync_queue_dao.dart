part of '../app_database.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Future<int> enqueue({
    required String entityType,
    required String entityId,
    required String action,
    String? payloadJson,
  }) => into(syncQueue).insert(
    SyncQueueCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      action: action,
      payloadJson: Value(payloadJson),
      createdAt: DateTime.now(),
    ),
  );

  Future<List<SyncQueueRow>> peekBatch({int limit = 50}) =>
      (select(syncQueue)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(limit))
          .get();

  /// Increments `retry_count` and stamps `last_attempt` + `error` in a
  /// single set-based UPDATE — no SELECT round-trip (issue #468).
  Future<void> markAttempted(int id, {String? error}) async {
    if (error == null) {
      await customUpdate(
        'UPDATE sync_queue SET retry_count = retry_count + 1, '
        'last_attempt = ?, error = NULL WHERE id = ?',
        variables: [
          Variable.withDateTime(DateTime.now()),
          Variable.withInt(id),
        ],
        updates: {syncQueue},
      );
    } else {
      await customUpdate(
        'UPDATE sync_queue SET retry_count = retry_count + 1, '
        'last_attempt = ?, error = ? WHERE id = ?',
        variables: [
          Variable.withDateTime(DateTime.now()),
          Variable.withString(error),
          Variable.withInt(id),
        ],
        updates: {syncQueue},
      );
    }
  }

  /// Sets [retryCount] to 5 so the row is no longer eligible for retry.
  /// Direct UPDATE — no SELECT round-trip (issue #468).
  Future<void> markPermanentlyFailed(int id, {String? error}) async {
    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: const Value(5),
        lastAttempt: Value(DateTime.now()),
        error: Value(error),
      ),
    );
  }

  Future<void> deleteId(int id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();
}
