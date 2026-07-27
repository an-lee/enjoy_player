/// Drift table: offline sync queue (aligned with weapp `syncQueue`).
library;

import 'package:drift/drift.dart';

@TableIndex(
  name: 'idx_sync_queue_retry_created',
  columns: {#retryCount, #createdAt},
)
@DataClassName('SyncQueueRow')
class SyncQueue extends Table {
  @override
  String get tableName => 'sync_queue';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get payloadJson => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttempt => dateTime().nullable()();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
