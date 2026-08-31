import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:flutter_test/flutter_test.dart';

VocabularyItem _item({
  String id = 'item-1',
  String word = 'hola',
  String language = 'es',
  String targetLanguage = 'en',
  VocabularyStatus status = VocabularyStatus.new_,
  double easeFactor = 2.5,
  int interval = 0,
  int reviewsCount = 0,
  DateTime? lastReviewedAt,
  int contextsCount = 0,
  String? explanation,
  String? syncStatus,
  DateTime? serverUpdatedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 1, 1);
  return VocabularyItem(
    id: id,
    word: word,
    language: language,
    targetLanguage: targetLanguage,
    status: status,
    easeFactor: easeFactor,
    interval: interval,
    nextReviewAt: DateTime.utc(2026, 6, 15, 12),
    reviewsCount: reviewsCount,
    lastReviewedAt: lastReviewedAt,
    contextsCount: contextsCount,
    explanation: explanation,
    syncStatus: syncStatus,
    serverUpdatedAt: serverUpdatedAt,
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}

VocabularyContext _context({
  String id = 'ctx-1',
  String vocabularyItemId = 'item-1',
  String text = 'hola mundo',
  VocabularySourceType sourceType = VocabularySourceType.video,
  String sourceId = 'src-1',
  MediaLocator? locator,
  EbookLocator? ebookLocator,
  String? explanation,
  String? syncStatus,
  DateTime? serverUpdatedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 1, 1);
  return VocabularyContext(
    id: id,
    vocabularyItemId: vocabularyItemId,
    text: text,
    sourceType: sourceType,
    sourceId: sourceId,
    locator: locator,
    ebookLocator: ebookLocator,
    explanation: explanation,
    syncStatus: syncStatus,
    serverUpdatedAt: serverUpdatedAt,
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}

void main() {
  group('VocabularyItem equality', () {
    test('identical records are equal', () {
      final a = _item();
      final b = _item();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('identical-this is short-circuited', () {
      final a = _item();
      expect(a, equals(a));
    });

    test('non-VocabularyItem is not equal', () {
      final a = _item();
      expect(a == Object(), isFalse);
      expect(identical(a, a), isTrue);
    });

    test('per-field inequality — one assertion per field', () {
      final base = _item();
      expect(base == _item(id: 'x'), isFalse, reason: 'id');
      expect(base == _item(word: 'adios'), isFalse, reason: 'word');
      expect(base == _item(language: 'fr'), isFalse, reason: 'language');
      expect(
        base == _item(targetLanguage: 'de'),
        isFalse,
        reason: 'targetLanguage',
      );
      expect(
        base == _item(status: VocabularyStatus.mastered),
        isFalse,
        reason: 'status',
      );
      expect(base == _item(easeFactor: 3.0), isFalse, reason: 'easeFactor');
      expect(base == _item(interval: 7), isFalse, reason: 'interval');
      expect(base == _item(reviewsCount: 1), isFalse, reason: 'reviewsCount');
      expect(
        base == _item(lastReviewedAt: DateTime.utc(2026, 5, 1)),
        isFalse,
        reason: 'lastReviewedAt',
      );
      expect(base == _item(contextsCount: 1), isFalse, reason: 'contextsCount');
      expect(base == _item(explanation: '{}'), isFalse, reason: 'explanation');
      expect(
        base == _item(syncStatus: 'pending'),
        isFalse,
        reason: 'syncStatus',
      );
      expect(
        base == _item(serverUpdatedAt: DateTime.utc(2026, 5, 2)),
        isFalse,
        reason: 'serverUpdatedAt',
      );
      expect(
        base ==
            _item(
              createdAt: DateTime.utc(2026, 2, 1),
              updatedAt: DateTime.utc(2026, 2, 1),
            ),
        isFalse,
        reason: 'createdAt/updatedAt',
      );
    });
  });

  group('VocabularyContext equality', () {
    test('identical records are equal', () {
      final a = _context();
      final b = _context();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('identical-this is short-circuited', () {
      final a = _context();
      expect(a, equals(a));
    });

    test('non-VocabularyContext is not equal', () {
      final a = _context();
      expect(a == Object(), isFalse);
      expect(identical(a, a), isTrue);
    });

    test('per-field inequality — one assertion per field', () {
      final base = _context();
      expect(base == _context(id: 'x'), isFalse, reason: 'id');
      expect(
        base == _context(vocabularyItemId: 'item-2'),
        isFalse,
        reason: 'vocabularyItemId',
      );
      expect(base == _context(text: 'hola amigo'), isFalse, reason: 'text');
      expect(
        base == _context(sourceType: VocabularySourceType.audio),
        isFalse,
        reason: 'sourceType',
      );
      expect(base == _context(sourceId: 'src-2'), isFalse, reason: 'sourceId');
      expect(
        base ==
            _context(locator: const MediaLocator(start: 1000, duration: 500)),
        isFalse,
        reason: 'locator',
      );
      expect(
        base ==
            _context(
              ebookLocator: const EbookLocator(
                href: 'ch01.xhtml',
                locatorType: 'application/xhtml+xml',
              ),
            ),
        isFalse,
        reason: 'ebookLocator',
      );
      expect(
        base == _context(explanation: '{}'),
        isFalse,
        reason: 'explanation',
      );
      expect(
        base == _context(syncStatus: 'pending'),
        isFalse,
        reason: 'syncStatus',
      );
      expect(
        base == _context(serverUpdatedAt: DateTime.utc(2026, 5, 2)),
        isFalse,
        reason: 'serverUpdatedAt',
      );
      expect(
        base ==
            _context(
              createdAt: DateTime.utc(2026, 2, 1),
              updatedAt: DateTime.utc(2026, 2, 1),
            ),
        isFalse,
        reason: 'createdAt/updatedAt',
      );
    });
  });
}
