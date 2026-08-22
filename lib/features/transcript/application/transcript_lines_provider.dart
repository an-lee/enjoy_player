/// Reactive subtitle lines for the active primary and secondary transcripts.
///
/// All of the lines orchestration (target-type resolution, active-row-only
/// fetch, size-gated isolate preload, merge + distinct) lives behind
/// `TranscriptRepository.watchPrimaryLines` / `watchSecondaryLines`; these
/// providers only bind the streams to Riverpod.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database_provider.dart';
import '../../../data/db/media_target_resolver.dart';
import '../../../data/subtitle/transcript_line.dart';
import 'transcript_repository_provider.dart';

/// Lines for the primary (shadow-reading) transcript.
final transcriptLinesForMediaProvider =
    StreamProvider.family<List<TranscriptLine>, String>((ref, mediaId) {
      final repo = ref.watch(transcriptRepositoryProvider);
      return repo.watchPrimaryLines(mediaId);
    });

/// Lines for the secondary (translation) transcript.
final secondaryTranscriptLinesForMediaProvider =
    StreamProvider.family<List<TranscriptLine>, String>((ref, mediaId) {
      final repo = ref.watch(transcriptRepositoryProvider);
      return repo.watchSecondaryLines(mediaId);
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
