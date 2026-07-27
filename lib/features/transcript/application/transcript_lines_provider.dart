/// Reactive subtitle lines for the active primary and secondary transcripts.
library;

import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/collections.dart';
import '../../../core/utils/stream_distinct.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/app_database_provider.dart';
import '../../../data/db/media_target_resolver.dart';
import '../../../data/subtitle/transcript_line.dart';
import 'transcript_repository_provider.dart';

Future<List<TranscriptLine>> _computeLines(
  AppDatabase db,
  TranscriptRepository repo,
  String tt,
  String mediaId, {
  required bool primary,
}) async {
  final echo = await db.echoSessionDao.getLatestForTarget(tt, mediaId);
  final id = primary ? echo?.transcriptId : echo?.secondaryTranscriptId;
  if (id == null) return <TranscriptLine>[];
  // Fetch only the active row, not the entire transcript list. Avoids
  // reading every transcript's timeline_json blob on every Drift tick —
  // a frequent no-op tick when an in-active transcript row changes or
  // when echo session aggregates (recordingsCount, lastActiveAt, …) bump.
  final row = await db.transcriptDao.getById(id);
  if (row == null) return <TranscriptLine>[];
  if (row.timelineJson.length > 16 * 1024) {
    await repo.preloadLinesForRow(row);
  }
  return repo.linesForRow(row);
}

Stream<List<TranscriptLine>> _linesForMedia(
  AppDatabase db,
  TranscriptRepository repo,
  String mediaId, {
  required bool primary,
}) {
  return Stream.fromFuture(dexieTargetTypeForId(db, mediaId)).asyncExpand((tt) {
    if (tt == null) {
      return Stream.value(<TranscriptLine>[]);
    }
    return Stream.fromFuture(
      _computeLines(db, repo, tt, mediaId, primary: primary),
    ).asyncExpand((initial) async* {
      yield initial;
      yield* StreamGroup.merge([
        db.echoSessionDao
            .watchLatestForTarget(tt, mediaId)
            .asyncMap(
              (_) => _computeLines(db, repo, tt, mediaId, primary: primary),
            ),
        db.transcriptDao
            .watchAllForTarget(tt, mediaId)
            .asyncMap(
              (_) => _computeLines(db, repo, tt, mediaId, primary: primary),
            ),
      ]).distinctBy(listEquals);
    });
  });
}

/// Lines for the primary (shadow-reading) transcript.
final transcriptLinesForMediaProvider =
    StreamProvider.family<List<TranscriptLine>, String>((ref, mediaId) {
      final db = ref.watch(appDatabaseProvider);
      final repo = ref.watch(transcriptRepositoryProvider);
      return _linesForMedia(db, repo, mediaId, primary: true);
    });

/// Lines for the secondary (translation) transcript.
final secondaryTranscriptLinesForMediaProvider =
    StreamProvider.family<List<TranscriptLine>, String>((ref, mediaId) {
      final db = ref.watch(appDatabaseProvider);
      final repo = ref.watch(transcriptRepositoryProvider);
      return _linesForMedia(db, repo, mediaId, primary: false);
    });

/// Whether the media has any transcript row (cheap; no cue JSON decode).
final transcriptHasLinesForMediaProvider = StreamProvider.family<bool, String>((
  ref,
  mediaId,
) {
  if (mediaId.isEmpty) return Stream.value(false);
  final db = ref.watch(appDatabaseProvider);
  return Stream.fromFuture(dexieTargetTypeForId(db, mediaId)).asyncExpand((tt) {
    if (tt == null) return Stream.value(false);
    return db.transcriptDao.watchExistsForTarget(tt, mediaId);
  });
});
