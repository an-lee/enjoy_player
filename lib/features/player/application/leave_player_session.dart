/// Leave-player policy: stop live playback off `/player/` (spec 044).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';

/// Whether a live [PlayerController] session should be cleared for [path].
bool shouldClearLiveSessionOnRouteChange({
  required bool onPlayerRoute,
  required bool hasLiveSession,
  required bool practiceOwnsVideoStage,
}) {
  return hasLiveSession && !onPlayerRoute && !practiceOwnsVideoStage;
}

/// Flushes and [PlayerController.clear]s when the learner left the player.
Future<void> clearLivePlaybackSessionIfNeeded(
  WidgetRef ref, {
  required bool onPlayerRoute,
}) async {
  final hasLiveSession = ref.read(playerControllerProvider) != null;
  final practiceOwnsVideoStage = ref
      .read(vocabularyReviewSessionProvider)
      .practiceOwnsVideoStage;
  if (!shouldClearLiveSessionOnRouteChange(
    onPlayerRoute: onPlayerRoute,
    hasLiveSession: hasLiveSession,
    practiceOwnsVideoStage: practiceOwnsVideoStage,
  )) {
    return;
  }
  await ref.read(playerControllerProvider.notifier).clear();
}
