/// Current timed-word index on the active primary cue (karaoke or practice).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/subtitle/current_transcript_word.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/settings/application/word_practice_settings.dart';

import 'karaoke_position_provider.dart';
import 'transcript_lines_provider.dart';
import 'transcript_playback_highlight_provider.dart';

part 'active_cue_word_index_provider.g.dart';

/// Word index into the current cue's `timeline`, or null.
///
/// Subscribes to the 50 ms karaoke position stream only when karaoke **or**
/// word-level practice is on. Inactive tiles must not watch this provider.
@riverpod
int? activeCueWordIndex(Ref ref, String mediaId) {
  final karaokeOn = ref.watch(karaokeHighlightSettingsProvider).value == true;
  final practiceOn = ref.watch(wordPracticeSettingsProvider).value == true;
  if (!karaokeOn && !practiceOn) return null;
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
