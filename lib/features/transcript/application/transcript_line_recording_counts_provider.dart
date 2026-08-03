/// Per-line shadow-reading recording counts for transcript UI.
library;

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/dexie_target_type_provider.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/sync/application/recordings_for_target_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_recording_counts.dart';

part 'transcript_line_recording_counts_provider.g.dart';

final _log = logNamed('TranscriptLineRecordingCounts');

/// Combines async transcript/recording inputs into per-line counts.
///
/// Returns `null` while any dependency is still loading.
/// Returns `{}` when loaded but nothing overlaps or when a dependency fails.
Map<int, int>? resolveTranscriptLineRecordingCounts({
  required AsyncValue<List<TranscriptLine>> linesAsync,
  required AsyncValue<String?> targetTypeAsync,
  required AsyncValue<List<RecordingRow>> recordingsAsync,
  required String mediaId,
  Logger? log,
}) {
  final logger = log ?? _log;

  if (linesAsync.isLoading) return null;
  if (linesAsync.hasError) {
    logger.warning(
      'Transcript lines unavailable for recording counts ($mediaId)',
      linesAsync.error,
      linesAsync.stackTrace,
    );
    return const {};
  }

  final lines = linesAsync.requireValue;
  if (lines.isEmpty) return const {};

  if (targetTypeAsync.isLoading) return null;
  if (targetTypeAsync.hasError) {
    logger.warning(
      'Target type unavailable for recording counts ($mediaId)',
      targetTypeAsync.error,
      targetTypeAsync.stackTrace,
    );
    return const {};
  }

  final tt = targetTypeAsync.requireValue;
  if (tt == null) return const {};

  if (recordingsAsync.isLoading) return null;
  if (recordingsAsync.hasError) {
    logger.warning(
      'Recordings unavailable for transcript line counts ($mediaId)',
      recordingsAsync.error,
      recordingsAsync.stackTrace,
    );
    return const {};
  }

  return countRecordingsPerLineIndex(lines, recordingsAsync.requireValue);
}

/// Map of transcript line index → overlapping recording count for [mediaId].
@riverpod
Map<int, int>? transcriptLineRecordingCounts(Ref ref, String mediaId) {
  if (mediaId.isEmpty) return const {};

  final linesAsync = ref.watch(transcriptLinesForMediaProvider(mediaId));
  final targetTypeAsync = ref.watch(dexieTargetTypeForMediaProvider(mediaId));

  final AsyncValue<List<RecordingRow>> recordingsAsync;
  final tt = targetTypeAsync.value;
  if (tt != null) {
    recordingsAsync = ref.watch(
      recordingsForTargetProvider((targetType: tt, targetId: mediaId)),
    );
  } else if (targetTypeAsync.isLoading) {
    recordingsAsync = const AsyncLoading();
  } else {
    recordingsAsync = const AsyncData([]);
  }

  return resolveTranscriptLineRecordingCounts(
    linesAsync: linesAsync,
    targetTypeAsync: targetTypeAsync,
    recordingsAsync: recordingsAsync,
    mediaId: mediaId,
  );
}
