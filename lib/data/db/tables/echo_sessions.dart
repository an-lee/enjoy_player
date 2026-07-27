/// Drift table: echo / playback practice session (aligned with weapp `echoSessions`).
library;

import 'package:drift/drift.dart';

import 'sync_metadata.dart';

@TableIndex(
  name: 'idx_echo_sessions_target_active',
  columns: {#targetType, #targetId, #lastActiveAt},
)
@DataClassName('EchoSessionRow')
class EchoSessions extends Table with SyncMetadataColumns {
  @override
  String get tableName => 'echo_sessions';

  TextColumn get id => text()();
  TextColumn get targetType => text()();
  TextColumn get targetId => text()();
  TextColumn get language => text().withDefault(const Constant('und'))();

  IntColumn get currentTimeMs => integer().withDefault(const Constant(0))();
  RealColumn get playbackRate => real().withDefault(const Constant(1.0))();
  RealColumn get volume => real().withDefault(const Constant(1.0))();
  IntColumn get echoStartMs => integer().nullable()();
  IntColumn get echoEndMs => integer().nullable()();

  /// Primary transcript (weapp `transcriptId`).
  TextColumn get transcriptId => text().nullable()();
  TextColumn get secondaryTranscriptId => text().nullable()();

  IntColumn get recordingsCount => integer().withDefault(const Constant(0))();
  IntColumn get recordingsDurationMs =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lastRecordingAt => dateTime().nullable()();

  IntColumn get currentSegmentIndex =>
      integer().withDefault(const Constant(-1))();
  BoolColumn get echoActive => boolean().withDefault(const Constant(false))();
  IntColumn get echoStartLine => integer().withDefault(const Constant(-1))();
  IntColumn get echoEndLine => integer().withDefault(const Constant(-1))();

  /// Listening-focus (transcript blur) practice mode for this target.
  BoolColumn get blurActive => boolean().withDefault(const Constant(false))();

  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get lastActiveAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
