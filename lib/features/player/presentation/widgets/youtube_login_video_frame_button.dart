/// YouTube account control overlaid on the video stage (not the app chrome).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/features/player/application/player_engine_capabilities_provider.dart';
import 'package:enjoy_player/features/player/application/youtube_auth_provider.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class YoutubeLoginVideoFrameButton extends ConsumerWidget {
  const YoutubeLoginVideoFrameButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(playerYoutubeLoginChromeSupportedProvider)) {
      return const SizedBox.shrink();
    }

    final signedIn = ref.watch(youtubeLoginStateProvider).value ?? false;
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        tooltip: l10n.youtubeLoginTooltip,
        icon: Icon(
          signedIn ? Icons.person_rounded : Icons.person_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => context.push('/youtube/login'),
      ),
    );
  }
}
