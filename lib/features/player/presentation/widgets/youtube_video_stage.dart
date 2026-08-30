/// YouTube half of the surface host slot: WebView host + poster overlays.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/platform/linux_platform_availability.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_player_engine.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_host.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_video_poster.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Video stage mounted for a [YoutubePlayerEngine].
///
/// Moved out of the engine (issue #664): an application service must not build
/// widgets. The engine publishes the non-widget inputs this stage reads —
/// [YoutubePlayerEngine.session] and [YoutubePlayerEngine.webViewLifecycle] —
/// and is told about stage layout through
/// [YoutubePlayerEngine.noteStageViewportSize] so the focus policy stays with
/// the transport code.
class YoutubeVideoStage extends StatelessWidget {
  const YoutubeVideoStage({
    super.key,
    required this.engine,
    required this.maxWidth,
    required this.maxHeight,
  });

  final YoutubePlayerEngine engine;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (maxWidth <= 0 || maxHeight <= 0) {
      return const SizedBox.shrink();
    }
    engine.noteStageViewportSize(width: maxWidth, height: maxHeight);

    final session = engine.session;
    return StreamBuilder<bool>(
      stream: engine.buffering,
      initialData: session.buffering,
      builder: (context, snapshot) {
        final bufferingNow = snapshot.data ?? session.buffering;
        // The poster is a "playback never started" affordance, not a
        // buffering one (issue #662): keyed to the session's first-playing
        // latch, so a mid-playback `waiting` no longer fades the static
        // thumbnail OVER the live frame. A stall after playback has started
        // gets the small spinner instead.
        final posterVisible = bufferingNow && !session.loggedFirstPlaying;
        final showSpinner = bufferingNow && session.loggedFirstPlaying;
        return ValueListenableBuilder<int>(
          valueListenable: session.mountTick,
          builder: (context, _, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                // ADR-0048: on opted-out platforms the host must never mount
                // (defense in depth — mount requests are gated too, but the
                // InAppWebView constructor itself asserts without a backend).
                if (!youTubeEngineOptedOutHere && session.shouldMountWebView)
                  _webViewHost(),
                if (session.tapToPlayHintActive && !posterVisible)
                  _YoutubeTapToPlayHint(
                    label:
                        AppLocalizations.of(context)?.youtubeTapToPlayHint ??
                        'Tap to play',
                  ),
                YoutubeVideoPoster(
                  primaryUrl: session.posterUrl,
                  visible: posterVisible,
                ),
                if (showSpinner) const _YoutubeBufferingIndicator(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _webViewHost() {
    return YoutubeWebViewHost(
      key: engine.session.webViewHostKey,
      controller: engine.webViewLifecycle,
      currentVideoId: () => engine.session.videoId,
    );
  }
}

class _YoutubeTapToPlayHint extends StatelessWidget {
  const _YoutubeTapToPlayHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    // IgnorePointer: empty regions must still reach the WebView so a real
    // user gesture can satisfy platform autoplay policy.
    return IgnorePointer(
      ignoring: true,
      child: ColoredBox(
        color: Colors.black45,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Colors.white70,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mid-playback buffering affordance (issue #662).
///
/// The poster used to be the only buffering overlay, which meant every
/// `waiting` after playback had started faded a static thumbnail over the
/// live frame. Once playback has started the stall is signalled with this
/// instead: a small spinner on a light scrim, never covering the video.
class _YoutubeBufferingIndicator extends StatelessWidget {
  const _YoutubeBufferingIndicator();

  @override
  Widget build(BuildContext context) {
    // IgnorePointer: a stall must stay tappable (pause / seek) like any
    // other moment of playback.
    return const IgnorePointer(
      ignoring: true,
      child: ColoredBox(
        color: Colors.black26,
        child: Center(
          child: SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
