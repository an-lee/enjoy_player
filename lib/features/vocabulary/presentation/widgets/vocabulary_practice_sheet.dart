/// In-tree practice panel for clip play and echo reading (not a navigator modal).
///
/// Clip mode claims the permanent RootShell [PlayerSurfaceHost] target; Echo
/// is recorder-only and never attaches a video surface.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_media.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_review_practice.dart';
import 'package:enjoy_player/features/vocabulary/presentation/widgets/vocabulary_practice_clip_body.dart';
import 'package:enjoy_player/features/vocabulary/presentation/widgets/vocabulary_practice_echo_body.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Modal-looking practice chrome stacked over the flashcard (same route).
class VocabularyPracticeOverlay extends ConsumerWidget {
  const VocabularyPracticeOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vocabularyReviewSessionProvider);
    if (!session.practiceSheetOpen) return const SizedBox.shrink();

    final t = EnjoyThemeTokens.of(context);
    final wide =
        MediaQuery.sizeOf(context).width >=
        EnjoyThemeTokens.of(context).breakpointCompact;

    return Stack(
      fit: StackFit.expand,
      children: [
        ModalBarrier(
          dismissible: true,
          color: enjoyModalBarrierColor(context),
          onDismiss: () {
            unawaited(
              ref
                  .read(vocabularyReviewSessionProvider.notifier)
                  .clearPractice(),
            );
          },
        ),
        Align(
          alignment: wide ? Alignment.center : Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: wide
                    ? EnjoyThemeTokens.of(context).modalMaxWidthLarge
                    : double.infinity,
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: Padding(
                padding: wide ? EdgeInsets.all(t.space24) : EdgeInsets.zero,
                child: const VocabularyPracticeSheet(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class VocabularyPracticeSheet extends ConsumerWidget {
  const VocabularyPracticeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final session = ref.watch(vocabularyReviewSessionProvider);
    final mode = session.practiceMode;
    final item = session.currentItem;
    final ctx = session.currentPrimaryContext;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final wide = MediaQuery.sizeOf(context).width >= t.breakpointCompact;

    final title = mode == ReviewPracticeMode.echo
        ? l10n.vocabularyEchoReading
        : l10n.vocabularyPlaySegment;

    Widget body;
    if (ctx == null ||
        item == null ||
        !vocabularyContextSupportsMediaActions(ctx) ||
        mode == ReviewPracticeMode.none) {
      body = Padding(
        padding: EdgeInsets.all(t.space16),
        child: Text(
          l10n.vocabularyMediaUnavailable,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    } else if (mode == ReviewPracticeMode.echo) {
      body = VocabularyPracticeEchoBody(
        contextItem: ctx,
        language: item.language,
        word: item.word,
      );
    } else {
      final window = mediaLocatorWindow(ctx.locator!);
      body = VocabularyPracticeClipBody(
        startSec: window.startSec,
        endSec: window.endSec,
      );
    }

    return Material(
      color: cs.surfaceContainerHigh,
      elevation: wide ? 6 : 0,
      borderRadius: wide
          ? BorderRadius.circular(t.radiusXl)
          : BorderRadius.vertical(top: Radius.circular(t.radiusXl)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              t.space16,
              t.space12,
              t.space16,
              t.space16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!wide)
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(t.radiusFull),
                      ),
                    ),
                  ),
                if (!wide) SizedBox(height: t.space12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                      ),
                    ),
                    EnjoyTappableIcon(
                      icon: Icons.close_rounded,
                      tooltip: l10n.vocabularyPracticeDismiss,
                      onPressed: () {
                        unawaited(
                          ref
                              .read(vocabularyReviewSessionProvider.notifier)
                              .clearPractice(),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: t.space12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                  ),
                  child: SingleChildScrollView(child: body),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
