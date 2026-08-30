import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/lookup_markdown_style.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/auth_required_callout.dart';
import 'package:enjoy_player/features/subscription/presentation/credits_failure_actions.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_media.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_source_title.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_explanation_codec.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_text_style.dart';
import 'package:enjoy_player/features/vocabulary/presentation/widgets/flashcard_soft_error.dart';
import 'package:enjoy_player/features/vocabulary/presentation/widgets/vocabulary_context_pager.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class FlashcardContextTab extends ConsumerWidget {
  const FlashcardContextTab({
    super.key,
    required this.word,
    required this.primaryContext,
    required this.contextualFetchInFlight,
    required this.clipPlayInFlight,
    required this.contextualError,
    required this.mediaError,
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

  final String word;
  final VocabularyContext? primaryContext;
  final bool contextualFetchInFlight;
  final bool clipPlayInFlight;
  final String? contextualError;
  final String? mediaError;
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
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final ctx = primaryContext;
    if (ctx == null || ctx.text.isEmpty) {
      return Text(l10n.vocabularyNoContextAvailable);
    }

    final translation = decodeContextualExplanation(ctx.explanation);
    final canMedia = vocabularyContextSupportsMediaActions(ctx);
    final locator = ctx.locator;
    final auth = ref.watch(authCtrlProvider);
    final signedIn = auth.maybeWhen(
      data: (s) => s is AuthSignedIn,
      orElse: () => false,
    );
    final titleAsync = ref.watch(vocabularySourceTitleProvider(ctx.sourceId));
    final sourceTitle =
        titleAsync.asData?.value ??
        (titleAsync.isLoading ? null : l10n.vocabularyUnknownSource);
    final contextBase = tt.bodyLarge?.copyWith(
      height: 1.55,
      color: cs.onSurface.withValues(alpha: 0.92),
    );
    final contextHighlight = contextBase?.copyWith(
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
      backgroundColor: cs.primary.withValues(alpha: 0.18),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 3,
                color: cs.primary.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: t.space16),
            child: Text.rich(
              TextSpan(
                children: highlightVocabularyWord(
                  text: ctx.text,
                  word: word,
                  base: contextBase ?? const TextStyle(),
                  highlight: contextHighlight ?? const TextStyle(),
                ),
              ),
            ),
          ),
        ),
        if (contextsCount > 1) ...[
          SizedBox(height: t.space16),
          VocabularyContextPager(
            index: activeContextIndex,
            total: contextsCount,
            onPrevious: actionsEnabled ? onPreviousContext : null,
            onNext: actionsEnabled ? onNextContext : null,
          ),
        ],
        SizedBox(height: t.space16),
        if (titleAsync.isLoading && sourceTitle == null)
          Text('…', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
        else
          Text(
            sourceTitle ?? l10n.vocabularyUnknownSource,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        if (locator != null) ...[
          SizedBox(height: t.space4),
          Text(
            l10n.vocabularyLocatorLabel(
              (locator.start / 1000).toStringAsFixed(1),
              (locator.duration / 1000).toStringAsFixed(1),
            ),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.75),
              letterSpacing: 0.1,
            ),
          ),
        ],
        if (canMedia) ...[
          SizedBox(height: t.space8),
          Row(
            children: [
              EnjoyTappableIcon(
                icon: Icons.play_arrow_rounded,
                tooltip: clipPlayInFlight
                    ? l10n.vocabularyFetching
                    : l10n.vocabularyPlaySegment,
                semanticLabel: clipPlayInFlight
                    ? l10n.vocabularyFetching
                    : l10n.vocabularyPlaySegment,
                color: cs.primary,
                onPressed: (!actionsEnabled || clipPlayInFlight)
                    ? null
                    : onPlayClip,
              ),
              EnjoyTappableIcon(
                icon: Icons.open_in_new_rounded,
                tooltip: l10n.vocabularyOpenInPlayer,
                semanticLabel: l10n.vocabularyOpenInPlayer,
                color: cs.primary,
                onPressed: actionsEnabled ? onOpenInPlayer : null,
              ),
              EnjoyTappableIcon(
                icon: Icons.record_voice_over_rounded,
                tooltip: l10n.vocabularyEchoReading,
                semanticLabel: l10n.vocabularyEchoReading,
                color: cs.primary,
                onPressed: actionsEnabled ? onShadowReading : null,
              ),
            ],
          ),
        ] else ...[
          SizedBox(height: t.space12),
          Text(
            l10n.vocabularyMediaUnavailable,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        if (mediaError != null) ...[
          SizedBox(height: t.space8),
          FlashcardSoftError(message: l10n.vocabularyMediaPlayFailed),
        ],
        SizedBox(height: t.space20),
        _DetailLabel(l10n.vocabularyContextualTranslation),
        SizedBox(height: t.space8),
        if (translation != null)
          _StructuredContextualMarkdown(markdown: translation.translatedText)
        else if (!signedIn)
          const AuthRequiredCallout(
            surface: AuthRequiredSurface.lookupContextual,
            compact: true,
          )
        else if (contextualFetchInFlight)
          Padding(
            padding: EdgeInsets.symmetric(vertical: t.space8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(width: t.space12),
                Text(
                  l10n.vocabularyFetching,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          )
        else ...[
          if (contextualError != null)
            Padding(
              padding: EdgeInsets.only(bottom: t.space8),
              // Credits rejection gets its own truthful copy instead of the
              // network-flavored fallback (spec 045).
              child: FlashcardSoftError(
                message: contextualError == 'credits'
                    ? l10n.subscriptionCreditsLimitMessageWithPackages
                    : l10n.vocabularyAiFetchFailed,
              ),
            ),
          if (contextualError == 'credits')
            Padding(
              padding: EdgeInsets.only(bottom: t.space8),
              // One-tap recovery for the credits block (spec 045).
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => context.push('/subscription'),
                  child: Text(creditsCtaLabel(l10n)),
                ),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: EnjoyButton.secondary(
              onPressed: onFetchContextual,
              child: Text(l10n.vocabularyFetchContextual),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailLabel extends StatelessWidget {
  const _DetailLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: cs.onSurfaceVariant.withValues(alpha: 0.75),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
        height: 1.2,
      ),
    );
  }
}

class _StructuredContextualMarkdown extends StatelessWidget {
  const _StructuredContextualMarkdown({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final doc = parseContextualMarkdownDocument(markdown);
    final bodyStyle = buildLookupMarkdownStyleSheet(theme, t).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(
        height: 1.55,
        color: cs.onSurface.withValues(alpha: 0.92),
      ),
      blockSpacing: t.space8,
      h1: theme.textTheme.bodyMedium,
      h2: theme.textTheme.bodyMedium,
      h3: theme.textTheme.bodyMedium,
      h4: theme.textTheme.bodyMedium,
      h1Padding: EdgeInsets.zero,
      h2Padding: EdgeInsets.zero,
      h3Padding: EdgeInsets.zero,
      h4Padding: EdgeInsets.zero,
    );
    final translationStyle = bodyStyle.copyWith(
      p: theme.textTheme.bodyLarge?.copyWith(
        height: 1.5,
        color: cs.onSurface,
        fontWeight: FontWeight.w500,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (doc.preamble.isNotEmpty)
          MarkdownBody(
            data: doc.preamble,
            selectable: true,
            styleSheet: translationStyle,
          ),
        for (final section in doc.sections) ...[
          SizedBox(height: doc.preamble.isNotEmpty ? t.space20 : t.space12),
          _DetailLabel(section.title),
          SizedBox(height: t.space8),
          MarkdownBody(
            data: section.body,
            selectable: true,
            styleSheet: bodyStyle,
          ),
        ],
      ],
    );
  }
}
