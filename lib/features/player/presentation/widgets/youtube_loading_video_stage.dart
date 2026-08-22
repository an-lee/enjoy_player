/// 16:9 portal target + poster while YouTube [openMedia] is in flight.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/features/player/application/player_engine_provider.dart';
import 'package:enjoy_player/features/player/application/player_surface_registry.dart';
import 'package:enjoy_player/features/player/application/youtube_open_preview_provider.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_surface_target.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_video_poster.dart';

class YoutubeLoadingVideoStage extends ConsumerStatefulWidget {
  const YoutubeLoadingVideoStage({
    required this.mediaId,
    this.overlayBuilder,
    super.key,
  });

  final String mediaId;
  final PlayerSurfaceOverlayBuilder? overlayBuilder;

  static const double aspectWidth = 16;
  static const double aspectHeight = 9;

  @override
  ConsumerState<YoutubeLoadingVideoStage> createState() =>
      _YoutubeLoadingVideoStageState();
}

class _YoutubeLoadingVideoStageState
    extends ConsumerState<YoutubeLoadingVideoStage> {
  String? _lastPosterUrl;
  bool _attachScheduled = false;

  void _scheduleAttach(String? thumb) {
    if (_lastPosterUrl != thumb) {
      // Poster is a plain field — safe to update outside the build callback
      // body as soon as we know the value, but keep it in the post-frame
      // path so build stays side-effect free.
      _lastPosterUrl = thumb;
    }
    if (_attachScheduled) return;
    _attachScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachScheduled = false;
      if (!mounted) return;
      final engine = ref.read(playerEngineProvider);
      if (!engine.supportsYouTubePlayback) return;
      engine.setPosterUrl(_lastPosterUrl);
      // warmVideoSurface is idempotent + build-safe; still never call from
      // build.
      engine.warmVideoSurface();
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(youtubeOpenPreviewProvider(widget.mediaId));
    final engine = ref.watch(playerEngineProvider);
    final isYoutube = engine.supportsYouTubePlayback;

    final thumb = preview.maybeWhen(
      data: (p) => p?.thumbnailUrl,
      orElse: () => null,
    );

    if (isYoutube) {
      _scheduleAttach(thumb);
    }

    // Claim the loading portal whenever a YouTube engine is active — same
    // pattern as [_LocalLoadingVideoStage]. WebView visibility is gated by
    // [YoutubePlayerEngine.shouldMountWebView] inside the surface host.
    final showSurface = isYoutube;

    return SafeArea(
      top: true,
      bottom: false,
      left: false,
      right: false,
      child: AspectRatio(
        aspectRatio:
            YoutubeLoadingVideoStage.aspectWidth /
            YoutubeLoadingVideoStage.aspectHeight,
        child: PlayerSurfaceTarget(
          id: PlayerSurfaceIds.expandedPlayerLoading,
          enabled: showSurface,
          overlayBuilder: widget.overlayBuilder,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              YoutubeVideoPoster(primaryUrl: thumb, visible: true),
            ],
          ),
        ),
      ),
    );
  }
}
