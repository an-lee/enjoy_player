/// Flashcard front/back with Context / Dictionary tabs.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';
import 'package:enjoy_player/features/pronounce/presentation/pronounce_icon_button.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_text_style.dart';
import 'package:enjoy_player/features/vocabulary/presentation/widgets/vocabulary_flashcard_context_tab.dart';
import 'package:enjoy_player/features/vocabulary/presentation/widgets/vocabulary_flashcard_dictionary_tab.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

export 'package:enjoy_player/features/vocabulary/presentation/vocabulary_ipa_formatter.dart';

class VocabularyFlashcard extends ConsumerWidget {
  const VocabularyFlashcard({
    super.key,
    required this.item,
    required this.primaryContext,
    required this.flipped,
    required this.ratingInFlight,
    required this.dictionaryFetchInFlight,
    required this.contextualFetchInFlight,
    required this.clipPlayInFlight,
    this.dictionaryError,
    this.contextualError,
    this.mediaError,
    required this.onFlip,
    required this.onUnflip,
    required this.onRate,
    required this.onFetchDictionary,
    required this.onFetchContextual,
    required this.onPlayClip,
    required this.onOpenInPlayer,
    required this.onShadowReading,
    this.contextsCount = 0,
    this.activeContextIndex = 0,
    this.onPreviousContext,
    this.onNextContext,
    this.actionsEnabled = true,
  });

  final VocabularyItem item;
  final VocabularyContext? primaryContext;
  final bool flipped;
  final bool ratingInFlight;
  final bool dictionaryFetchInFlight;
  final bool contextualFetchInFlight;
  final bool clipPlayInFlight;
  final String? dictionaryError;
  final String? contextualError;
  final String? mediaError;
  final VoidCallback onFlip;
  final VoidCallback onUnflip;
  final ValueChanged<VocabularyRating> onRate;
  final VoidCallback onFetchDictionary;
  final VoidCallback onFetchContextual;
  final VoidCallback onPlayClip;
  final VoidCallback onOpenInPlayer;
  final VoidCallback onShadowReading;
  final int contextsCount;
  final int activeContextIndex;
  final VoidCallback? onPreviousContext;
  final VoidCallback? onNextContext;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = EnjoyThemeTokens.of(context);
    // Card source language (may be bare ISO 639-1; resolvePronounceLocale maps).
    final localeTag = item.language;

    void stopPronounce() {
      unawaited(ref.read(pronouncePlaybackControllerProvider.notifier).stop());
    }

    return AnimatedSwitcher(
      duration: t.motionStandard,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: <Widget>[...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: flipped
          ? KeyedSubtree(
              key: const ValueKey('back'),
              child: _FlashcardBack(
                item: item,
                primaryContext: primaryContext,
                localeTag: localeTag,
                ratingInFlight: ratingInFlight,
                dictionaryFetchInFlight: dictionaryFetchInFlight,
                contextualFetchInFlight: contextualFetchInFlight,
                clipPlayInFlight: clipPlayInFlight,
                dictionaryError: dictionaryError,
                contextualError: contextualError,
                mediaError: mediaError,
                onUnflip: () {
                  stopPronounce();
                  onUnflip();
                },
                onRate: (r) {
                  stopPronounce();
                  onRate(r);
                },
                onFetchDictionary: onFetchDictionary,
                onFetchContextual: onFetchContextual,
                onPlayClip: onPlayClip,
                onOpenInPlayer: onOpenInPlayer,
                onShadowReading: onShadowReading,
                contextsCount: contextsCount,
                activeContextIndex: activeContextIndex,
                onPreviousContext: onPreviousContext,
                onNextContext: onNextContext,
                actionsEnabled: actionsEnabled,
              ),
            )
          : KeyedSubtree(
              key: const ValueKey('front'),
              child: _FlashcardFront(
                word: item.word,
                localeTag: localeTag,
                contextText: primaryContext?.text,
                onFlip: actionsEnabled
                    ? () {
                        stopPronounce();
                        onFlip();
                      }
                    : () {},
              ),
            ),
    );
  }
}

class _FlashcardFront extends StatelessWidget {
  const _FlashcardFront({
    required this.word,
    required this.localeTag,
    required this.contextText,
    required this.onFlip,
  });

