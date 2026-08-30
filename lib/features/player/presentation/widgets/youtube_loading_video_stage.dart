/// 16:9 portal target + poster while YouTube [openMedia] is in flight.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/features/player/application/player_engine_provider.dart';
import 'package:enjoy_player/features/player/application/player_surface_registry.dart';
import 'package:enjoy_player/features/player/application/youtube_open_preview_provider.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_loading_stage.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_video_poster.dart';

class YoutubeLoadingVideoStage extends ConsumerStatefulWidget {
  const YoutubeLoadingVideoStage({
    required this.mediaId,
    this.overlayBuilder,
    super.key,
  });

  final String mediaId;
  final PlayerSurfaceOverlayBuilder? overlayBuilder;

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
      final metadata = engine.metadata;
      // Poster plumbing is a capability (issue #664) — an engine without one
      // renders decoded frames and has nothing to preload.
      if (metadata == null) return;
      metadata.setPosterUrl(_lastPosterUrl);
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
    // pattern as the local loading stage. WebView visibility is gated by
    // [YoutubePlayerEngine.shouldMountWebView] inside the surface host.
    final showSurface = isYoutube;

    return PlayerLoadingStage(
      surfaceId: PlayerSurfaceIds.expandedPlayerLoading,
      enabled: showSurface,
      overlayBuilder: widget.overlayBuilder,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          YoutubeVideoPoster(primaryUrl: thumb, visible: true),
        ],
      ),
    );
  }
}
