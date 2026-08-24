/// Subtitles picker and desktop fullscreen toggle for the transport bar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_chrome_icon.dart';
import 'package:enjoy_player/core/window/desktop_window.dart';
import 'package:enjoy_player/core/window/window_fullscreen_provider.dart';
import 'package:enjoy_player/features/transcript/application/all_transcripts_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_fetch_controller.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_fetch_status.dart';
import 'package:enjoy_player/features/transcript/presentation/subtitle_track_picker_sheet.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class TransportCcButton extends ConsumerWidget {
  const TransportCcButton({super.key, required this.mediaId});

  final String mediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(allTranscriptsForMediaProvider(mediaId));
    final hasTrack = (tracksAsync.value ?? []).isNotEmpty;
    final fetchState = ref.watch(transcriptFetchStatusProvider(mediaId));
    final showSpinner =
        fetchState.status == TranscriptFetchStatus.loading && !hasTrack;
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: l10n.subtitles,
          icon: showSpinner
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : const EnjoyChromeIcon(EnjoyChromeGlyph.cc),
          onPressed: () => showSubtitleTrackPicker(context, ref, mediaId),
        ),
        if (hasTrack)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: t.ccBadge,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class TransportFullscreenButton extends ConsumerWidget {
  const TransportFullscreenButton({super.key, required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // Button is only enabled for video on desktop; hidden otherwise.
    if (!isDesktop || !isVideo) return const SizedBox.shrink();

    final isFullscreen = ref.watch(windowFullscreenProvider);
    final tooltip = isFullscreen
        ? l10n.transportExitFullscreen
        : l10n.transportFullscreen;
    final icon = isFullscreen
        ? const Icon(Icons.fullscreen_exit_rounded)
        : const Icon(Icons.fullscreen_rounded);

    return IconButton(
      tooltip: tooltip,
      icon: icon,
      onPressed: () => ref.read(windowFullscreenProvider.notifier).toggle(),
    );
  }
}
