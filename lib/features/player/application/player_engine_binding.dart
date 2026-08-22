/// Swaps [PlayerEngine] implementation for YouTube vs local/URL (ADR-0015).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/features/player/application/engines/youtube/youtube_player_engine.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine_rev.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';

/// Ensures [_ownedEngine] matches [playable] (YouTube vs MediaKit), bumping
/// [playerEngineRevProvider] when the implementation changes.
///
/// [openGeneration] must match [currentOpenGeneration] before and after each
/// async step so concurrent [openMedia] calls cannot dispose another call's
/// engine mid-flight.
///
/// Per ADR-0057, the permanent [PlayerSurfaceHost] keys its stage by engine
/// identity. We must **swap + bump first** so the host drops the old
/// `buildVideoStage`, then dispose the previous engine — never dispose while
/// the host still mounts that engine's platform view.
///
/// The first local/URL open also installs [MediaKitPlayerEngine] and bumps
/// so [PlayerSurfaceHost] can mount `Video` before decode starts. Creating
/// [VideoController] with no [Video] widget binds a native texture that stays
/// black on Windows/Android until a later layout.
Future<void> ensureEngineForPlayableSource(
  Ref ref, {
  required PlayableSource playable,
  required int openGeneration,
  required int Function() currentOpenGeneration,
  required PlayerEngine? Function() getOwnedEngine,
  required void Function(PlayerEngine? next) setOwnedEngine,
}) async {
  if (ref.read(playerEngineTestDoubleProvider) != null) return;
  if (currentOpenGeneration() != openGeneration) return;

  final wantYt = playable is YoutubePlayableSource;
  final owned = getOwnedEngine();
  final haveYt = owned?.supportsYouTubePlayback ?? false;

  if (owned != null && haveYt == wantYt) return;
  if (currentOpenGeneration() != openGeneration) return;

  final next = wantYt ? YoutubePlayerEngine() : MediaKitPlayerEngine();
  setOwnedEngine(next);
  ref.read(playerEngineRevProvider.notifier).bump();
  // Let PlayerSurfaceHost drop the old ObjectKey stage before teardown.
  await Future<void>.delayed(Duration.zero);
  if (currentOpenGeneration() != openGeneration) {
    await next.dispose();
    return;
  }
  if (owned != null) {
    await owned.dispose();
  }
}
