/// Drift table: dictation attempts (aligned with weapp `dictations`).
library;

import 'package:drift/drift.dart';

import 'sync_metadata.dart';

@TableIndex(name: 'idx_dictations_target', columns: {#targetType, #targetId})
@DataClassName('DictationRow')
class Dictations extends Table with SyncMetadataColumns {
  @override
  String get tableName => 'dictations';

  TextColumn get id => text()();
  TextColumn get targetType => text()();
  TextColumn get targetId => text()();
  IntColumn get referenceStartMs => integer()();
  IntColumn get referenceDurationMs => integer()();
  TextColumn get referenceText => text()();
  TextColumn get language => text()();
  TextColumn get userInput => text()();
  IntColumn get accuracy => integer()();
  IntColumn get correctWords => integer()();
  IntColumn get missedWords => integer()();
  IntColumn get extraWords => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
