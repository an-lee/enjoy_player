library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/player/application/player_engine_provider.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class YoutubeOpenInBrowserButton extends ConsumerWidget {
  const YoutubeOpenInBrowserButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(playerEngineProvider);
    final videoId = engine.metadata?.currentVideoId ?? '';
    if (videoId.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        tooltip: l10n.youtubeOpenInBrowser,
        icon: const Icon(Icons.open_in_browser, color: Colors.white, size: 20),
        onPressed: () => _openInBrowser(videoId),
      ),
    );
  }

  static Future<void> _openInBrowser(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      logNamed('yt-open-browser').warning('Could not launch $uri');
    }
  }
}
