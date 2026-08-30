import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/theme/colors.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/features/ai/domain/models/dictionary_result.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/auth_required_callout.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_explanation_codec.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_ipa_formatter.dart';
import 'package:enjoy_player/features/subscription/presentation/credits_failure_actions.dart';
import 'package:enjoy_player/features/vocabulary/presentation/widgets/flashcard_soft_error.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class FlashcardDictionaryTab extends ConsumerStatefulWidget {
  const FlashcardDictionaryTab({
    super.key,
    required this.explanation,
    required this.fetchInFlight,
    required this.error,
    required this.onFetch,
  });

  final String? explanation;
  final bool fetchInFlight;
  final String? error;
  final VoidCallback onFetch;

  @override
  ConsumerState<FlashcardDictionaryTab> createState() =>
      _FlashcardDictionaryTabState();
}

class _FlashcardDictionaryTabState
    extends ConsumerState<FlashcardDictionaryTab> {
  var _autoloadRequested = false;

  @override
  void didUpdateWidget(covariant FlashcardDictionaryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New cache payload (or cleared after navigation) may need a fresh load.
    if (oldWidget.explanation != widget.explanation) {
      _autoloadRequested = false;
    }
  }

  void _maybeAutoload({required bool signedIn}) {
    if (!mounted || _autoloadRequested) return;
    if (decodeDictionaryExplanation(widget.explanation) != null) return;
    if (widget.fetchInFlight || widget.error != null) return;
    if (!signedIn) return;
    _autoloadRequested = true;
    widget.onFetch();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final result = decodeDictionaryExplanation(widget.explanation);
    final auth = ref.watch(authCtrlProvider);
    final authLoading = auth.isLoading;
    final signedIn = auth.maybeWhen(
      data: (s) => s is AuthSignedIn,
      orElse: () => false,
    );

    if (result != null) {
      return _DictionaryResultView(result: result);
    }

    if (authLoading) {
      return _DictionaryLoading(label: l10n.vocabularyFetching);
    }

    if (!signedIn) {
      return const AuthRequiredCallout(
        surface: AuthRequiredSurface.lookupDictionary,
        compact: true,
      );
    }

    // Kick off load once auth is ready and cache is empty.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoload(signedIn: signedIn);
    });

    if (widget.fetchInFlight || widget.error == null) {
      return _DictionaryLoading(label: l10n.vocabularyFetching);
    }

    // Credits rejection gets its own truthful copy instead of the
    // network-flavored fallback (spec 045), plus the one-tap recovery CTA.
    final isCredits = widget.error == 'credits';
    final errorMessage = isCredits
        ? l10n.subscriptionCreditsLimitMessageWithPackages
        : l10n.vocabularyAiFetchFailed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FlashcardSoftError(message: errorMessage),
        SizedBox(height: t.space12),
        EnjoyButton.secondary(
          onPressed: widget.onFetch,
          child: Text(l10n.vocabularyFetchDictionary),
        ),
        if (isCredits)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => context.push('/subscription'),
              child: Text(creditsCtaLabel(l10n)),
            ),
          ),
      ],
    );
  }
}

class _DictionaryLoading extends StatelessWidget {
  const _DictionaryLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: t.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: scheme.primary,
              ),
            ),
            SizedBox(height: t.space12),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DictionaryResultView extends StatelessWidget {
  const _DictionaryResultView({required this.result});

  final DictionaryResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lemmaTrim = result.lemma?.trim();
    final showLemma =
        lemmaTrim != null &&
        lemmaTrim.isNotEmpty &&
        lemmaTrim != result.word.trim();
    final ipaFormatted = result.ipa == null
        ? ''
        : formatVocabularyIpa(result.ipa!);
    final hasIpa = ipaFormatted.isNotEmpty;

    if (result.senses.isEmpty) {
      return Text(l10n.vocabularyDictionaryNotAvailable);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasIpa || showLemma) ...[
          Wrap(
            spacing: t.space8,
            runSpacing: t.space4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hasIpa)
                Text(
                  ipaFormatted,
                  style: tt.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              if (showLemma)
                Text(
                  lemmaTrim,
                  style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
          SizedBox(height: t.space16),
        ],
        for (var i = 0; i < result.senses.length; i++) ...[
          if (i > 0) ...[
            SizedBox(height: t.space12),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.18),
            ),
            SizedBox(height: t.space12),
          ],
          _SenseTile(sense: result.senses[i]),
        ],
      ],
    );
  }
}

class _SenseTile extends StatelessWidget {
  const _SenseTile({required this.sense});

  final DictionarySense sense;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final t = EnjoyThemeTokens.of(context);
    final pos = sense.partOfSpeech?.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final translationColor = isDark ? AppColors.brandOnDark : scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pos != null && pos.isNotEmpty) ...[
          Text(
            pos,
            style: tt.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: t.space4),
        ],
        if (sense.definition.trim().isNotEmpty)
          SelectableText(
            sense.definition,
            style: tt.bodyMedium?.copyWith(height: 1.45),
          ),
        if (sense.translation != null &&
            sense.translation!.trim().isNotEmpty) ...[
          SizedBox(height: t.space4),
          SelectableText(
            sense.translation!,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: translationColor,
              height: 1.4,
            ),
          ),
        ],
        if (sense.examples != null && sense.examples!.isNotEmpty) ...[
          SizedBox(height: t.space12),
          for (final ex in sense.examples!)
            Padding(
              padding: EdgeInsets.only(bottom: t.space8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      width: 2,
                      color: scheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                padding: EdgeInsetsDirectional.only(start: t.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      ex.source,
                      style: tt.bodySmall?.copyWith(
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (ex.target != null && ex.target!.trim().isNotEmpty) ...[
                      SizedBox(height: t.space4),
                      SelectableText(
                        ex.target!,
                        style: tt.bodySmall?.copyWith(
                          height: 1.4,
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
        if (sense.notes != null && sense.notes!.trim().isNotEmpty) ...[
          SizedBox(height: t.space4),
          Text(
            sense.notes!,
            style: tt.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
