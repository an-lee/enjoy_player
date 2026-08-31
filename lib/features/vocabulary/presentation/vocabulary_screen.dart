/// Vocabulary destination: slim Review / All Words tabs + list-first chrome.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/layout/enjoy_page_kind.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_page.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_providers.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_review_options.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_word_list.dart';
import 'package:enjoy_player/features/vocabulary/presentation/widgets/vocabulary_empty_states.dart';
import 'package:enjoy_player/features/vocabulary/presentation/widgets/vocabulary_stats_strip.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class VocabularyScreen extends ConsumerWidget {
  const VocabularyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final stats = ref.watch(vocabularyStatsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 2,
      child: EnjoyPage(
        kind: EnjoyPageKind.hub,
        title: l10n.vocabularyTitle,
        showBack: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/profile');
          }
        },
        actions: [
          IconButton(
            tooltip: l10n.vocabularyStatsExpand,
            onPressed: () => showVocabularyStatsSheet(context, stats),
            icon: const Icon(Icons.insights_outlined),
          ),
        ],
        body: (context, metrics) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: metrics.padding(top: t.space8, bottom: t.space4),
              child: Material(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(t.radiusFull),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(t.radiusFull),
                    ),
                    labelColor: cs.onPrimaryContainer,
                    unselectedLabelColor: cs.onSurfaceVariant,
                    labelStyle: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: tt.labelLarge,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    tabs: [
                      Tab(
                        height: 40,
                        child: _ReviewTabLabel(
                          label: l10n.vocabularyReview,
                          due: stats.due,
                        ),
                      ),
                      Tab(height: 40, text: l10n.vocabularyAllWords),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ReviewTab(total: stats.total, due: stats.due),
                  VocabularyWordList(metrics: metrics),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTabLabel extends StatelessWidget {
  const _ReviewTabLabel({required this.label, required this.due});

  final String label;
  final int due;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (due > 0) ...[
          SizedBox(width: t.space8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: t.space8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(t.radiusFull),
            ),
            child: Text(
              '$due',
              style: tt.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewTab extends ConsumerWidget {
  const _ReviewTab({required this.total, required this.due});

  final int total;
  final int due;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (total == 0) {
      return const VocabularyEmptyState(kind: VocabularyEmptyKind.noWords);
    }

    if (due == 0) {
      return VocabularyEmptyState(
        kind: VocabularyEmptyKind.noDue,
        action: () => _startReview(context, ref),
        actionLabel: l10n.vocabularyCustomReview,
      );
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(t.space24),
        child: EnjoyCard(
          padding: EdgeInsets.all(t.space32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$due',
                  style: tt.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: cs.primary,
                  ),
                ),
                SizedBox(height: t.space8),
                Text(
                  l10n.vocabularyDue,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: t.space24),
                SizedBox(
                  width: double.infinity,
                  child: EnjoyButton.primary(
                    onPressed: () => _startReview(context, ref),
                    child: Text(l10n.vocabularyStartReview),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startReview(BuildContext context, WidgetRef ref) async {
    final options = await showVocabularyReviewOptions(context);
    if (options == null || !context.mounted) return;
    final started = await ref
        .read(vocabularyReviewSessionProvider.notifier)
        .start(options);
    if (!context.mounted) return;
    if (!started) {
      AppNotice.info(
        context,
        AppLocalizations.of(context)!.vocabularyEmptyQueue,
      );
      return;
    }
    await context.push('/vocabulary/review');
  }
}
