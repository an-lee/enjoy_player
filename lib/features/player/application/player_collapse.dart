/// Collapse expanded player chrome and pop the player route.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/window/window_fullscreen_provider.dart';
import 'package:enjoy_player/features/player/application/leave_player_session.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_ui_provider.dart';

Future<void> collapseExpandedPlayer(WidgetRef ref, BuildContext context) async {
  // Pop BEFORE the teardown awaits. clear() nulls the session mid-flight,
  // which rebuilds the player page into its loading placeholder and swaps the
  // permanent surface overlay that hosts the collapse control — the calling
  // context is deactivated, so the old `if (context.mounted) context.pop()`
  // silently skipped the pop and stranded the learner on the placeholder
  // (only the system back gesture could leave). Popping first also keeps the
  // chrome body mounted for the whole reverse transition instead of flashing
  // the placeholder while the engine tears down.
  final router = GoRouter.of(context);
  // Guard against a second tap (or hotkey) while the first pop's transition
  // is still running: the overlay control stays mounted during it.
  if (router.state.uri.path.startsWith('/player/')) {
    router.pop();
  }
  await ref.read(windowFullscreenProvider.notifier).setFullscreen(false);
  ref.read(playerUiProvider.notifier).collapse();
  if (ref.read(playerControllerProvider) == null) {
    ref.read(playerControllerProvider.notifier).abandonPendingOpen();
  } else {
    await clearLivePlaybackSessionIfNeeded(ref, onPlayerRoute: false);
  }
}
