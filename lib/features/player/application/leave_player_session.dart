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
///
/// Widget-tree entry point (`collapseExpandedPlayer`). Router-side callers —
/// the route observer and the mid-launch safety net in `app_router.dart` —
/// have a provider [Ref] and use [clearLivePlaybackSession].
Future<void> clearLivePlaybackSessionIfNeeded(
  WidgetRef ref, {
  required bool onPlayerRoute,
}) {
  return _clearLiveSession(
    onPlayerRoute: onPlayerRoute,
    hasLiveSession: ref.read(playerControllerProvider) != null,
    practiceOwnsVideoStage: ref
        .read(vocabularyReviewSessionProvider)
        .practiceOwnsVideoStage,
    clear: () => ref.read(playerControllerProvider.notifier).clear(),
  );
}

/// [Ref] variant of [clearLivePlaybackSessionIfNeeded] for teardowns that run
/// outside the widget tree (never on a player route when it is called).
Future<void> clearLivePlaybackSession(Ref ref) {
  return _clearLiveSession(
    onPlayerRoute: false,
    hasLiveSession: ref.read(playerControllerProvider) != null,
    practiceOwnsVideoStage: ref
        .read(vocabularyReviewSessionProvider)
        .practiceOwnsVideoStage,
    clear: () => ref.read(playerControllerProvider.notifier).clear(),
  );
}

Future<void> _clearLiveSession({
  required bool onPlayerRoute,
  required bool hasLiveSession,
  required bool practiceOwnsVideoStage,
  required Future<void> Function() clear,
}) async {
  if (!shouldClearLiveSessionOnRouteChange(
    onPlayerRoute: onPlayerRoute,
    hasLiveSession: hasLiveSession,
    practiceOwnsVideoStage: practiceOwnsVideoStage,
  )) {
    return;
  }
  await clear();
}
