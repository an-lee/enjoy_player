/// Highlighted transcript cue + karaoke word index for the active playback
/// position.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/subtitle/current_transcript_word.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/transcript/application/transcript_display_readiness_provider.dart';

import '../../player/application/display_position_provider.dart';
import '../../player/application/echo_mode_provider.dart';
import 'karaoke_position_provider.dart';
import 'transcript_cue_selection.dart';
import 'transcript_lines_provider.dart';

part 'transcript_playback_highlight_provider.g.dart';

/// Echo-aware active cue index plus the karaoke word index on that cue.
typedef TranscriptPlaybackHighlight = ({int cueIndex, int? wordIndex});

/// Current cue index (echo-aware) and karaoke current-word index.
///
/// `cueIndex` is `-1` when there are no lines. `wordIndex` is null when
/// karaoke is off / still loading, `karaokeSwitchEnabled` is false (no timed
/// words on owned media), the cue is out of range, or the position is in a
/// gap.
///
/// The 50 ms karaoke position stream is watched **only after** the karaoke
/// gate passes, so karaoke-off transcripts never subscribe to the word tick
/// stream. Consumers that only need the cue index must use
/// `.select((h) => h.cueIndex)` (or select on a listener) so they are not
/// rebuilt on the 50 ms word ticks; only the active transcript tile should
/// watch the full record.
@riverpod
TranscriptPlaybackHighlight transcriptPlaybackHighlight(
  Ref ref,
  String mediaId,
) {
  final linesAsync = ref.watch(transcriptLinesForMediaProvider(mediaId));
  final lines = linesAsync.value ?? [];
  final echo = ref.watch(echoModeProvider);
  final posAsync = ref.watch(displayPositionProvider);
  final timeSec = switch (posAsync) {
    AsyncData(:final value) => value.inMilliseconds / 1000.0,
    _ => 0.0,
  };
  final cueIndex = lines.isEmpty
      ? -1
      : transcriptActiveIndexForEchoUi(
          echo,
          transcriptActiveIndex(lines, timeSec),
        );
  if (cueIndex < 0) {
    return (cueIndex: cueIndex, wordIndex: null);
  }

  final enabled = ref.watch(karaokeHighlightSettingsProvider).value;
  if (enabled != true) return (cueIndex: cueIndex, wordIndex: null);
  final readiness = ref.watch(
    transcriptDisplayReadinessForMediaProvider(mediaId),
  );
  if (!readiness.karaokeSwitchEnabled) {
    return (cueIndex: cueIndex, wordIndex: null);
  }
  final karaokePos = ref.watch(karaokePositionProvider);
  final positionMs = switch (karaokePos) {
    AsyncData(:final value) => value.inMilliseconds,
    _ => null,
  };
  if (positionMs == null) return (cueIndex: cueIndex, wordIndex: null);
  return (
    cueIndex: cueIndex,
    wordIndex: currentWordIndex(lines[cueIndex], positionMs),
  );
}
