import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  DictationRow row({
    String id = 'd-1',
    String targetType = 'video',
    String targetId = 'v-1',
    int referenceStartMs = 0,
    int referenceDurationMs = 1000,
    String referenceText = 'hello world',
    String language = 'en',
    String userInput = 'hello world',
    int accuracy = 100,
    int correctWords = 2,
    int missedWords = 0,
    int extraWords = 0,
  }) {
    final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    return DictationRow(
      id: id,
      targetType: targetType,
      targetId: targetId,
      referenceStartMs: referenceStartMs,
      referenceDurationMs: referenceDurationMs,
      referenceText: referenceText,
      language: language,
      userInput: userInput,
      accuracy: accuracy,
      correctWords: correctWords,
      missedWords: missedWords,
      extraWords: extraWords,
      createdAt: now,
      updatedAt: now,
      serverUpdatedAt: null,
    );
  }

  group('DictationDao.insertRow', () {
    test('inserts a new row and reads it back', () async {
      await db.dictationDao.insertRow(row(id: 'a'));

      final watched = await db.dictationDao.watchByTarget('video', 'v-1').first;
      expect(watched, hasLength(1));
      expect(watched.single.id, 'a');
      expect(watched.single.referenceText, 'hello world');
    });

    test(
      'insertRow replaces an existing row with the same primary key',
      () async {
        await db.dictationDao.insertRow(row(id: 'dup', accuracy: 80));
        await db.dictationDao.insertRow(row(id: 'dup', accuracy: 95));

        final all = await db.dictationDao.watchByTarget('video', 'v-1').first;
        expect(all, hasLength(1));
        expect(all.single.id, 'dup');
        expect(all.single.accuracy, 95);
      },
    );
  });

  group('DictationDao.deleteId', () {
    test('removes the row with the matching id', () async {
      await db.dictationDao.insertRow(row(id: 'kill', targetId: 'v-99'));
      await db.dictationDao.insertRow(row(id: 'keep', targetId: 'v-99'));

      await db.dictationDao.deleteId('kill');

      final remaining = await db.dictationDao
          .watchByTarget('video', 'v-99')
          .first;
      expect(remaining.map((r) => r.id), ['keep']);
    });

    test('is a no-op when the id does not exist', () async {
      await db.dictationDao.insertRow(row(id: 'alive', targetId: 'v-1'));
      await db.dictationDao.deleteId('does-not-exist');

      final all = await db.dictationDao.watchByTarget('video', 'v-1').first;
      expect(all, hasLength(1));
      expect(all.single.id, 'alive');
    });
  });

  group('DictationDao.watchByTarget', () {
    test('orders by createdAt descending', () async {
      final older = DateTime.utc(2026, 1, 1);
      final newer = DateTime.utc(2026, 6, 1);

      await db.dictationDao.insertRow(
        row(id: 'old', targetId: 'shared').copyWith(createdAt: older),
      );
      await db.dictationDao.insertRow(
        row(id: 'new', targetId: 'shared').copyWith(createdAt: newer),
      );

      final watched = await db.dictationDao
          .watchByTarget('video', 'shared')
          .first;
      expect(watched.map((r) => r.id), ['new', 'old']);
    });

    test('filters by both targetType and targetId', () async {
      await db.dictationDao.insertRow(row(id: '1', targetType: 'video'));
      await db.dictationDao.insertRow(row(id: '2', targetType: 'audio'));
      await db.dictationDao.insertRow(row(id: '3', targetType: 'video'));

      final videos = await db.dictationDao.watchByTarget('video', 'v-1').first;
      expect(videos.map((r) => r.id).toSet(), {'1', '3'});

      final audios = await db.dictationDao.watchByTarget('audio', 'v-1').first;
      expect(audios.map((r) => r.id), ['2']);
    });

    test('emits a new snapshot when data changes (Stream)', () async {
      final streamed = db.dictationDao.watchByTarget('video', 'live');
      final collected = <List<DictationRow>>[];
      final sub = streamed.listen(collected.add);
      await Future<void>.delayed(Duration.zero);
      await db.dictationDao.insertRow(row(id: 'first', targetId: 'live'));
      await Future<void>.delayed(Duration.zero);
      await db.dictationDao.insertRow(row(id: 'second', targetId: 'live'));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      final ids = collected.expand((rows) => rows).map((r) => r.id).toList();
      expect(ids, contains('first'));
      expect(ids, contains('second'));
    });
  });
}

extension on DictationRow {
  // ignore: unused_element
  DictationRow copyWith({DateTime? createdAt}) => DictationRow(
    id: id,
    targetType: targetType,
    targetId: targetId,
    referenceStartMs: referenceStartMs,
    referenceDurationMs: referenceDurationMs,
    referenceText: referenceText,
    language: language,
    userInput: userInput,
    accuracy: accuracy,
    correctWords: correctWords,
    missedWords: missedWords,
    extraWords: extraWords,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt,
    serverUpdatedAt: serverUpdatedAt,
  );
}
