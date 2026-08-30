/// Declarative open for a route param [mediaId] / [PlayerLaunchRequest].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/domain/open_media_options.dart';
import 'package:enjoy_player/features/player/domain/player_launch_request.dart';

/// Default open (restore last position / echo) for simple `/player/:id` routes.
final openMediaActionProvider = FutureProvider.autoDispose.family<void, String>(
  (ref, mediaId) async {
    await ref.watch(
      openMediaLaunchProvider(PlayerLaunchRequest(mediaId: mediaId)).future,
    );
  },
  // Relocate / missing-file errors are expected UX — do not exponential-retry
  // (Riverpod 3 default) or LocateMediaScreen never settles.
  retry: null,
);

/// Full launch pipeline: open → readiness → optional seek/clip → autoplay.
final openMediaLaunchProvider = FutureProvider.autoDispose
    .family<void, PlayerLaunchRequest>((ref, request) async {
      // Yield so notifier mutations are not attributed to FutureProvider mount.
      await Future<void>.delayed(Duration.zero);

      final player = ref.read(playerControllerProvider.notifier);
      final echo = ref.read(echoModeProvider.notifier);

      if (request.isExplicitLaunch) {
        echo.deactivate();
        await player.openMedia(
          request.mediaId,
          options: OpenMediaOptions.explicitLaunch,
        );
      } else {
        await player.openMedia(request.mediaId);
      }

      // Leaving the player mid-launch runs clearLivePlaybackSessionIfNeeded,
      // whose clear() bumps the open generation. YouTube readiness can block
      // for seconds, so every step after openMedia re-checks and bails instead
      // of driving seek/play into the cleared engine (#654).
      final gen = player.openGeneration;

      await player.activeEngine.awaitSurfaceReady();
      if (player.isOpenStale(gen)) return;

      final start = request.startSec;
      if (start != null) {
        await player.seekToSeconds(start);
        if (player.isOpenStale(gen)) return;
      }

      final end = request.endSec;
      if (request.activateClipWindow && start != null && end != null) {
        echo.activate(
          startLineIndex: -1,
          endLineIndex: -1,
          startTimeSeconds: start,
          endTimeSeconds: end,
        );
      }

      if (request.autoplay) {
        if (player.isOpenStale(gen)) return;
        await player.play();
      }
    }, retry: null);
