/// Clip mini-player body for the vocabulary practice sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_state_providers.dart';
import 'package:enjoy_player/features/player/application/player_surface_registry.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_surface_target.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_video_poster.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_review_practice.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class VocabularyPracticeClipBody extends ConsumerWidget {
  const VocabularyPracticeClipBody({
    super.key,
    required this.startSec,
    required this.endSec,
  });

  final double startSec;
  final double endSec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final phase = ref.watch(
      vocabularyReviewSessionProvider.select((s) => s.practicePhase),
    );
    final player = ref.watch(playerControllerProvider.notifier);
    final session = ref.watch(playerControllerProvider);
    // Avoid watching transport streams when no session is open (test / opening).
    final playing = session == null
        ? false
        : (ref.watch(playerIsPlayingProvider).value ?? false);
    final mediaError = ref.watch(
      vocabularyReviewSessionProvider.select((s) => s.mediaError),
    );
    final engine = player.ownedEngine;
    final claimSurface = phase == ReviewPracticePhase.clipReady;
    final opening = phase == ReviewPracticePhase.clipOpening;

    final poster = YoutubeVideoPoster(
      primaryUrl: engine?.metadata?.posterUrl ?? session?.thumbnailUrl,
      visible: true,
    );

    Widget underlay;
    if (mediaError != null) {
      underlay = ColoredBox(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(t.space16),
            child: Text(
              l10n.vocabularyMediaOpenFailed,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.error),
            ),
          ),
        ),
      );
    } else if (opening || engine == null) {
      underlay = ColoredBox(
        color: cs.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            poster,
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    } else {
      underlay = ColoredBox(color: cs.surfaceContainerHighest, child: poster);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(t.radiusMd),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: PlayerSurfaceTarget(
              id: PlayerSurfaceIds.vocabularyClip,
              enabled: claimSurface && mediaError == null,
              child: underlay,
            ),
          ),
        ),
        SizedBox(height: t.space12),
        Row(
          children: [
            EnjoyTappableIcon(
              icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              tooltip: playing
                  ? l10n.vocabularyPracticePause
                  : l10n.vocabularyPlaySegment,
              onPressed: (!claimSurface || mediaError != null)
                  ? null
                  : () => ref
                        .read(playerControllerProvider.notifier)
                        .togglePlay(),
            ),
            SizedBox(width: t.space8),
            Expanded(
              child: Text(
                l10n.vocabularyLocatorLabel(
                  startSec.toStringAsFixed(1),
                  (endSec - startSec).toStringAsFixed(1),
                ),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
