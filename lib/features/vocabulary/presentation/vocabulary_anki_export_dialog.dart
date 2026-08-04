/// Export to Anki dialog: filters, Pro gate, progress, save/share.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/features/subscription/application/current_tier_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_anki_export.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_anki_export_io.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_providers.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_anki_export_filters.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_l10n.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Future<void> showVocabularyAnkiExportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const VocabularyAnkiExportDialog(),
  );
}

class VocabularyAnkiExportDialog extends ConsumerStatefulWidget {
  const VocabularyAnkiExportDialog({super.key});

  @override
  ConsumerState<VocabularyAnkiExportDialog> createState() =>
      _VocabularyAnkiExportDialogState();
}

class _VocabularyAnkiExportDialogState
    extends ConsumerState<VocabularyAnkiExportDialog> {
  VocabularyAnkiExportFilters _filters = const VocabularyAnkiExportFilters();
  var _exporting = false;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final status = ref.watch(subscriptionStatusProvider).valueOrNull;
    final isPaid = vocabularyAnkiExportAllowedFrom(
      tier: ref.watch(currentTierProvider),
      subscriptionIsPaid: status?.isPaidTier,
    );
    final itemsAsync = ref.watch(vocabularyItemsProvider);

    return AlertDialog(
      title: Text(l10n.vocabularyExportDialogTitle),
      content: SizedBox(
        width: 420,
        child: itemsAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e'),
          data: (items) {
            if (!isPaid) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.vocabularyProRequiredDescription),
                  SizedBox(height: t.space16),
                  EnjoyButton.primary(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await context.push('/subscription');
                    },
                    child: Text(l10n.vocabularyUpgradeToPro),
                  ),
                ],
              );
            }

            final languages = items.map((i) => i.language).toSet().toList()
              ..sort();
            final filtered = filterVocabularyItemsForAnkiExport(
              items,
              _filters,
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.vocabularyExportSparseCacheHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(height: t.space12),
                TextField(
                  decoration: InputDecoration(
                    hintText: l10n.vocabularySearchPlaceholder,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      setState(() => _filters = _filters.copyWith(query: v)),
                ),
                SizedBox(height: t.space8),
                Wrap(
                  spacing: t.space8,
                  runSpacing: t.space8,
                  children: [
                    DropdownButton<VocabularyStatus?>(
                      value: _filters.status,
                      hint: Text(l10n.vocabularyFilterStatus),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.vocabularyFilterAll),
                        ),
                        for (final s in VocabularyStatus.values)
                          DropdownMenuItem(
                            value: s,
                            child: Text(vocabularyStatusLabel(l10n, s)),
                          ),
                      ],
                      onChanged: _exporting
                          ? null
                          : (v) => setState(() {
                              _filters = v == null
                                  ? _filters.copyWith(clearStatus: true)
                                  : _filters.copyWith(status: v);
                            }),
                    ),
                    DropdownButton<String?>(
                      value: _filters.language,
                      hint: Text(l10n.vocabularyFilterLanguage),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.vocabularyFilterAll),
                        ),
                        for (final lang in languages)
                          DropdownMenuItem(value: lang, child: Text(lang)),
                      ],
                      onChanged: _exporting
                          ? null
                          : (v) => setState(() {
                              _filters = v == null
                                  ? _filters.copyWith(clearLanguage: true)
                                  : _filters.copyWith(language: v);
                            }),
                    ),
                  ],
                ),
                SizedBox(height: t.space8),
                Text(
                  filtered.isEmpty
                      ? l10n.vocabularyNoItemsToExport
                      : '${filtered.length}',
                ),
                if (_exporting) ...[
                  SizedBox(height: t.space12),
                  LinearProgressIndicator(value: _progress.clamp(0.0, 1.0)),
                  SizedBox(height: t.space4),
                  Text(l10n.vocabularyExportProgress),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _exporting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.vocabularyCancel),
        ),
        if (isPaid)
          TextButton(
            onPressed: _exporting ? null : () => _export(context, l10n),
            child: Text(l10n.vocabularyExport),
          ),
      ],
    );
  }

  Future<void> _export(BuildContext context, AppLocalizations l10n) async {
    setState(() {
      _exporting = true;
      _progress = 0;
    });
    try {
      final repo = ref.read(vocabularyRepositoryProvider);
      final status = ref.read(subscriptionStatusProvider).valueOrNull;
      final isPaid = vocabularyAnkiExportAllowedFrom(
        tier: ref.read(currentTierProvider),
        subscriptionIsPaid: status?.isPaidTier,
      );
      final outcome = await runVocabularyAnkiExport(
        isPaid: isPaid,
        listAll: repo.listAll,
        getContextsForItem: repo.getContextsForItem,
        filters: _filters,
        dialogTitle: l10n.vocabularyExportDialogTitle,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!context.mounted) return;
      switch (outcome) {
        case VocabularyAnkiExportIoOutcome.shared:
        case VocabularyAnkiExportIoOutcome.saved:
          AppNotice.success(context, l10n.vocabularyExportSuccess);
          Navigator.of(context).pop();
        case VocabularyAnkiExportIoOutcome.cancelled:
          AppNotice.info(context, l10n.vocabularyExportCancelled);
        case VocabularyAnkiExportIoOutcome.failed:
          AppNotice.error(context, l10n.vocabularyExportError);
      }
    } on StateError catch (e) {
      if (!context.mounted) return;
      if (e.message == 'no_items_to_export') {
        AppNotice.error(context, l10n.vocabularyNoItemsToExport);
      } else if (e.message == 'pro_required') {
        AppNotice.error(context, l10n.vocabularyProRequired);
      } else {
        AppNotice.error(context, l10n.vocabularyExportError);
      }
    } on Object {
      if (!context.mounted) return;
      AppNotice.error(context, l10n.vocabularyExportError);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
