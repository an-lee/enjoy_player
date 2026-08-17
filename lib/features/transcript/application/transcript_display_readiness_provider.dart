/// Riverpod wrappers for karaoke / IPA / enrich gating.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/media_target_resolver.dart';
import 'package:enjoy_player/data/subtitle/transcript_display_readiness.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';

part 'transcript_display_readiness_provider.g.dart';

/// True when this item has a trusted local file (karaoke may use word clocks).
@riverpod
Future<bool> canTrustWordTimes(Ref ref, String mediaId) async {
  final db = ref.watch(appDatabaseProvider);
  final source = await resolvePlayableSource(db, mediaId);
  return source is LocalFilePlayableSource;
}

/// Primary-track display capability for [mediaId].
@riverpod
TranscriptDisplayReadiness transcriptDisplayReadinessForMedia(
  Ref ref,
  String mediaId,
) {
  final lines =
      ref.watch(transcriptLinesForMediaProvider(mediaId)).value ?? const [];
  final canTrust = ref.watch(canTrustWordTimesProvider(mediaId)).value ?? false;
  return transcriptDisplayReadiness(lines: lines, canTrustWordTimes: canTrust);
}
