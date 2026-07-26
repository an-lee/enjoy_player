import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

VocabularyItemRow _vocabItem({
  String id = 'vi-1',
  String word = 'hello',
  String language = 'en',
  String targetLanguage = 'zh',
  String status = 'new',
  double easeFactor = 2.5,
  int interval = 0,
  DateTime? lastReviewedAt,
  DateTime? nextReviewAt,
  int reviewsCount = 0,
  int contextsCount = 0,
}) {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  return VocabularyItemRow(
    id: id,
    word: word,
    language: language,
    targetLanguage: targetLanguage,
    status: status,
    easeFactor: easeFactor,
    interval: interval,
    lastReviewedAt: lastReviewedAt,
    nextReviewAt: nextReviewAt ?? now,
    reviewsCount: reviewsCount,
    contextsCount: contextsCount,
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

  group('VocabularyItemDao', () {
    test('insertRow persists and getById reads it back', () async {
      await db.vocabularyItemDao.insertRow(_vocabItem(id: 'a'));
      final found = await db.vocabularyItemDao.getById('a');
      expect(found, isNotNull);
      expect(found!.word, 'hello');
    });

    test('getById returns null for missing id', () async {
      expect(await db.vocabularyItemDao.getById('missing'), isNull);
    });

    test('getByWordLanguageTarget filters by all three fields', () async {
      await db.vocabularyItemDao.insertRow(
        _vocabItem(
          id: 'a',
          word: 'hello',
          language: 'en',
          targetLanguage: 'zh',
        ),
      );
      await db.vocabularyItemDao.insertRow(
        _vocabItem(
          id: 'b',
          word: 'world',
          language: 'en',
          targetLanguage: 'zh',
        ),
      );
      await db.vocabularyItemDao.insertRow(
        _vocabItem(
          id: 'c',
          word: 'hello',
          language: 'en',
          targetLanguage: 'ja',
        ),
      );
      await db.vocabularyItemDao.insertRow(
        _vocabItem(
          id: 'd',
          word: 'hello',
          language: 'fr',
          targetLanguage: 'zh',
        ),
      );
      final found = await db.vocabularyItemDao.getByWordLanguageTarget(
        word: 'hello',
        language: 'en',
        targetLanguage: 'zh',
      );
      expect(found, isNotNull);
      expect(found!.id, 'a');
    });

    test('getByWordLanguageTarget returns null when no match', () async {
      await db.vocabularyItemDao.insertRow(_vocabItem(id: 'a'));
      expect(
        await db.vocabularyItemDao.getByWordLanguageTarget(
          word: 'missing',
          language: 'en',
          targetLanguage: 'zh',
        ),
        isNull,
      );
    });

    test('updateRow replaces by primary key', () async {
      await db.vocabularyItemDao.insertRow(_vocabItem(id: 'a', word: 'first'));
      await db.vocabularyItemDao.updateRow(_vocabItem(id: 'a', word: 'second'));
      final found = await db.vocabularyItemDao.getById('a');
      expect(found!.word, 'second');
    });

    test('deleteById removes the row', () async {
      await db.vocabularyItemDao.insertRow(_vocabItem(id: 'kill'));
      await db.vocabularyItemDao.insertRow(_vocabItem(id: 'keep'));
      final deleted = await db.vocabularyItemDao.deleteById('kill');
      expect(deleted, 1);
      expect(await db.vocabularyItemDao.getById('kill'), isNull);
      expect(await db.vocabularyItemDao.getById('keep'), isNotNull);
    });

    test('listAll returns every row', () async {
      await db.vocabularyItemDao.insertRow(_vocabItem(id: 'a'));
      await db.vocabularyItemDao.insertRow(_vocabItem(id: 'b'));
      final all = await db.vocabularyItemDao.listAll();
      expect(all.map((r) => r.id), unorderedEquals(['a', 'b']));
    });

    test('watchAll emits a stream of all rows', () async {
      await db.vocabularyItemDao.insertRow(_vocabItem(id: 'a'));
      await db.vocabularyItemDao.insertRow(_vocabItem(id: 'b'));
      final list = await db.vocabularyItemDao.watchAll().first;
      expect(list.map((r) => r.id), unorderedEquals(['a', 'b']));
    });

    test('listDue returns rows with nextReviewAt <= now', () async {
      final now = DateTime.utc(2026, 7, 1);
      await db.vocabularyItemDao.insertRow(
        _vocabItem(
          id: 'due-1',
          nextReviewAt: now.subtract(const Duration(days: 2)),
        ),
      );
      await db.vocabularyItemDao.insertRow(
        _vocabItem(id: 'due-2', nextReviewAt: now),
      );
      await db.vocabularyItemDao.insertRow(
        _vocabItem(
          id: 'future',
          nextReviewAt: now.add(const Duration(days: 5)),
        ),
      );
      final due = await db.vocabularyItemDao.listDue(now);
      expect(due.map((r) => r.id), unorderedEquals(['due-1', 'due-2']));
    });

    test(
      'listDue filters rows whose nextReviewAt is not after lastReviewedAt',
      () async {
        final now = DateTime.utc(2026, 7, 1);
        // reviewed before, due in past — eligible (nextReviewAt after review)
        await db.vocabularyItemDao.insertRow(
          _vocabItem(
            id: 'reviewed-due',
            nextReviewAt: now.subtract(const Duration(days: 1)),
            lastReviewedAt: now.subtract(const Duration(days: 5)),
          ),
        );
        // nextReviewAt still in past relative to last review — not eligible
        // (system has not yet updated nextReviewAt after the most recent
        // review).
        await db.vocabularyItemDao.insertRow(
          _vocabItem(
            id: 'reviewed-not-scheduled',
            nextReviewAt: now.subtract(const Duration(days: 1)),
            lastReviewedAt: now.subtract(const Duration(hours: 1)),
          ),
        );
        // reviewed in future relative to last review (scheduling race) — skip
        await db.vocabularyItemDao.insertRow(
          _vocabItem(
            id: 'reviewed-future-skip',
            nextReviewAt: now.add(const Duration(days: 10)),
            lastReviewedAt: now,
          ),
        );
        final due = await db.vocabularyItemDao.listDue(now);
        expect(due.map((r) => r.id), ['reviewed-due']);
      },
    );
  });
}
