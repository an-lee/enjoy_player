import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

TranscriptRow _transcript({
  String id = 't-1',
  String targetType = 'video',
  String targetId = 'v-1',
  String language = 'en',
  String source = 'manual',
  String timelineJson = '{"cues":[]}',
  String? referenceId,
  String label = 'primary',
  int? trackIndex,
}) {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  return TranscriptRow(
    id: id,
    targetType: targetType,
    targetId: targetId,
    language: language,
    source: source,
    timelineJson: timelineJson,
    referenceId: referenceId,
    label: label,
    trackIndex: trackIndex,
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

  group('TranscriptDao', () {
    test('upsert persists and getById reads it back', () async {
      await db.transcriptDao.upsert(_transcript(id: 't-1'));
      final found = await db.transcriptDao.getById('t-1');
      expect(found, isNotNull);
      expect(found!.language, 'en');
    });

    test('getById returns null for missing id', () async {
      expect(await db.transcriptDao.getById('missing'), isNull);
    });

    test('upsert replaces by primary key', () async {
      await db.transcriptDao.upsert(_transcript(id: 't-1', label: 'first'));
      await db.transcriptDao.upsert(_transcript(id: 't-1', label: 'second'));
      final found = await db.transcriptDao.getById('t-1');
      expect(found!.label, 'second');
    });

    test('listForTarget returns matching transcripts only', () async {
      await db.transcriptDao.upsert(
        _transcript(id: 't-1', targetType: 'video', targetId: 'v-1'),
      );
      await db.transcriptDao.upsert(
        _transcript(id: 't-2', targetType: 'video', targetId: 'v-1'),
      );
      await db.transcriptDao.upsert(
        _transcript(id: 't-3', targetType: 'video', targetId: 'v-2'),
      );
      final list = await db.transcriptDao.listForTarget('video', 'v-1');
      expect(list.map((r) => r.id), unorderedEquals(['t-1', 't-2']));
    });

    test('listForTarget returns empty for unknown target', () async {
      await db.transcriptDao.upsert(_transcript(id: 't-1'));
      expect(await db.transcriptDao.listForTarget('video', 'unknown'), isEmpty);
    });

    test('deleteId removes the row', () async {
      await db.transcriptDao.upsert(_transcript(id: 'kill'));
      await db.transcriptDao.upsert(_transcript(id: 'keep'));
      await db.transcriptDao.deleteId('kill');
      expect(await db.transcriptDao.getById('kill'), isNull);
      expect(await db.transcriptDao.getById('keep'), isNotNull);
    });

    test('watchForTarget orders by language ascending', () async {
      await db.transcriptDao.upsert(_transcript(id: 't-1', language: 'zh'));
      await db.transcriptDao.upsert(_transcript(id: 't-2', language: 'en'));
      await db.transcriptDao.upsert(_transcript(id: 't-3', language: 'ja'));
      final list = await db.transcriptDao.watchForTarget('video', 'v-1').first;
      expect(list.map((r) => r.language), ['en', 'ja', 'zh']);
    });

    test('watchForTarget filters by target', () async {
      await db.transcriptDao.upsert(_transcript(id: 't-1', targetId: 'v-1'));
      await db.transcriptDao.upsert(_transcript(id: 't-2', targetId: 'v-2'));
      final list = await db.transcriptDao.watchForTarget('video', 'v-1').first;
      expect(list.single.id, 't-1');
    });

    test('watchAllForTarget orders by source, language, createdAt', () async {
      final earlier = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final later = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      await db.transcriptDao.upsert(
        _transcript(
          id: 't-1',
          source: 'yt',
          language: 'en',
        ).copyWith(createdAt: later),
      );
      await db.transcriptDao.upsert(
        _transcript(
          id: 't-2',
          source: 'yt',
          language: 'zh',
        ).copyWith(createdAt: earlier),
      );
      await db.transcriptDao.upsert(
        _transcript(
          id: 't-3',
          source: 'manual',
          language: 'en',
        ).copyWith(createdAt: earlier),
      );
      final list = await db.transcriptDao
          .watchAllForTarget('video', 'v-1')
          .first;
      // manual < yt, then en < zh within yt
      expect(list.map((r) => r.id), ['t-3', 't-1', 't-2']);
    });

    test('watchExistsForTarget emits false when empty', () async {
      final exists = await db.transcriptDao
          .watchExistsForTarget('video', 'unknown')
          .first;
      expect(exists, isFalse);
    });

    test('watchExistsForTarget emits true after insert', () async {
      await db.transcriptDao.upsert(_transcript(id: 't-1'));
      final exists = await db.transcriptDao
          .watchExistsForTarget('video', 'v-1')
          .first;
      expect(exists, isTrue);
    });

    test('watchExistsForTarget emits false again after delete', () async {
      await db.transcriptDao.upsert(_transcript(id: 't-1'));
      await db.transcriptDao.deleteId('t-1');
      final exists = await db.transcriptDao
          .watchExistsForTarget('video', 'v-1')
          .first;
      expect(exists, isFalse);
    });
  });
}
