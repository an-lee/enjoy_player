import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_anki_export.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_anki_export_filters.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';

void main() {
  group('vocabularyAnkiExportAllowedFrom', () {
    test('uses subscriptionIsPaid when provided', () {
      expect(
        vocabularyAnkiExportAllowedFrom(
          tier: SubscriptionTier.free,
          subscriptionIsPaid: true,
        ),
        isTrue,
      );
      expect(
        vocabularyAnkiExportAllowedFrom(
          tier: SubscriptionTier.lite,
          subscriptionIsPaid: false,
        ),
        isFalse,
      );
      expect(
        vocabularyAnkiExportAllowedFrom(
          tier: SubscriptionTier.pro,
          subscriptionIsPaid: false,
        ),
        isFalse,
      );
    });

    test('falls back to tier when subscriptionIsPaid is null', () {
      expect(
        vocabularyAnkiExportAllowedFrom(tier: SubscriptionTier.pro),
        isTrue,
      );
      expect(
        vocabularyAnkiExportAllowedFrom(tier: SubscriptionTier.lite),
        isTrue,
      );
      expect(
        vocabularyAnkiExportAllowedFrom(tier: SubscriptionTier.free),
        isFalse,
      );
    });
  });

  group('runVocabularyAnkiExport', () {
    test('throws paid_required when not paid', () async {
      expect(
        () => runVocabularyAnkiExport(
          isPaid: false,
          listAll: () async => const [],
          getContextsForItem: (_) async => const [],
          filters: const VocabularyAnkiExportFilters(),
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'paid_required'),
        ),
      );
    });

    test('throws no_items_to_export when filtered empty', () async {
      final now = DateTime.utc(2026, 1, 1);
      final items = [
        VocabularyItem(
          id: '1',
          word: 'hello',
          language: 'en',
          targetLanguage: 'zh',
          status: VocabularyStatus.new_,
          easeFactor: 2.5,
          interval: 0,
          nextReviewAt: now,
          reviewsCount: 0,
          contextsCount: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      expect(
        () => runVocabularyAnkiExport(
          isPaid: true,
          listAll: () async => items,
          getContextsForItem: (_) async => const [],
          filters: const VocabularyAnkiExportFilters(
            status: VocabularyStatus.mastered,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'no_items_to_export',
          ),
        ),
      );
    });
  });
}
