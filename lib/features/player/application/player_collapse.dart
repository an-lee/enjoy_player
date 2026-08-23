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
  await ref.read(windowFullscreenProvider.notifier).setFullscreen(false);
  ref.read(playerUiProvider.notifier).collapse();
  if (ref.read(playerControllerProvider) == null) {
    ref.read(playerControllerProvider.notifier).abandonPendingOpen();
  } else {
    await clearLivePlaybackSessionIfNeeded(ref, onPlayerRoute: false);
  }
  if (context.mounted) context.pop();
}
