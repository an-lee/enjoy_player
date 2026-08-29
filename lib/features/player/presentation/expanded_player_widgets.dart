/// Scaffold bodies for [ExpandedPlayerScreen] (loading, error, main chrome).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/theme/widgets/app_background.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';
import 'package:enjoy_player/features/player/application/player_collapse.dart';
import 'package:enjoy_player/features/player/application/player_engine_provider.dart';
import 'package:enjoy_player/features/player/application/player_preferences_provider.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/presentation/layouts/audio_player_layout.dart';
import 'package:enjoy_player/features/player/presentation/layouts/video_player_layout.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import 'package:enjoy_player/features/player/application/player_surface_registry.dart';
import 'package:enjoy_player/features/player/application/youtube_open_preview_provider.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_frosted_back_button.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_surface_target.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_loading_video_stage.dart';

import 'package:enjoy_player/features/transcript/presentation/transcript_panel.dart';

/// Centered loading indicator while [openMediaActionProvider] resolves.
class ExpandedPlayerLoadingBody extends ConsumerWidget {
  const ExpandedPlayerLoadingBody({
    super.key,
    required this.colorScheme,
    required this.mediaId,
  });

  final ColorScheme colorScheme;
  final String mediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(youtubeOpenPreviewProvider(mediaId));
    final isYoutube = preview.maybeWhen(
      data: (p) => p != null,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (isYoutube)
            Align(
              alignment: Alignment.topCenter,
              child: YoutubeLoadingVideoStage(
                mediaId: mediaId,
                overlayBuilder: (_) =>
                    const _VideoCollapseOnlyOverlay(useSafeArea: false),
              ),
            )
          else
            // Claim the chrome viewport during open (ADR-0057) so Video is
            // not unmounted for the whole resolve → open window.
            const Align(
              alignment: Alignment.topCenter,
              child: _LocalLoadingVideoStage(),
            ),
          if (!isYoutube)
            const Align(
              alignment: Alignment.topCenter,
              child: _VideoCollapseOnlyOverlay(),
            ),
        ],
      ),
    );
  }
}

/// 16:9 portal target while local / URL [openMedia] is in flight.
class _LocalLoadingVideoStage extends StatelessWidget {
  const _LocalLoadingVideoStage();

  static const double aspectWidth = 16;
  static const double aspectHeight = 9;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      left: false,
      right: false,
      child: AspectRatio(
        aspectRatio: aspectWidth / aspectHeight,
        child: PlayerSurfaceTarget(
          // Share the chrome viewport id so loading → player does not park
          // (unmount) the media_kit Texture. A distinct id raced detach/attach
          // and left ~1s of picture then a black stage until resize.
          id: PlayerSurfaceIds.expandedPlayer,
          overlayBuilder: (_) => const SizedBox.shrink(),
          child: const ColoredBox(
            color: Colors.black,
            child: Center(child: SkeletonAppBootstrap()),
          ),
        ),
      ),
    );
  }
}

/// Non-relocate open failure (generic message; no raw exception text).
class ExpandedPlayerGenericErrorBody extends StatelessWidget {
  const ExpandedPlayerGenericErrorBody({super.key, required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.playerOpenGenericError, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// YouTube open on an opted-out platform (ADR-0048): localized "coming soon"
/// notice instead of the generic failure body.
class ExpandedPlayerYoutubeUnavailableBody extends StatelessWidget {
  const ExpandedPlayerYoutubeUnavailableBody({
    super.key,
    required this.colorScheme,
  });

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.youtubeLinuxUnavailable,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // The user is stranded without a way back otherwise — mirror the
          // loading body's collapse-only chrome.
          const Align(
            alignment: Alignment.topCenter,
            child: _VideoCollapseOnlyOverlay(),
          ),
        ],
      ),
    );
  }
}

/// Main expanded player: AppBar + ambient backdrop + video/audio layout.
class ExpandedPlayerChromeBody extends ConsumerWidget {
  const ExpandedPlayerChromeBody({
    super.key,
    required this.mediaId,
    required this.chrome,
    required this.accent,
  });

  final String mediaId;
  final PlaybackChrome chrome;
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = chrome.mediaType == 'video';
    final engine = ref.read(playerEngineProvider);
    final splitPx = ref.watch(
      playerPreferencesCtrlProvider.select(
        (p) => p.videoTranscriptSplitWidthPx,
      ),
    );
    final transcript = TranscriptPanel(mediaId: mediaId);

    final mediaBody = isVideo
        ? VideoPlayerLayout(
            engine: engine,
            transcript: transcript,
            initialTranscriptSplitWidthPx: splitPx,
            onTranscriptSplitWidthCommitted: (w) => ref
                .read(playerPreferencesCtrlProvider.notifier)
                .setVideoTranscriptSplitWidthPx(w),
          )
        : AudioPlayerLayout(transcript: transcript);

    // Lift ambient tint around the Scaffold so audio collapse chrome and
    // transcript share one backdrop (transparent scaffold).
    return PlayerAmbientBackdrop(
      accentColor: accent,
      intensity: 0.08,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Video only: body draws under overlay chrome so the 16:9 stage does
        // not jump on play/pause. Audio has no AppBar — collapse lives in
        // [AudioPlayerLayout] as a compact top-left chevron (ADR-0077).
        extendBodyBehindAppBar: isVideo,
        appBar: null,
        body: mediaBody,
      ),
    );
  }
}

/// Collapse control only (loading / minimal chrome).
class _VideoCollapseOnlyOverlay extends ConsumerWidget {
  const _VideoCollapseOnlyOverlay({this.useSafeArea = true});

  final bool useSafeArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = SizedBox(
      height: kToolbarHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: PlayerFrostedBackButton(
            onPressed: () => unawaited(collapseExpandedPlayer(ref, context)),
          ),
        ),
      ),
    );
    if (!useSafeArea) return content;
    return SafeArea(bottom: false, left: false, right: false, child: content);
  }
}
