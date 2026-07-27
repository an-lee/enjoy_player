/// Drift table: video media (aligned with weapp Dexie `videos`).
library;

import 'package:drift/drift.dart';

import 'sync_metadata.dart';

@TableIndex(name: 'idx_videos_provider_vid', columns: {#provider, #vid})
@TableIndex(name: 'idx_videos_local_uri', columns: {#localUri})
@DataClassName('VideoRow')
class Videos extends Table with SyncMetadataColumns {
  @override
  String get tableName => 'videos';

  TextColumn get id => text()();
  TextColumn get vid => text()();
  TextColumn get provider => text().withDefault(const Constant('user'))();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();

  /// Duration in whole seconds (weapp `Video.duration`).
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  TextColumn get language => text().withDefault(const Constant('und'))();
  TextColumn get source => text().nullable()();

  /// Local file URI (replaces web `fileHandle` / `blob`).
  TextColumn get localUri => text().nullable()();
  TextColumn get md5 => text().nullable()();
  IntColumn get size => integer().nullable()();

  /// Last-modified ms of the linked/copied file at import or re-link time.
  /// Used for cheap open trust checks; device-local (not synced).
  IntColumn get localMtimeMs => integer().nullable()();
  TextColumn get mediaUrl => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
