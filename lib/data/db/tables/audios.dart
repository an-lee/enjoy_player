/// Drift table: audio media (aligned with weapp Dexie `audios`).
library;

import 'package:drift/drift.dart';

import 'sync_metadata.dart';

@TableIndex(name: 'idx_audios_local_uri', columns: {#localUri})
@TableIndex(name: 'idx_audios_md5', columns: {#md5})
@DataClassName('AudioRow')
class Audios extends Table with SyncMetadataColumns {
  @override
  String get tableName => 'audios';

  TextColumn get id => text()();
  TextColumn get aid => text()();
  TextColumn get provider => text().withDefault(const Constant('user'))();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  TextColumn get language => text().withDefault(const Constant('und'))();
  TextColumn get translationKey => text().nullable()();
  TextColumn get sourceText => text().nullable()();
  TextColumn get voice => text().nullable()();
  TextColumn get source => text().nullable()();
  TextColumn get localUri => text().nullable()();

  /// macOS security-scoped bookmark bytes for [localUri]. See ADR-0060.
  BlobColumn get bookmarkData => blob().nullable()();
  TextColumn get md5 => text().nullable()();
  IntColumn get size => integer().nullable()();

  /// Last-modified ms of the linked/copied file at import or re-link time.
  /// Used for cheap open trust checks; device-local (not synced).
  IntColumn get localMtimeMs => integer().nullable()();
  TextColumn get mediaUrl => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
