/// Flashcard front/back with Context / Dictionary tabs.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/typography.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';
import 'package:enjoy_player/core/window/desktop_window.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';
import 'package:enjoy_player/features/pronounce/presentation/pronounce_icon_button.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_explanation_codec.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_ipa_formatter.dart';
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
    required this.dictionaryFetchInFlight,
    required this.contextualFetchInFlight,
    required this.clipPlayInFlight,
    this.dictionaryError,
    this.contextualError,
    this.mediaError,
    required this.onFlip,
    required this.onUnflip,
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
  final bool dictionaryFetchInFlight;
  final bool contextualFetchInFlight;
  final bool clipPlayInFlight;
  final String? dictionaryError;
  final String? contextualError;
  final String? mediaError;
  final VoidCallback onFlip;
  final VoidCallback onUnflip;
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
                explanation: item.explanation,
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
    required this.explanation,
    required this.contextText,
    required this.onFlip,
  });

  final String word;
  final String localeTag;
  final String? explanation;
  final String? contextText;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final type = TranscriptTypographyTokens.of(context);
    final dictionary = decodeDictionaryExplanation(explanation);
    final ipa = dictionary?.ipa == null
        ? ''
        : formatVocabularyIpa(dictionary!.ipa!);
    final pos = dictionary?.senses
        .map((s) => s.partOfSpeech?.trim())
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .firstOrNull;
    final metaParts = <String>[if (ipa.isNotEmpty) ipa, if (pos != null) pos];
    final contextBase = type.bodyStyle.copyWith(
      fontSize: 15.5,
      height: 1.6,
      fontStyle: FontStyle.italic,
      color: cs.onSurfaceVariant,
    );
    final contextHighlight = contextBase.copyWith(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
      backgroundColor: t.accentSoft,
    );
    final hint = isDesktop
        ? l10n.vocabularyFlipHintShortcuts
        : l10n.vocabularyFlipHint;

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
                      Text(
                        word,
                        textAlign: TextAlign.center,
                        style: type.displaySerifStyle.copyWith(
                          fontSize: 40,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                          letterSpacing: -0.6,
                          color: cs.onSurface,
                        ),
                      ),
                      if (metaParts.isNotEmpty) ...[
                        SizedBox(height: t.space8),
                        Text(
                          metaParts.join(' · '),
                          textAlign: TextAlign.center,
                          style: type.monoStyle.copyWith(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      PronounceIconButton(
                        text: word,
                        localeTag: localeTag,
                        surfaceId: PronounceSurfaceId.flashcard,
                        compact: true,
                        label: l10n.vocabularyPronounce,
                      ),
                      SizedBox(height: t.space16),
                      if (contextText != null && contextText!.isNotEmpty)
                        Text.rich(
                          TextSpan(
                            children: highlightVocabularyWord(
                              text: contextText!,
                              word: word,
                              base: contextBase,
                              highlight: contextHighlight,
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
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: type.monoStyle.copyWith(
                    fontSize: 11.5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
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
    required this.dictionaryFetchInFlight,
    required this.contextualFetchInFlight,
    required this.clipPlayInFlight,
    this.dictionaryError,
    this.contextualError,
    this.mediaError,
    required this.onUnflip,
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
  final bool dictionaryFetchInFlight;
  final bool contextualFetchInFlight;
  final bool clipPlayInFlight;
  final String? dictionaryError;
  final String? contextualError;
  final String? mediaError;
  final VoidCallback onUnflip;
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
    final type = TranscriptTypographyTokens.of(context);

    return SizedBox.expand(
      child: EnjoyCard(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: actionsEnabled ? onUnflip : null,
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space24,
                    t.space20,
                    t.space16,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.word,
                          style: type.displaySerifStyle.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.3,
                            height: 1.15,
                            color: cs.onSurface,
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
                Align(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                      borderRadius: BorderRadius.circular(t.radiusFull),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.center,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(t.radiusFull),
                        ),
                        labelColor: cs.onSurface,
                        unselectedLabelColor: cs.onSurfaceVariant,
                        labelStyle: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        unselectedLabelStyle: Theme.of(
                          context,
                        ).textTheme.labelSmall,
                        labelPadding: EdgeInsets.symmetric(
                          horizontal: t.space12,
                        ),
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        splashFactory: NoSplash.splashFactory,
                        tabs: [
                          Tab(height: 28, text: l10n.vocabularyContext),
                          Tab(height: 28, text: l10n.vocabularyDictionary),
                        ],
                      ),
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
                            key: ValueKey('dict-${item.id}'),
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
