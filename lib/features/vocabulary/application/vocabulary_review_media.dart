/// Media clip helpers for vocabulary review (single Player).
library;

import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/domain/open_media_options.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';

/// Time window for a [MediaLocator] in seconds.
typedef MediaClipWindow = ({double startSec, double endSec});

MediaClipWindow mediaLocatorWindow(MediaLocator locator) {
  final startSec = locator.start / 1000.0;
  final endSec = (locator.start + locator.duration) / 1000.0;
  return (startSec: startSec, endSec: endSec);
}

bool vocabularyContextSupportsMediaActions(VocabularyContext context) {
  if (context.sourceType == VocabularySourceType.ebook) return false;
  final locator = context.locator;
  if (locator == null || locator.duration <= 0) return false;
  if (context.sourceId.isEmpty) return false;
  return context.sourceType == VocabularySourceType.video ||
      context.sourceType == VocabularySourceType.audio;
}

/// Open → await surface → seek → activate bounded clip → optionally play.
///
/// Uses [OpenMediaOptions.explicitLaunch] so a restored lesson position cannot
/// race [EchoEnforcer] before the clip seek lands.
Future<void> openVocabularyClipWindow({
  required PlayerController player,
  required EchoMode echo,
  required String mediaId,
  required double startSec,
  required double endSec,
  required bool playAfter,
}) async {
  echo.deactivate();
  await player.openMedia(mediaId, options: OpenMediaOptions.explicitLaunch);

  await player.activeEngine.awaitSurfaceReady();

  await player.seekToSeconds(startSec);

  echo.activate(
    startLineIndex: -1,
    endLineIndex: -1,
    startTimeSeconds: startSec,
    endTimeSeconds: endSec,
  );

  if (playAfter) {
    await player.play();
  } else {
    try {
      await player.activeEngine.pause();
    } catch (_) {}
  }
}

/// Plays the active context clip through the shared [PlayerController].
Future<void> playVocabularyClip({
  required PlayerController player,
  required EchoMode echo,
  required VocabularyContext context,
}) async {
  if (!vocabularyContextSupportsMediaActions(context)) {
    throw StateError('Context does not support clip playback');
  }
  final window = mediaLocatorWindow(context.locator!);
  await openVocabularyClipWindow(
    player: player,
    echo: echo,
    mediaId: context.sourceId,
    startSec: window.startSec,
    endSec: window.endSec,
    playAfter: true,
  );
}
