import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

VocabularyContextRow _vocabContext({
  String id = 'c-1',
  String vocabularyItemId = 'v-1',
  String contextText = 'ctx',
  String sourceType = 'video',
  String sourceId = 's-1',
  String locatorJson = '{}',
  String? explanation,
}) {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  return VocabularyContextRow(
    id: id,
    vocabularyItemId: vocabularyItemId,
    contextText: contextText,
    sourceType: sourceType,
    sourceId: sourceId,
    locatorJson: locatorJson,
    explanation: explanation,
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

  group('VocabularyContextDao', () {
    test('insertRow persists and getById reads it back', () async {
      await db.vocabularyContextDao.insertRow(_vocabContext(id: 'a'));
      final found = await db.vocabularyContextDao.getById('a');
      expect(found, isNotNull);
      expect(found!.vocabularyItemId, 'v-1');
      expect(found.contextText, 'ctx');
    });

    test('getById returns null for missing id', () async {
      expect(await db.vocabularyContextDao.getById('nope'), isNull);
    });

    test('getByItemId returns contexts grouped by item id', () async {
      await db.vocabularyContextDao.insertRow(
        _vocabContext(id: 'a', vocabularyItemId: 'item-1'),
      );
      await db.vocabularyContextDao.insertRow(
        _vocabContext(id: 'b', vocabularyItemId: 'item-1'),
      );
      await db.vocabularyContextDao.insertRow(
        _vocabContext(id: 'c', vocabularyItemId: 'item-2'),
      );
      final item1 = await db.vocabularyContextDao.getByItemId('item-1');
      expect(item1.map((r) => r.id), unorderedEquals(['a', 'b']));
      final item2 = await db.vocabularyContextDao.getByItemId('item-2');
      expect(item2.single.id, 'c');
      expect(await db.vocabularyContextDao.getByItemId('item-3'), isEmpty);
    });

    test('getByItemAndSource filters on source type and id', () async {
      await db.vocabularyContextDao.insertRow(
        _vocabContext(
          id: 'a',
          vocabularyItemId: 'item-1',
          sourceType: 'video',
          sourceId: 's-1',
        ),
      );
      await db.vocabularyContextDao.insertRow(
        _vocabContext(
          id: 'b',
          vocabularyItemId: 'item-1',
          sourceType: 'audio',
          sourceId: 's-1',
        ),
      );
      await db.vocabularyContextDao.insertRow(
        _vocabContext(
          id: 'c',
          vocabularyItemId: 'item-1',
          sourceType: 'video',
          sourceId: 's-2',
        ),
      );
      final found = await db.vocabularyContextDao.getByItemAndSource(
        vocabularyItemId: 'item-1',
        sourceType: 'video',
        sourceId: 's-1',
      );
      expect(found.single.id, 'a');
    });

    test('getByItemAndSource returns empty when source differs', () async {
      await db.vocabularyContextDao.insertRow(_vocabContext(id: 'a'));
      final found = await db.vocabularyContextDao.getByItemAndSource(
        vocabularyItemId: 'v-1',
        sourceType: 'audio',
        sourceId: 's-1',
      );
      expect(found, isEmpty);
    });

    test('updateRow replaces an existing row by primary key', () async {
      await db.vocabularyContextDao.insertRow(
        _vocabContext(id: 'a', contextText: 'first'),
      );
      await db.vocabularyContextDao.updateRow(
        _vocabContext(id: 'a', contextText: 'second'),
      );
      final found = await db.vocabularyContextDao.getById('a');
      expect(found!.contextText, 'second');
    });

    test('deleteByItemId removes all rows for the item', () async {
      await db.vocabularyContextDao.insertRow(
        _vocabContext(id: 'a', vocabularyItemId: 'item-1'),
      );
      await db.vocabularyContextDao.insertRow(
        _vocabContext(id: 'b', vocabularyItemId: 'item-1'),
      );
      await db.vocabularyContextDao.insertRow(
        _vocabContext(id: 'c', vocabularyItemId: 'item-2'),
      );
      final deleted = await db.vocabularyContextDao.deleteByItemId('item-1');
      expect(deleted, 2);
      expect(await db.vocabularyContextDao.getByItemId('item-1'), isEmpty);
      expect(
        (await db.vocabularyContextDao.getByItemId('item-2')).single.id,
        'c',
      );
    });

    test('deleteByItemId is a no-op when nothing matches', () async {
      await db.vocabularyContextDao.insertRow(
        _vocabContext(id: 'a', vocabularyItemId: 'item-1'),
      );
      final deleted = await db.vocabularyContextDao.deleteByItemId('item-99');
      expect(deleted, 0);
      expect(
        (await db.vocabularyContextDao.getByItemId('item-1')).single.id,
        'a',
      );
    });
  });
}
