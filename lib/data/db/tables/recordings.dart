/// Drift table: pronunciation recordings (aligned with weapp `recordings`).
library;

import 'package:drift/drift.dart';

import 'sync_metadata.dart';

@TableIndex(name: 'idx_recordings_target', columns: {#targetType, #targetId})
@DataClassName('RecordingRow')
class Recordings extends Table with SyncMetadataColumns {
  @override
  String get tableName => 'recordings';

  TextColumn get id => text()();
  TextColumn get targetType => text()();
  TextColumn get targetId => text()();
  IntColumn get referenceStart => integer()();
  IntColumn get referenceDuration => integer()();
  TextColumn get referenceText => text()();
  TextColumn get language => text()();
  IntColumn get duration => integer()();
  TextColumn get md5 => text().nullable()();
  TextColumn get audioUrl => text().nullable()();
  IntColumn get pronunciationScore => integer().nullable()();
  TextColumn get assessmentJson => text().nullable()();
  TextColumn get localPath => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
