/// Presentation-facing capabilities of the active [PlayerEngine].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/features/player/application/player_engine_provider.dart';

/// Whether the expanded player should show YouTube account chrome (WebView engine).
final playerYoutubeLoginChromeSupportedProvider = Provider<bool>((ref) {
  final engine = ref.watch(playerEngineProvider);
  return engine.supportsYouTubePlayback;
});
