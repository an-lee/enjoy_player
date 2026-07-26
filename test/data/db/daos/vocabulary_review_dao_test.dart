import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

VocabularyReviewRow _vocabReview({
  String id = 'vr-1',
  String vocabularyItemId = 'vi-1',
  int rating = 3,
  DateTime? at,
  double easeFactorBefore = 2.5,
  int intervalBefore = 0,
  String statusBefore = 'new',
  int reviewsCountBefore = 0,
  DateTime? nextReviewAtBefore,
  DateTime? lastReviewedAtBefore,
}) {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  return VocabularyReviewRow(
    id: id,
    vocabularyItemId: vocabularyItemId,
    rating: rating,
    at: at ?? now,
    easeFactorBefore: easeFactorBefore,
    intervalBefore: intervalBefore,
    statusBefore: statusBefore,
    reviewsCountBefore: reviewsCountBefore,
    nextReviewAtBefore: nextReviewAtBefore ?? now,
    lastReviewedAtBefore: lastReviewedAtBefore,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('VocabularyReviewDao', () {
    test('insertRow persists a review', () async {
      await db.vocabularyReviewDao.insertRow(_vocabReview(id: 'a'));
      // No public read API exists — verify by deleteById round-trip.
      final deleted = await db.vocabularyReviewDao.deleteById('a');
      expect(deleted, 1);
    });

    test('latestForItem returns the most recent review', () async {
      final earlier = DateTime.utc(2026, 1, 1);
      final later = DateTime.utc(2026, 7, 1);
      await db.vocabularyReviewDao.insertRow(
        _vocabReview(id: 'old', at: earlier),
      );
      await db.vocabularyReviewDao.insertRow(
        _vocabReview(id: 'new', at: later),
      );
      await db.vocabularyReviewDao.insertRow(
        _vocabReview(id: 'other-item', vocabularyItemId: 'vi-2', at: later),
      );
      final latest = await db.vocabularyReviewDao.latestForItem('vi-1');
      expect(latest, isNotNull);
      expect(latest!.id, 'new');
    });

    test('latestForItem returns null for unknown item', () async {
      expect(await db.vocabularyReviewDao.latestForItem('unknown'), isNull);
    });

    test('deleteByItemId removes all reviews for the item', () async {
      await db.vocabularyReviewDao.insertRow(
        _vocabReview(id: 'a', vocabularyItemId: 'vi-1'),
      );
      await db.vocabularyReviewDao.insertRow(
        _vocabReview(id: 'b', vocabularyItemId: 'vi-1'),
      );
      await db.vocabularyReviewDao.insertRow(
        _vocabReview(id: 'c', vocabularyItemId: 'vi-2'),
      );
      final deleted = await db.vocabularyReviewDao.deleteByItemId('vi-1');
      expect(deleted, 2);
      expect(await db.vocabularyReviewDao.deleteByItemId('vi-1'), 0);
      expect(await db.vocabularyReviewDao.deleteByItemId('vi-2'), 1);
    });

    test('deleteById is a no-op for missing id', () async {
      final deleted = await db.vocabularyReviewDao.deleteById('missing');
      expect(deleted, 0);
    });
  });
}
