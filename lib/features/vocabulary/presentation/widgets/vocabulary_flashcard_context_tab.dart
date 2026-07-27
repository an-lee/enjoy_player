import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/lookup_markdown_style.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/auth_required_callout.dart';
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
        _SectionHeading(
          icon: Icons.format_quote_rounded,
          label: l10n.vocabularyContext,
        ),
        SizedBox(height: t.space16),
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
        SizedBox(height: t.space32),
        _SectionHeading(
          icon: Icons.movie_outlined,
          label: l10n.vocabularySourceLabel,
        ),
        SizedBox(height: t.space16),
        if (titleAsync.isLoading && sourceTitle == null)
          Text('…', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
        else
          Text(
            sourceTitle ?? l10n.vocabularyUnknownSource,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurface,
              height: 1.4,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        if (locator != null) ...[
          SizedBox(height: t.space8),
          Text(
            l10n.vocabularyLocatorLabel(
              (locator.start / 1000).toStringAsFixed(1),
              (locator.duration / 1000).toStringAsFixed(1),
            ),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.85),
              letterSpacing: 0.1,
            ),
          ),
        ],
        if (canMedia) ...[
          SizedBox(height: t.space8),
          Wrap(
            spacing: t.space4,
            runSpacing: t.space4,
            children: [
              _MediaAction(
                icon: Icons.play_arrow_rounded,
                label: clipPlayInFlight
                    ? l10n.vocabularyFetching
                    : l10n.vocabularyPlaySegment,
                onPressed: (!actionsEnabled || clipPlayInFlight)
                    ? null
                    : onPlayClip,
              ),
              _MediaAction(
                icon: Icons.open_in_new_rounded,
                label: l10n.vocabularyOpenInPlayer,
                onPressed: actionsEnabled ? onOpenInPlayer : null,
              ),
              _MediaAction(
                icon: Icons.record_voice_over_rounded,
                label: l10n.vocabularyEchoReading,
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
        SizedBox(height: t.space32),
        _SectionHeading(
          icon: Icons.translate_rounded,
          label: l10n.vocabularyContextualTranslation,
        ),
        SizedBox(height: t.space16),
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
              child: FlashcardSoftError(message: l10n.vocabularyAiFetchFailed),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary.withValues(alpha: 0.9)),
        SizedBox(width: t.space8),
        Expanded(
          child: Text(
            label,
            style: tt.titleSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              height: 1.2,
            ),
          ),
        ),
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

class _MediaAction extends StatelessWidget {
  const _MediaAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    return TextButton.icon(
      onPressed: onPressed == null
          ? null
          : () {
              Haptics.selection(context);
              onPressed!();
            },
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: EdgeInsets.symmetric(horizontal: t.space12),
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
