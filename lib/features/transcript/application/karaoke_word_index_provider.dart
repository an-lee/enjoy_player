/// Current karaoke word index on the active primary cue, or null.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/subtitle/current_transcript_word.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/transcript/application/transcript_display_readiness_provider.dart';

import 'karaoke_position_provider.dart';
import 'transcript_lines_provider.dart';
import 'transcript_playback_highlight_provider.dart';

part 'karaoke_word_index_provider.g.dart';

/// Word index into the current cue's `timeline`, or null when karaoke is off
/// / still loading, the cue is line-only, or position is in a gap.
///
/// Watches [karaokeHighlightSettingsProvider] so a persisted `'true'` is not
/// frozen as off: loading is `null` (no paint yet), then this provider
/// rebuilds when the keep-alive notifier resolves. Inactive tiles must not
/// watch this provider. Also requires [karaokeSwitchEnabled] (timed words on
/// extractable local media) so YouTube / untimed tracks never highlight.
@riverpod
int? karaokeWordIndex(Ref ref, String mediaId) {
  final enabled = ref.watch(karaokeHighlightSettingsProvider).value;
  if (enabled != true) return null;
  final readiness = ref.watch(
    transcriptDisplayReadinessForMediaProvider(mediaId),
  );
  if (!readiness.karaokeSwitchEnabled) return null;
  final lines = ref.watch(transcriptLinesForMediaProvider(mediaId)).value ?? [];
  final cueIndex = ref.watch(transcriptPlaybackHighlightProvider(mediaId));
  if (cueIndex < 0 || cueIndex >= lines.length) return null;
  final posAsync = ref.watch(karaokePositionProvider);
  final positionMs = switch (posAsync) {
    AsyncData(:final value) => value.inMilliseconds,
    _ => null,
  };
  if (positionMs == null) return null;
  return currentWordIndex(lines[cueIndex], positionMs);
}
