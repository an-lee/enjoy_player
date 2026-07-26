import 'package:enjoy_player/features/vocabulary/domain/vocabulary_anki_export_filters.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-01-01T00:00:00.000Z';

VocabularyItem _item({
  required String id,
  required String word,
  String language = 'en',
  VocabularyStatus status = VocabularyStatus.new_,
}) {
  final now = DateTime.parse(_now);
  return VocabularyItem(
    id: id,
    word: word,
    language: language,
    targetLanguage: 'zh',
    status: status,
    easeFactor: 2.5,
    interval: 0,
    nextReviewAt: now,
    reviewsCount: 0,
    contextsCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('VocabularyAnkiExportFilters.copyWith', () {
    test('returns equivalent filter when nothing is overridden', () {
      const filters = VocabularyAnkiExportFilters(
        query: 'hello',
        status: VocabularyStatus.learning,
        language: 'en',
      );
      final copy = filters.copyWith();
      expect(copy.query, 'hello');
      expect(copy.status, VocabularyStatus.learning);
      expect(copy.language, 'en');
    });

    test('overrides query only', () {
      const filters = VocabularyAnkiExportFilters(query: 'old');
      final updated = filters.copyWith(query: 'new');
      expect(updated.query, 'new');
    });

    test('overrides status only', () {
      const filters = VocabularyAnkiExportFilters(
        status: VocabularyStatus.new_,
      );
      final updated = filters.copyWith(status: VocabularyStatus.learning);
      expect(updated.status, VocabularyStatus.learning);
    });

    test('clearStatus=true clears status back to null', () {
      const filters = VocabularyAnkiExportFilters(
        status: VocabularyStatus.learning,
      );
      final updated = filters.copyWith(clearStatus: true);
      expect(updated.status, isNull);
    });

    test('clearLanguage=true clears language back to null', () {
      const filters = VocabularyAnkiExportFilters(language: 'en');
      final updated = filters.copyWith(clearLanguage: true);
      expect(updated.language, isNull);
    });

    test('clearStatus=false with no status keeps existing status', () {
      const filters = VocabularyAnkiExportFilters(
        status: VocabularyStatus.learning,
      );
      final updated = filters.copyWith();
      expect(updated.status, VocabularyStatus.learning);
    });
  });

  group('filterVocabularyItemsForAnkiExport', () {
    final items = <VocabularyItem>[
      _item(id: '1', word: 'hello', language: 'en'),
      _item(id: '2', word: 'world', language: 'en'),
      _item(id: '3', word: 'hola', language: 'es'),
      _item(
        id: '4',
        word: 'learned',
        language: 'en',
        status: VocabularyStatus.learning,
      ),
      _item(
        id: '5',
        word: 'mastered',
        language: 'en',
        status: VocabularyStatus.mastered,
      ),
    ];

    test('returns all items when filters are empty', () {
      final out = filterVocabularyItemsForAnkiExport(
        items,
        const VocabularyAnkiExportFilters(),
      );
      expect(out, hasLength(5));
    });

    test('filters by status', () {
      final out = filterVocabularyItemsForAnkiExport(
        items,
        const VocabularyAnkiExportFilters(status: VocabularyStatus.learning),
      );
      expect(out.map((i) => i.id), <String>['4']);
    });

    test('filters by language', () {
      final out = filterVocabularyItemsForAnkiExport(
        items,
        const VocabularyAnkiExportFilters(language: 'es'),
      );
      expect(out.map((i) => i.id), <String>['3']);
    });

    test('status + language combined (intersection)', () {
      final out = filterVocabularyItemsForAnkiExport(
        items,
        const VocabularyAnkiExportFilters(
          status: VocabularyStatus.learning,
          language: 'en',
        ),
      );
      expect(out.map((i) => i.id), <String>['4']);
    });

    test('query matches word substring case-insensitively', () {
      final out = filterVocabularyItemsForAnkiExport(
        items,
        const VocabularyAnkiExportFilters(query: 'HEL'),
      );
      expect(out.map((i) => i.id), <String>['1']);
    });

    test('empty query is treated as no filter', () {
      final out = filterVocabularyItemsForAnkiExport(
        items,
        const VocabularyAnkiExportFilters(query: '   '),
      );
      expect(out, hasLength(5));
    });

    test('query does not match anything when no word or language matches', () {
      final out = filterVocabularyItemsForAnkiExport(
        items,
        const VocabularyAnkiExportFilters(query: 'xyz123'),
      );
      expect(out, isEmpty);
    });

    test('language filter does not crash on empty items list', () {
      expect(
        filterVocabularyItemsForAnkiExport(
          const <VocabularyItem>[],
          const VocabularyAnkiExportFilters(language: 'en'),
        ),
        isEmpty,
      );
    });
  });
}
