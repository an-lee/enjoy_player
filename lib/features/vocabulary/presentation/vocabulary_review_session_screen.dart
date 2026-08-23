/// Fullscreen vocabulary flashcard review session.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/routing/player_navigation.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/typography.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/player/domain/player_launch_request.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_media.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_explanation_codec.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_review_practice.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_flashcard.dart';
import 'package:enjoy_player/features/vocabulary/presentation/widgets/vocabulary_practice_sheet.dart';
import 'package:enjoy_player/features/vocabulary/presentation/widgets/vocabulary_rating_bar.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class VocabularyReviewSessionScreen extends ConsumerStatefulWidget {
  const VocabularyReviewSessionScreen({super.key});

  @override
  ConsumerState<VocabularyReviewSessionScreen> createState() =>
      _VocabularyReviewSessionScreenState();
}

class _VocabularyReviewSessionScreenState
    extends ConsumerState<VocabularyReviewSessionScreen> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = ref.read(vocabularyReviewSessionProvider);
      if (!session.hasActiveSession) {
        context.go('/vocabulary');
        return;
      }
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _exit() {
    // Session clear is owned by GoRoute.onExit for `/vocabulary/review`.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/vocabulary');
    }
  }

  Future<void> _openPractice(ReviewPracticeMode mode) async {
    final notifier = ref.read(vocabularyReviewSessionProvider.notifier);
    if (mode == ReviewPracticeMode.clip) {
      // Mount InAppWebView in-tree first; playing before the stage exists
      // deallocates the Windows WebView and blanks the review route.
      notifier.preparePracticeClip();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await notifier.startPracticeClipPlayback();
    } else if (mode == ReviewPracticeMode.echo) {
      await notifier.openPracticeEcho();
    }
  }

  Future<void> _confirmOpenInPlayer() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showEnjoyAlertDialog<bool>(
      context: context,
      title: Text(l10n.vocabularyOpenInPlayer),
      content: Text(l10n.vocabularyOpenInPlayerDescription),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.vocabularyCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.vocabularyConfirmContinue),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    final ctx = ref.read(vocabularyReviewSessionProvider).currentPrimaryContext;
    if (ctx == null || !vocabularyContextSupportsMediaActions(ctx)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.vocabularyMediaOpenFailed)));
      return;
    }

    final window = mediaLocatorWindow(ctx.locator!);
    // Single replace — review onExit clears the session. Do not pop first
    // (that unmounts this State and used to abort navigation → mini-bar only).
    replacePlayerLaunch(
      context,
      PlayerLaunchRequest.vocabularyOpenSource(
        mediaId: ctx.sourceId,
        startSec: window.startSec,
        endSec: window.endSec,
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final session = ref.read(vocabularyReviewSessionProvider);
    final notifier = ref.read(vocabularyReviewSessionProvider.notifier);
    if (!session.hasActiveSession) return KeyEventResult.ignored;

    // Escape is owned by AppHotkeys (modal.close → popGoRouter). Handling it
    // here as well double-pops (review → vocabulary → profile).
    // Practice overlay is in-tree — dismiss it before the review route pops.
    if (session.practiceSheetOpen) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        unawaited(notifier.clearPractice());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (session.completed) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.space) {
      notifier.toggleFlip();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      notifier.skip();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      notifier.previous();
      return KeyEventResult.handled;
    }
    if (session.flipped && !session.ratingInFlight) {
      if (event.logicalKey == LogicalKeyboardKey.digit1 ||
          event.logicalKey == LogicalKeyboardKey.numpad1) {
        unawaited(notifier.rate(VocabularyRating.dontKnow));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit2 ||
          event.logicalKey == LogicalKeyboardKey.numpad2) {
        unawaited(notifier.rate(VocabularyRating.know));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit3 ||
          event.logicalKey == LogicalKeyboardKey.numpad3) {
        unawaited(notifier.rate(VocabularyRating.knowWell));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _maybePrefetchContextual(ReviewSessionState session) {
    if (!session.flipped || session.contextualFetchInFlight) return;
    final ctx = session.currentPrimaryContext;
    if (ctx == null || ctx.text.isEmpty) return;
    if (decodeContextualExplanation(ctx.explanation) != null) return;
    final auth = ref.read(authCtrlProvider);
    final signedIn = auth.maybeWhen(
      data: (s) => s is AuthSignedIn,
      orElse: () => false,
    );
    if (!signedIn) return;
    unawaited(
      ref
          .read(vocabularyReviewSessionProvider.notifier)
          .fetchContextualTranslation(),
    );
  }

  void _maybePrefetchDictionary(ReviewSessionState session) {
    if (!session.flipped || session.dictionaryFetchInFlight) return;
    final item = session.currentItem;
    if (item == null) return;
    if (decodeDictionaryExplanation(item.explanation) != null) return;
    final auth = ref.read(authCtrlProvider);
    final signedIn = auth.maybeWhen(
      data: (s) => s is AuthSignedIn,
      orElse: () => false,
    );
    if (!signedIn) return;
    unawaited(
      ref.read(vocabularyReviewSessionProvider.notifier).fetchDictionary(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final session = ref.watch(vocabularyReviewSessionProvider);

    ref.listen(vocabularyReviewSessionProvider, (prev, next) {
      if (next.flipped && prev?.flipped != true) {
        _maybePrefetchContextual(next);
        _maybePrefetchDictionary(next);
      }
    });

    if (!session.hasActiveSession) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.vocabularyTitle)),
        body: const SizedBox.shrink(),
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: session.completed
                  ? _CompleteBody(onDone: _exit)
                  : Column(
                      children: [
                        _SessionHeader(
                          current: session.displayCurrent,
                          total: session.total,
                          canUndo: session.canUndo,
                          ratingInFlight: session.ratingInFlight,
                          onClose: _exit,
                          onUndo: () => unawaited(
                            ref
                                .read(vocabularyReviewSessionProvider.notifier)
                                .undo(),
                          ),
                          onSkip: () => ref
                              .read(vocabularyReviewSessionProvider.notifier)
                              .skip(),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: t.space16,
                              vertical: t.space8,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: t.contentMaxWidth,
                                ),
                                child: VocabularyFlashcard(
                                  item: session.currentItem!,
                                  primaryContext: session.currentPrimaryContext,
                                  flipped: session.flipped,
                                  dictionaryFetchInFlight:
                                      session.dictionaryFetchInFlight,
                                  contextualFetchInFlight:
                                      session.contextualFetchInFlight,
                                  clipPlayInFlight: session.clipPlayInFlight,
                                  dictionaryError: session.dictionaryError,
                                  contextualError: session.contextualError,
                                  mediaError: session.mediaError,
                                  contextsCount: session.currentContextsCount,
                                  activeContextIndex:
                                      session.currentActiveContextIndex,
                                  actionsEnabled: !session.practiceSheetOpen,
                                  onPreviousContext: () => unawaited(
                                    ref
                                        .read(
                                          vocabularyReviewSessionProvider
                                              .notifier,
                                        )
                                        .selectPreviousContext(),
                                  ),
                                  onNextContext: () => unawaited(
                                    ref
                                        .read(
                                          vocabularyReviewSessionProvider
                                              .notifier,
                                        )
                                        .selectNextContext(),
                                  ),
                                  onFlip: () => ref
                                      .read(
                                        vocabularyReviewSessionProvider
                                            .notifier,
                                      )
                                      .flip(),
                                  onUnflip: () => ref
                                      .read(
                                        vocabularyReviewSessionProvider
                                            .notifier,
                                      )
                                      .unflip(),
                                  onFetchDictionary: () => unawaited(
                                    ref
                                        .read(
                                          vocabularyReviewSessionProvider
                                              .notifier,
                                        )
                                        .fetchDictionary(),
                                  ),
                                  onFetchContextual: () => unawaited(
                                    ref
                                        .read(
                                          vocabularyReviewSessionProvider
                                              .notifier,
                                        )
                                        .fetchContextualTranslation(),
                                  ),
                                  onPlayClip: () => unawaited(
                                    _openPractice(ReviewPracticeMode.clip),
                                  ),
                                  onOpenInPlayer: () =>
                                      unawaited(_confirmOpenInPlayer()),
                                  onShadowReading: () => unawaited(
                                    _openPractice(ReviewPracticeMode.echo),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (session.flipped)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              t.space20,
                              t.space8,
                              t.space20,
                              t.space16,
                            ),
                            child: VocabularyRatingBar(
                              ratingInFlight:
                                  session.ratingInFlight ||
                                  session.practiceSheetOpen,
                              onRate: (r) {
                                unawaited(
                                  ref
                                      .read(
                                        pronouncePlaybackControllerProvider
                                            .notifier,
                                      )
                                      .stop(),
                                );
                                unawaited(
                                  ref
                                      .read(
                                        vocabularyReviewSessionProvider
                                            .notifier,
                                      )
                                      .rate(r),
                                );
                              },
                            ),
                          )
                        else
                          SizedBox(height: t.space8),
                      ],
                    ),
            ),
            // Video/WebView is owned by RootShell [PlayerSurfaceHost].
            const VocabularyPracticeOverlay(),
          ],
        ),
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.current,
    required this.total,
    required this.canUndo,
    required this.ratingInFlight,
    required this.onClose,
    required this.onUndo,
    required this.onSkip,
  });

  final int current;
  final int total;
  final bool canUndo;
  final bool ratingInFlight;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final type = TranscriptTypographyTokens.of(context);
    final progress = total <= 0 ? 0.0 : current / total;

    return Padding(
      padding: EdgeInsets.fromLTRB(t.space8, t.space8, t.space8, t.space4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.vocabularyExitReview,
            onPressed: onClose,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: t.motionStandard,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 5,
                      backgroundColor: cs.surfaceContainerHighest.withValues(
                        alpha: 0.55,
                      ),
                      color: cs.primary,
                    );
                  },
                ),
              ),
            ),
          ),
          Text(
            l10n.vocabularyProgress(current, total),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.monoStyle.copyWith(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: cs.onSurfaceVariant,
              textStyle: Theme.of(context).textTheme.labelMedium,
            ),
            onPressed: ratingInFlight ? null : onSkip,
            child: Text(l10n.vocabularySkip),
          ),
          if (canUndo)
            EnjoyTappableIcon(
              icon: Icons.undo_rounded,
              tooltip: l10n.vocabularyUndo,
              onPressed: onUndo,
            ),
        ],
      ),
    );
  }
}

class _CompleteBody extends StatelessWidget {
  const _CompleteBody({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.all(t.space24),
          child: EnjoyCard(
            padding: EdgeInsets.all(t.space32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: t.space16),
                Text(
                  l10n.vocabularyReviewComplete,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: t.space8),
                Text(
                  l10n.vocabularyReviewCompleteDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: t.space24),
                EnjoyButton.primary(
                  onPressed: onDone,
                  child: Text(l10n.vocabularyDone),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