  final String word;
  final String localeTag;
  final String? contextText;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final contextBase = tt.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant.withValues(alpha: 0.9),
      height: 1.45,
    );
    final contextHighlight = contextBase?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w700,
      backgroundColor: cs.primary.withValues(alpha: 0.18),
    );

    return SizedBox.expand(
      child: EnjoyCard(
        child: EnjoyTappableSurface(
          borderRadius: BorderRadius.circular(t.radiusLg),
          semanticsLabel: l10n.vocabularyFlipHint,
          onTap: onFlip,
          child: Padding(
            padding: EdgeInsets.all(t.space24),
            child: Column(
              children: [
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              word,
                              textAlign: TextAlign.center,
                              style: tt.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.0,
                                height: 1.1,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          PronounceIconButton(
                            text: word,
                            localeTag: localeTag,
                            surfaceId: PronounceSurfaceId.flashcard,
                            compact: true,
                          ),
                        ],
                      ),
                      SizedBox(height: t.space20),
                      if (contextText != null && contextText!.isNotEmpty)
                        Text.rich(
                          TextSpan(
                            children: highlightVocabularyWord(
                              text: contextText!,
                              word: word,
                              base: contextBase ?? const TextStyle(),
                              highlight: contextHighlight ?? const TextStyle(),
                            ),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          l10n.vocabularyNoContextAvailable,
                          textAlign: TextAlign.center,
                          style: contextBase,
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(t.radiusFull),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.space20,
                      vertical: t.space12,
                    ),
                    child: Text(
                      l10n.vocabularyFlipHint,
                      style: tt.labelLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlashcardBack extends StatelessWidget {
  const _FlashcardBack({
    required this.item,
    required this.primaryContext,
    required this.localeTag,
    required this.ratingInFlight,
    required this.dictionaryFetchInFlight,
    required this.contextualFetchInFlight,
    required this.clipPlayInFlight,
    this.dictionaryError,
    this.contextualError,
    this.mediaError,
    required this.onUnflip,
    required this.onRate,
    required this.onFetchDictionary,
    required this.onFetchContextual,
    required this.onPlayClip,
    required this.onOpenInPlayer,
    required this.onShadowReading,
    required this.contextsCount,
    required this.activeContextIndex,
    this.onPreviousContext,
    this.onNextContext,
    required this.actionsEnabled,
  });

  final VocabularyItem item;
  final VocabularyContext? primaryContext;
  final String localeTag;
  final bool ratingInFlight;
  final bool dictionaryFetchInFlight;
  final bool contextualFetchInFlight;
  final bool clipPlayInFlight;
  final String? dictionaryError;
  final String? contextualError;
  final String? mediaError;
  final VoidCallback onUnflip;
  final ValueChanged<VocabularyRating> onRate;
  final VoidCallback onFetchDictionary;
  final VoidCallback onFetchContextual;
  final VoidCallback onPlayClip;
  final VoidCallback onOpenInPlayer;
  final VoidCallback onShadowReading;
  final int contextsCount;
  final int activeContextIndex;
  final VoidCallback? onPreviousContext;
  final VoidCallback? onNextContext;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox.expand(
      child: EnjoyCard(
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space24,
                  t.space20,
                  t.space24,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.word,
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    PronounceIconButton(
                      text: item.word,
                      localeTag: localeTag,
                      surfaceId: PronounceSurfaceId.flashcard,
                      compact: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: t.space12),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.space24),
                child: Material(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(t.radiusMd),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(t.radiusSm),
                    ),
                    labelColor: cs.onSurface,
                    unselectedLabelColor: cs.onSurfaceVariant,
                    labelStyle: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: tt.labelMedium,
                    labelPadding: EdgeInsets.symmetric(horizontal: t.space8),
                    tabs: [
                      Tab(height: 40, text: l10n.vocabularyContext),
                      Tab(height: 40, text: l10n.vocabularyDictionary),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ScrollbarTheme(
                  data: ScrollbarThemeData(
                    thickness: WidgetStateProperty.all(4),
                    radius: Radius.circular(t.radiusFull),
                    thumbColor: WidgetStateProperty.all(
                      cs.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: TabBarView(
                    children: [
                      _TabBody(
                        child: FlashcardContextTab(
                          word: item.word,
                          primaryContext: primaryContext,
                          contextualFetchInFlight: contextualFetchInFlight,
                          clipPlayInFlight: clipPlayInFlight,
                          contextualError: contextualError,
                          mediaError: mediaError,
                          onFetchContextual: onFetchContextual,
                          onPlayClip: onPlayClip,
                          onOpenInPlayer: onOpenInPlayer,
                          onShadowReading: onShadowReading,
                          contextsCount: contextsCount,
                          activeContextIndex: activeContextIndex,
                          onPreviousContext: onPreviousContext,
                          onNextContext: onNextContext,
                          actionsEnabled: actionsEnabled,
                        ),
                      ),
                      _TabBody(
                        child: FlashcardDictionaryTab(
                          explanation: item.explanation,
                          fetchInFlight: dictionaryFetchInFlight,
                          error: dictionaryError,
                          onFetch: onFetchDictionary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.28),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space12,
                    t.space8,
                    t.space12,
                    t.space8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.vocabularyHowWellDoYouKnow,
                        textAlign: TextAlign.center,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: t.space8),
                      _RatingBar(
                        ratingInFlight: ratingInFlight || !actionsEnabled,
                        onRate: onRate,
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 36),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.symmetric(horizontal: t.space12),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: (ratingInFlight || !actionsEnabled)
                            ? null
                            : () {
                                Haptics.selection(context);
                                onUnflip();
                              },
                        child: Text(l10n.vocabularyFlipBack),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact rating pills — sized for small screens, capped on wide layouts.
class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.ratingInFlight, required this.onRate});

  static const double _maxWidth = 360;

  final bool ratingInFlight;
  final ValueChanged<VocabularyRating> onRate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final gap = MediaQuery.sizeOf(context).width < 360 ? t.space4 : t.space8;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Row(
          children: [
            Expanded(
              child: _RatingChip(
                label: l10n.vocabularyDontKnow,
                icon: Icons.close_rounded,
                background: cs.error.withValues(alpha: 0.12),
                foreground: cs.error,
                border: cs.error.withValues(alpha: 0.35),
                emphasized: false,
                onPressed: ratingInFlight
                    ? null
                    : () => onRate(VocabularyRating.dontKnow),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _RatingChip(
                label: l10n.vocabularyKnow,
                icon: Icons.check_rounded,
                background: cs.primary.withValues(alpha: 0.18),
                foreground: cs.primary,
                border: cs.primary.withValues(alpha: 0.45),
                emphasized: true,
                onPressed: ratingInFlight
                    ? null
                    : () => onRate(VocabularyRating.know),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _RatingChip(
                label: l10n.vocabularyKnowWell,
                icon: Icons.check_circle_rounded,
                background: cs.tertiary.withValues(alpha: 0.16),
                foreground: cs.tertiary,
                border: cs.tertiary.withValues(alpha: 0.45),
                emphasized: false,
                onPressed: ratingInFlight
                    ? null
                    : () => onRate(VocabularyRating.knowWell),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact outlined rating pill (~36px tall).
class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
    required this.emphasized,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;
  final bool emphasized;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(t.radiusFull);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled ? background : background.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: enabled ? border : border.withValues(alpha: 0.25),
            width: emphasized ? 1.25 : 1,
          ),
        ),
        child: InkWell(
          onTap: enabled
              ? () {
                  Haptics.selection(context);
                  onPressed!();
                }
              : null,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.space8,
              vertical: t.space8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: foreground),
                SizedBox(width: t.space4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBody extends StatefulWidget {
  const _TabBody({required this.child});

  final Widget child;

  @override
  State<_TabBody> createState() => _TabBodyState();
}

class _TabBodyState extends State<_TabBody> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    // Explicit controller: desktop Scrollbar defaults to PrimaryScrollController,
    // but SingleChildScrollView does not attach to it — scrolling then throws.
    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          t.space24,
          t.space16,
          t.space24,
          t.space24,
        ),
        child: widget.child,
      ),
    );
  }
}
