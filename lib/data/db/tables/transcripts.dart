/// Drift table: transcript payloads (aligned with weapp Dexie `transcripts`).
library;

import 'package:drift/drift.dart';

import 'sync_metadata.dart';

@TableIndex(name: 'idx_transcripts_target', columns: {#targetType, #targetId})
@DataClassName('TranscriptRow')
class Transcripts extends Table with SyncMetadataColumns {
  @override
  String get tableName => 'transcripts';

  TextColumn get id => text()();

  /// Weapp `TargetType`: `Video` | `Audio` | `Example` | `Ebook`.
  TextColumn get targetType => text()();
  TextColumn get targetId => text()();
  TextColumn get language => text()();

  /// Weapp `TranscriptSource`: `official` | `auto` | `ai` | `user`.
  TextColumn get source => text()();

  /// JSON array of `TranscriptLine` (ms-based), same shape as enjoy web
  /// `timeline` (`{text, start, duration}` plus optional nested `timeline` /
  /// `phones` per ADR-0070).
  TextColumn get timelineJson => text()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get label => text().withDefault(const Constant(''))();
  IntColumn get trackIndex => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
