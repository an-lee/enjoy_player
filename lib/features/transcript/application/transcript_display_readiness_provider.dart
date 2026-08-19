/// Riverpod wrappers for karaoke / IPA / enrich gating.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/media_target_resolver.dart';
import 'package:enjoy_player/data/subtitle/transcript_display_readiness.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';

part 'transcript_display_readiness_provider.g.dart';

/// True when this item is owned media (local file or the user's cloud URL).
///
/// Karaoke may use stored word clocks. YouTube stays false.
@riverpod
Future<bool> canTrustWordTimes(Ref ref, String mediaId) async {
  final db = ref.watch(appDatabaseProvider);
  final source = await resolvePlayableSource(db, mediaId);
  return source is LocalFilePlayableSource || source is RemoteUrlPlayableSource;
}

/// Unresolved trust (provider still loading) is treated as owned so
/// cloud-library nested-but-incomplete tracks keep the enrich tile and
/// owned copy. YouTube flips to false once the row resolves. Karaoke stays
/// off until trust is known and [hasTimedWords] is true.
@riverpod
TranscriptDisplayReadiness transcriptDisplayReadinessForMedia(
  Ref ref,
  String mediaId,
) {
  final lines =
      ref.watch(transcriptLinesForMediaProvider(mediaId)).value ?? const [];
  final trustAsync = ref.watch(canTrustWordTimesProvider(mediaId));
  final canTrust = trustAsync.hasError ? false : (trustAsync.value ?? true);
  return transcriptDisplayReadiness(
    lines: lines,
    canTrustWordTimes: canTrust,
    trustResolved: trustAsync.hasValue || trustAsync.hasError,
  );
}
