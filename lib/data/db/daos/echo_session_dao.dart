part of '../app_database.dart';

@DriftAccessor(tables: [EchoSessions])
class EchoSessionDao extends DatabaseAccessor<AppDatabase>
    with _$EchoSessionDaoMixin {
  EchoSessionDao(super.db);

  // ignore: prefer_const_constructors — Uuid() is not const
  static final Uuid _uuid = Uuid();

  EchoSessionRow _newSession({
    required String targetType,
    required String targetId,
    String language = 'und',
    String? transcriptId,
    String? secondaryTranscriptId,
  }) {
    final now = DateTime.now();
    return EchoSessionRow(
      id: _uuid.v4(),
      targetType: targetType,
      targetId: targetId,
      language: language,
      currentTimeMs: 0,
      playbackRate: 1,
      volume: 1,
      echoStartMs: null,
      echoEndMs: null,
      transcriptId: transcriptId,
      secondaryTranscriptId: secondaryTranscriptId,
      recordingsCount: 0,
      recordingsDurationMs: 0,
      lastRecordingAt: null,
      currentSegmentIndex: -1,
      echoActive: false,
      echoStartLine: -1,
      echoEndLine: -1,
      blurActive: false,
      startedAt: now,
      lastActiveAt: now,
      completedAt: null,
      syncStatus: null,
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<EchoSessionRow> getOrCreateLatestForTarget(
    String targetType,
    String targetId,
  ) async {
    final existing = await getLatestForTarget(targetType, targetId);
    if (existing != null) return existing;
    final row = _newSession(targetType: targetType, targetId: targetId);
    await into(echoSessions).insert(row);
    return row;
  }

  Future<EchoSessionRow?> getLatestForTarget(
    String targetType,
    String targetId,
  ) =>
      (select(echoSessions)
            ..where(
              (t) =>
                  t.targetType.equals(targetType) & t.targetId.equals(targetId),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.lastActiveAt)])
            ..limit(1))
          .getSingleOrNull();

  Stream<EchoSessionRow?> watchLatestForTarget(
    String targetType,
    String targetId,
  ) =>
      (select(echoSessions)
            ..where(
              (t) =>
                  t.targetType.equals(targetType) & t.targetId.equals(targetId),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.lastActiveAt)])
            ..limit(1))
          .watch()
          .map((rows) => rows.isEmpty ? null : rows.first);

  Future<void> upsert(EchoSessionRow row) =>
      into(echoSessions).insert(row, mode: InsertMode.insertOrReplace);

  Future<void> updatePrimaryTranscriptForTarget(
    String targetType,
    String targetId,
    String? transcriptId,
  ) async {
    final latest = await getLatestForTarget(targetType, targetId);
    final now = DateTime.now();
    if (latest == null) {
      await into(echoSessions).insert(
        _newSession(
          targetType: targetType,
          targetId: targetId,
          transcriptId: transcriptId,
        ),
      );
    } else {
      await (update(echoSessions)..where((t) => t.id.equals(latest.id))).write(
        EchoSessionsCompanion(
          transcriptId: Value(transcriptId),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> updateSecondaryTranscriptForTarget(
    String targetType,
    String targetId,
    String? secondaryTranscriptId,
  ) async {
    final latest = await getLatestForTarget(targetType, targetId);
    final now = DateTime.now();
    if (latest == null) {
      await into(echoSessions).insert(
        _newSession(
          targetType: targetType,
          targetId: targetId,
          secondaryTranscriptId: secondaryTranscriptId,
        ),
      );
    } else {
      await (update(echoSessions)..where((t) => t.id.equals(latest.id))).write(
        EchoSessionsCompanion(
          secondaryTranscriptId: Value(secondaryTranscriptId),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Most recently active sessions across all targets (Home Continue lookback).
  Future<List<EchoSessionRow>> listRecentByLastActiveAt({int limit = 20}) {
    return (select(echoSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.lastActiveAt)])
          ..limit(limit))
        .get();
  }

  /// Watch counterpart of [listRecentByLastActiveAt].
  Stream<List<EchoSessionRow>> watchRecentByLastActiveAt({int limit = 20}) {
    return (select(echoSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.lastActiveAt)])
          ..limit(limit))
        .watch();
  }

  Future<({int sessionCount, int recordingsDurationMs})> practiceTotals() {
    return customSelect(
          'SELECT COUNT(*) AS c, COALESCE(SUM(recordings_duration_ms), 0) AS d '
          'FROM echo_sessions',
          readsFrom: {echoSessions},
        )
        .map(
          (row) => (
            sessionCount: row.read<int>('c'),
            recordingsDurationMs: row.read<int>('d'),
          ),
        )
        .getSingle();
  }
}
