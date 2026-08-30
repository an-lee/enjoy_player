/// Best-effort YouTube WebView pre-warm before navigating to the player.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/features/player/application/player_controller.dart';

/// Warms the YouTube surface when [provider] names YouTube.
///
/// Previously there was a second `warmYoutubeSurfaceForVideoId` helper for
/// callers that already knew the target was YouTube; it ignored the videoId
/// its name advertised and did exactly this, so it was folded in (issue #668).
/// Call it with `provider: 'youtube'` in that case.
void warmYoutubeSurfaceIfNeeded(WidgetRef ref, {required String? provider}) {
  if (provider?.toLowerCase() != 'youtube') return;
  ref.read(playerControllerProvider.notifier).warmYoutubeSurface();
}
