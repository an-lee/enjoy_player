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

      await player.activeEngine.awaitSurfaceReady();

      final start = request.startSec;
      if (start != null) {
        await player.seekToSeconds(start);
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
        await player.play();
      }
    }, retry: null);
