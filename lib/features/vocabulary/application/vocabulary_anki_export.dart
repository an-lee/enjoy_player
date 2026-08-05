/// Orchestrates paid-tier-gated Anki CSV export.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/subscription/application/current_tier_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_anki_export_io.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_providers.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_anki_csv.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_anki_export_filters.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';

/// Whether the current session may export Anki CSV (paid tier when known).
bool vocabularyAnkiExportAllowedFrom({
  required SubscriptionTier tier,
  bool? subscriptionIsPaid,
}) {
  if (subscriptionIsPaid != null) return subscriptionIsPaid;
  return tier != SubscriptionTier.free;
}

/// Convenience for Riverpod [Ref] / test containers.
bool vocabularyAnkiExportAllowed(Ref ref) {
  final status = ref.read(subscriptionStatusProvider).valueOrNull;
  return vocabularyAnkiExportAllowedFrom(
    tier: ref.read(currentTierProvider),
    subscriptionIsPaid: status?.isPaidTier,
  );
}

final class VocabularyAnkiExportBundle {
  const VocabularyAnkiExportBundle({
    required this.items,
    required this.contextsByItemId,
    required this.csv,
    required this.bytes,
  });

  final List<VocabularyItem> items;
  final Map<String, List<VocabularyContext>> contextsByItemId;
  final String csv;
  final Uint8List bytes;
}

/// Loads filtered items + contexts and builds CSV. Throws [StateError] if empty.
Future<VocabularyAnkiExportBundle> buildVocabularyAnkiExport({
  required Future<List<VocabularyItem>> Function() listAll,
  required Future<List<VocabularyContext>> Function(String itemId)
  getContextsForItem,
  required VocabularyAnkiExportFilters filters,
  Map<String, AnkiSourceReference> sourceRefs = const {},
  void Function(double progress)? onProgress,
}) async {
  onProgress?.call(0.1);
  final all = await listAll();
  final items = filterVocabularyItemsForAnkiExport(all, filters);
  if (items.isEmpty) {
    throw StateError('no_items_to_export');
  }
  onProgress?.call(0.3);
  final contextsByItemId = <String, List<VocabularyContext>>{};
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    contextsByItemId[item.id] = await getContextsForItem(item.id);
    onProgress?.call(0.3 + 0.4 * ((i + 1) / items.length));
  }
  onProgress?.call(0.8);
  final csv = exportVocabularyToAnkiCsv(
    items: items,
    contextsByItemId: contextsByItemId,
    sourceRefs: sourceRefs,
  );
  final bytes = Uint8List.fromList(ankiCsvWithBomBytes(csv));
  onProgress?.call(1.0);
  return VocabularyAnkiExportBundle(
    items: items,
    contextsByItemId: contextsByItemId,
    csv: csv,
    bytes: bytes,
  );
}

Future<VocabularyAnkiExportIoOutcome> runVocabularyAnkiExport({
  required bool isPaid,
  required Future<List<VocabularyItem>> Function() listAll,
  required Future<List<VocabularyContext>> Function(String itemId)
  getContextsForItem,
  required VocabularyAnkiExportFilters filters,
  String? dialogTitle,
  void Function(double progress)? onProgress,
}) async {
  if (!isPaid) {
    throw StateError('paid_required');
  }
  final bundle = await buildVocabularyAnkiExport(
    listAll: listAll,
    getContextsForItem: getContextsForItem,
    filters: filters,
    onProgress: onProgress,
  );
  return saveOrShareAnkiCsv(bytes: bundle.bytes, dialogTitle: dialogTitle);
}

/// Riverpod-wired export (for callers with a [Ref]).
Future<VocabularyAnkiExportIoOutcome> runVocabularyAnkiExportWithRef({
  required Ref ref,
  required VocabularyAnkiExportFilters filters,
  String? dialogTitle,
  void Function(double progress)? onProgress,
}) {
  final repo = ref.read(vocabularyRepositoryProvider);
  return runVocabularyAnkiExport(
    isPaid: vocabularyAnkiExportAllowed(ref),
    listAll: repo.listAll,
    getContextsForItem: repo.getContextsForItem,
    filters: filters,
    dialogTitle: dialogTitle,
    onProgress: onProgress,
  );
}
