import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/files/file_storage.dart';
import 'package:enjoy_player/features/craft/data/craft_library_repository.dart';
import 'package:enjoy_player/features/sync/domain/sync_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../support/test_path_provider.dart';

const _testUserId = 'test-user';

String _solidTimeline([String text = 'Hello world.']) => jsonEncode([
  {'text': text, 'start': 0, 'duration': 1000},
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CraftLibraryRepository.importCraftedFromText', () {
    late PathProviderPlatform original;
    late Directory root;
    late AppDatabase db;
    late CraftLibraryRepository repo;

    setUp(() {
      original = PathProviderPlatform.instance;
      root = Directory.systemTemp.createTempSync('enjoy_craft_repo_test');
      PathProviderPlatform.instance = TestPathProvider(root.path);
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = CraftLibraryRepository(db, FileStorage());
    });

    tearDown(() async {
      PathProviderPlatform.instance = original;
      await db.close();
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    test('Speak directly writes audio row + primary transcript', () async {
      final audioBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final id = await repo.importCraftedFromText(
        audioBytes: audioBytes,
        audioFormat: 'wav',
        learningLanguage: 'en',
        sourceLanguage: null,
        text: 'Hello, this is a test sentence for synthesis.',
        normalizedText: 'Hello, this is a test sentence for synthesis.',
        primaryTimelineJson: _solidTimeline(
          'Hello, this is a test sentence for synthesis.',
        ),
        sourceFlag: 'craft-direct',
        signedInUserId: _testUserId,
      );

      // Audio row exists with provider = craft.
      final audioRow = await db.audioDao.getById(id);
      expect(audioRow, isNotNull);
      expect(audioRow!.provider, 'craft');
      expect(audioRow.source, 'craft-direct');
      expect(audioRow.language, 'en-US');
      expect(
        audioRow.sourceText,
        'Hello, this is a test sentence for synthesis.',
      );

      // Primary transcript exists.
      final transcripts = await db.transcriptDao.listForTarget('Audio', id);
      expect(transcripts, hasLength(1));
      expect(transcripts.first.source, 'ai');
      expect(transcripts.first.language.startsWith('en'), isTrue);
    });

    test(
      'Translate then speak writes only the learning-language transcript',
      () async {
        final audioBytes = Uint8List.fromList([10, 20, 30]);

        final id = await repo.importCraftedFromText(
          audioBytes: audioBytes,
          audioFormat: 'wav',
          learningLanguage: 'zh',
          sourceLanguage: 'en',
          text: 'Hello world this is a test.',
          normalizedText: 'Hello world this is a test.',
          primaryTimelineJson: _solidTimeline('Hello world this is a test.'),
          sourceFlag: 'craft-translate',
          signedInUserId: _testUserId,
        );

        // Only one transcript: the learning-language (zh) target.
        // The source-language text is stored on the audio row's sourceText
        // column but is NOT written as a separate transcript (we don't have
        // real word-level alignment between source and target).
        final transcripts = await db.transcriptDao.listForTarget('Audio', id);
        expect(transcripts, hasLength(1));
        expect(transcripts.first.language.startsWith('zh'), isTrue);

        // The audio row still carries the source text for reference.
        final audioRow = await db.audioDao.getById(id);
        expect(audioRow!.sourceText, 'Hello world this is a test.');
      },
    );

    test('dedupes on same content hash', () async {
      final audioBytes = Uint8List.fromList([1, 2, 3]);

      final id1 = await repo.importCraftedFromText(
        audioBytes: audioBytes,
        audioFormat: 'wav',
        learningLanguage: 'en',
        sourceLanguage: null,
        text: 'Same text for dedupe test.',
        normalizedText: 'Same text for dedupe test.',
        sourceFlag: 'craft-direct',
        signedInUserId: _testUserId,
      );

      final id2 = await repo.importCraftedFromText(
        audioBytes: audioBytes,
        audioFormat: 'wav',
        learningLanguage: 'en',
        sourceLanguage: null,
        text: 'Same text for dedupe test.',
        normalizedText: 'Same text for dedupe test.',
        sourceFlag: 'craft-direct',
        signedInUserId: _testUserId,
      );

      expect(id1, id2);
    });

    test('findExistingCrafted returns null for new content', () async {
      final existing = await repo.findExistingCrafted(
        learningLanguage: 'en',
        normalizedText: 'Brand new content never seen.',
        sourceFlag: 'craft-direct',
      );
      expect(existing, isNull);
    });

    test('findExistingCrafted returns id after import', () async {
      await repo.importCraftedFromText(
        audioBytes: Uint8List.fromList([1]),
        audioFormat: 'wav',
        learningLanguage: 'en',
        sourceLanguage: null,
        text: 'Existing crafted content.',
        normalizedText: 'Existing crafted content.',
        sourceFlag: 'craft-direct',
        signedInUserId: _testUserId,
      );

      final existing = await repo.findExistingCrafted(
        learningLanguage: 'en',
        normalizedText: 'Existing crafted content.',
        sourceFlag: 'craft-direct',
      );
      expect(existing, isNotNull);
    });

    test('audio file is written to storage', () async {
      final audioBytes = Uint8List.fromList([100, 101, 102, 103]);

      final id = await repo.importCraftedFromText(
        audioBytes: audioBytes,
        audioFormat: 'wav',
        learningLanguage: 'en',
        sourceLanguage: null,
        text: 'Check file write path.',
        normalizedText: 'Check file write path.',
        sourceFlag: 'craft-direct',
        signedInUserId: _testUserId,
      );

      final audioRow = await db.audioDao.getById(id);
      expect(audioRow, isNotNull);
      expect(audioRow!.localUri, isNotNull);
      expect(audioRow.localUri!.startsWith('file://'), isTrue);

      // File exists on disk.
      final fileUri = Uri.parse(audioRow.localUri!);
      final file = File.fromUri(fileUri);
      expect(await file.exists(), isTrue);
      expect(await file.length(), audioBytes.length);
    });

    test('title is truncated to ~40 chars', () async {
      final longText = 'A' * 100;
      await repo.importCraftedFromText(
        audioBytes: Uint8List.fromList([1]),
        audioFormat: 'wav',
        learningLanguage: 'en',
        sourceLanguage: null,
        text: longText,
        normalizedText: longText,
        sourceFlag: 'craft-direct',
        signedInUserId: _testUserId,
      );

      final rows = await db.audioDao.watchAll().first;
      expect(rows, hasLength(1));
      expect(rows.first.title.length, lessThanOrEqualTo(41)); // 40 + ellipsis
      expect(rows.first.title.endsWith('…'), isTrue);
    });

    test(
      'null primaryTimelineJson imports audio with blank transcript',
      () async {
        final id = await repo.importCraftedFromText(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
          learningLanguage: 'en',
          sourceLanguage: null,
          text: 'Blank timeline item.',
          normalizedText: 'Blank timeline item.',
          primaryTimelineJson: null,
          sourceFlag: 'craft-direct',
          signedInUserId: _testUserId,
        );
        final audioRow = await db.audioDao.getById(id);
        expect(audioRow, isNotNull);
        final transcripts = await db.transcriptDao.listForTarget('Audio', id);
        expect(transcripts, isEmpty);
      },
    );
  });

  group('CraftLibraryRepository.getCraftEditSource', () {
    late PathProviderPlatform original;
    late Directory root;
    late AppDatabase db;
    late CraftLibraryRepository repo;

    setUp(() {
      original = PathProviderPlatform.instance;
      root = Directory.systemTemp.createTempSync('enjoy_craft_edit_test');
      PathProviderPlatform.instance = TestPathProvider(root.path);
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = CraftLibraryRepository(db, FileStorage());
    });

    tearDown(() async {
      PathProviderPlatform.instance = original;
      await db.close();
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    test('returns null for a non-existent media id', () async {
      final source = await repo.getCraftEditSource('missing');
      expect(source, isNull);
    });

    test('returns null for a non-craft media row', () async {
      final now = DateTime.now();
      const id = 'a-user-1';
      await db.audioDao.insertRow(
        AudioRow(
          id: id,
          aid: 'aid-1',
          provider: 'user',
          title: 'User audio',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 0,
          language: 'en-US',
          translationKey: null,
          sourceText: null,
          voice: null,
          source: null,
          localUri: null,
          md5: null,
          size: null,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final source = await repo.getCraftEditSource(id);
      expect(source, isNull);
    });

    test('joins the primary transcript timeline into practiceText', () async {
      final id = await repo.importCraftedFromText(
        audioBytes: Uint8List.fromList([1, 2, 3]),
        audioFormat: 'wav',
        learningLanguage: 'en',
        sourceLanguage: null,
        text: 'Hello world this is a test.',
        normalizedText: 'Hello world this is a test.',
        primaryTimelineJson: jsonEncode([
          {'text': 'Hello world', 'start': 0, 'duration': 500},
          {'text': 'this is a test.', 'start': 500, 'duration': 500},
        ]),
        sourceFlag: 'craft-direct',
        signedInUserId: _testUserId,
      );

      final source = await repo.getCraftEditSource(id);
      expect(source, isNotNull);
      expect(source!.mediaId, id);
      expect(source.practiceText, 'Hello world this is a test.');
      expect(source.sourceText, 'Hello world this is a test.');
      expect(source.language.startsWith('en'), isTrue);
      expect(source.sourceFlag, 'craft-direct');
    });

    test(
      'blank Express save keeps practice text from description, not native sourceText',
      () async {
        final id = await repo.importCraftedFromText(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
          learningLanguage: 'es',
          sourceLanguage: null,
          text: 'I had a great day today.',
          normalizedText: 'Hoy tuve un gran día.',
          primaryTimelineJson: null,
          sourceFlag: 'craft-express',
          signedInUserId: _testUserId,
        );

        final transcripts = await db.transcriptDao.listForTarget('Audio', id);
        expect(transcripts, isEmpty);

        final source = await repo.getCraftEditSource(id);
        expect(source, isNotNull);
        expect(source!.practiceText, 'Hoy tuve un gran día.');
        expect(source.sourceText, 'I had a great day today.');
        expect(source.sourceFlag, 'craft-express');
      },
    );
  });

  group('CraftLibraryRepository.updateCraftedFromText', () {
    late PathProviderPlatform original;
    late Directory root;
    late AppDatabase db;
    late CraftLibraryRepository repo;

    setUp(() {
      original = PathProviderPlatform.instance;
      root = Directory.systemTemp.createTempSync('enjoy_craft_update_test');
      PathProviderPlatform.instance = TestPathProvider(root.path);
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = CraftLibraryRepository(db, FileStorage());
    });

    tearDown(() async {
      PathProviderPlatform.instance = original;
      await db.close();
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    test('throws StateError for a non-existent media id', () async {
      await expectLater(
        () => repo.updateCraftedFromText(
          mediaId: 'missing',
          audioBytes: Uint8List.fromList([1]),
          audioFormat: 'wav',
          learningLanguage: 'en',
          text: 'New text.',
          normalizedText: 'New text.',
          sourceFlag: 'craft-direct',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('keeps the same media id and replaces audio + transcript', () async {
      final id = await repo.importCraftedFromText(
        audioBytes: Uint8List.fromList([1, 2, 3]),
        audioFormat: 'wav',
        learningLanguage: 'en',
        sourceLanguage: null,
        text: 'Original text for editing.',
        normalizedText: 'Original text for editing.',
        primaryTimelineJson: _solidTimeline('Original text for editing.'),
        sourceFlag: 'craft-direct',
        signedInUserId: _testUserId,
      );
      final original = await db.audioDao.getById(id);

      final updatedId = await repo.updateCraftedFromText(
        mediaId: id,
        audioBytes: Uint8List.fromList([9, 9, 9, 9]),
        audioFormat: 'wav',
        learningLanguage: 'en',
        text: 'Updated text after editing.',
        normalizedText: 'Updated text after editing.',
        primaryTimelineJson: _solidTimeline('Updated text after editing.'),
        sourceFlag: 'craft-direct',
      );

      expect(updatedId, id);

      final updated = await db.audioDao.getById(id);
      expect(updated, isNotNull);
      expect(updated!.id, original!.id);
      expect(updated.aid, original.aid);
      expect(updated.createdAt, original.createdAt);
      expect(updated.provider, 'craft');
      expect(updated.sourceText, 'Updated text after editing.');
      expect(updated.md5, isNot(original.md5));

      final transcripts = await db.transcriptDao.listForTarget('Audio', id);
      expect(transcripts, hasLength(1));

      final source = await repo.getCraftEditSource(id);
      expect(source!.practiceText, 'Updated text after editing.');
    });

    test('removes the old audio file when the URI changes', () async {
      final id = await repo.importCraftedFromText(
        audioBytes: Uint8List.fromList([1, 2, 3]),
        audioFormat: 'wav',
        learningLanguage: 'en',
        sourceLanguage: null,
        text: 'Original text.',
        normalizedText: 'Original text.',
        sourceFlag: 'craft-direct',
        signedInUserId: _testUserId,
      );
      final original = await db.audioDao.getById(id);
      final originalFile = File.fromUri(Uri.parse(original!.localUri!));
      expect(await originalFile.exists(), isTrue);

      await repo.updateCraftedFromText(
        mediaId: id,
        audioBytes: Uint8List.fromList([4, 4, 4]),
        audioFormat: 'wav',
        learningLanguage: 'en',
        text: 'Replacement text.',
        normalizedText: 'Replacement text.',
        sourceFlag: 'craft-direct',
      );

      expect(await originalFile.exists(), isFalse);

      final updated = await db.audioDao.getById(id);
      final updatedFile = File.fromUri(Uri.parse(updated!.localUri!));
      expect(await updatedFile.exists(), isTrue);
      expect(await updatedFile.length(), 3);
    });

    test('blank update deletes prior transcript rows', () async {
      final id = await repo.importCraftedFromText(
        audioBytes: Uint8List.fromList([1, 2, 3]),
        audioFormat: 'wav',
        learningLanguage: 'en',
        sourceLanguage: null,
        text: 'Has cues first.',
        normalizedText: 'Has cues first.',
        primaryTimelineJson: _solidTimeline('Has cues first.'),
        sourceFlag: 'craft-direct',
        signedInUserId: _testUserId,
      );
      expect(await db.transcriptDao.listForTarget('Audio', id), hasLength(1));

      await repo.updateCraftedFromText(
        mediaId: id,
        audioBytes: Uint8List.fromList([4, 5, 6]),
        audioFormat: 'wav',
        learningLanguage: 'en',
        text: 'Now blank cues.',
        normalizedText: 'Now blank cues.',
        primaryTimelineJson: null,
        sourceFlag: 'craft-direct',
      );
      expect(await db.transcriptDao.listForTarget('Audio', id), isEmpty);
    });
  });

  group('CraftLibraryRepository.removeCraftHistoryRecord', () {
    late PathProviderPlatform original;
    late Directory root;
    late AppDatabase db;
    late CraftLibraryRepository repo;

    setUp(() {
      original = PathProviderPlatform.instance;
      root = Directory.systemTemp.createTempSync('enjoy_craft_remove_test');
      PathProviderPlatform.instance = TestPathProvider(root.path);
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = CraftLibraryRepository(db, FileStorage());
    });

    tearDown(() async {
      PathProviderPlatform.instance = original;
      await db.close();
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    test('clears craft provider but keeps audio file and media id', () async {
      final audioBytes = Uint8List.fromList([9, 8, 7]);
      final id = await repo.importCraftedFromText(
        audioBytes: audioBytes,
        audioFormat: 'wav',
        learningLanguage: 'en',
        sourceLanguage: null,
        text: 'Keep this audio for practice.',
        normalizedText: 'Keep this audio for practice.',
        primaryTimelineJson: _solidTimeline('Keep this audio for practice.'),
        sourceFlag: 'craft-direct',
        signedInUserId: _testUserId,
      );

      final before = await db.audioDao.getById(id);
      expect(before!.provider, 'craft');
      final file = File.fromUri(Uri.parse(before.localUri!));
      expect(await file.exists(), isTrue);

      await repo.removeCraftHistoryRecord(id);

      final after = await db.audioDao.getById(id);
      expect(after, isNotNull);
      expect(after!.id, id);
      expect(after.provider, 'user');
      expect(after.localUri, before.localUri);
      expect(await file.exists(), isTrue);
      expect(await file.length(), audioBytes.length);

      final transcripts = await db.transcriptDao.listForTarget('Audio', id);
      expect(transcripts, isNotEmpty);
    });

    test('throws when media is not a craft record', () async {
      await expectLater(
        repo.removeCraftHistoryRecord('missing'),
        throwsStateError,
      );
    });
  });

  group('CraftLibraryRepository additional coverage', () {
    late PathProviderPlatform original;
    late Directory root;
    late AppDatabase db;
    late CraftLibraryRepository repo;

    setUp(() {
      original = PathProviderPlatform.instance;
      root = Directory.systemTemp.createTempSync('enjoy_craft_repo_extra');
      PathProviderPlatform.instance = TestPathProvider(root.path);
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = CraftLibraryRepository(db, FileStorage());
    });

    tearDown(() async {
      PathProviderPlatform.instance = original;
      await db.close();
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    group('CraftLibraryRepository.importCraftedFromText (additional)', () {
      test('uses provided primaryTimelineJson', () async {
        final timeline = jsonEncode([
          {'text': 'Hello', 'start': 0, 'duration': 500},
          {'text': 'world', 'start': 500, 'duration': 400},
        ]);

        final id = await repo.importCraftedFromText(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
          learningLanguage: 'en',
          text: 'Hello world',
          normalizedText: 'Hello world',
          primaryTimelineJson: timeline,
          sourceFlag: 'craft-direct',
          signedInUserId: _testUserId,
        );

        final transcripts = await db.transcriptDao.listForTarget('Audio', id);
        expect(transcripts, hasLength(1));
        expect(transcripts.first.timelineJson, timeline);
      });

      test('omits transcript when primaryTimelineJson is null', () async {
        final id = await repo.importCraftedFromText(
          audioBytes: Uint8List.fromList([4, 5, 6]),
          audioFormat: 'wav',
          learningLanguage: 'en',
          text: 'Blank timeline',
          normalizedText: 'Blank timeline',
          primaryTimelineJson: null,
          sourceFlag: 'craft-direct',
          signedInUserId: _testUserId,
        );

        final transcripts = await db.transcriptDao.listForTarget('Audio', id);
        expect(transcripts, isEmpty);
        final audio = await db.audioDao.getById(id);
        expect(audio, isNotNull);
      });

      test('voice participates in dedupe key', () async {
        final audioBytes = Uint8List.fromList([7, 8, 9]);

        final id1 = await repo.importCraftedFromText(
          audioBytes: audioBytes,
          audioFormat: 'wav',
          learningLanguage: 'en',
          text: 'Voice test',
          normalizedText: 'Voice test',
          voice: 'alloy',
          sourceFlag: 'craft-direct',
          signedInUserId: _testUserId,
        );

        final id2 = await repo.importCraftedFromText(
          audioBytes: audioBytes,
          audioFormat: 'wav',
          learningLanguage: 'en',
          text: 'Voice test',
          normalizedText: 'Voice test',
          voice: 'nova',
          sourceFlag: 'craft-direct',
          signedInUserId: _testUserId,
        );

        expect(id1, isNot(id2));
      });

      test('same voice dedupes correctly', () async {
        final audioBytes = Uint8List.fromList([10, 11]);

        final id1 = await repo.importCraftedFromText(
          audioBytes: audioBytes,
          audioFormat: 'wav',
          learningLanguage: 'en',
          text: 'Same voice',
          normalizedText: 'Same voice',
          voice: 'alloy',
          sourceFlag: 'craft-direct',
          signedInUserId: _testUserId,
        );

        final id2 = await repo.importCraftedFromText(
          audioBytes: audioBytes,
          audioFormat: 'wav',
          learningLanguage: 'en',
          text: 'Same voice',
          normalizedText: 'Same voice',
          voice: 'alloy',
          sourceFlag: 'craft-direct',
          signedInUserId: _testUserId,
        );

        expect(id1, id2);
      });

      test('enqueues sync create', () async {
        final syncLog = <(SyncEntityType, String, SyncAction)>[];
        final syncRepo = CraftLibraryRepository(
          db,
          FileStorage(),
          enqueueSync: (type, id, action) async {
            syncLog.add((type, id, action));
          },
        );

        final id = await syncRepo.importCraftedFromText(
          audioBytes: Uint8List.fromList([20]),
          audioFormat: 'wav',
          learningLanguage: 'en',
          text: 'Sync craft',
          normalizedText: 'Sync craft',
          sourceFlag: 'craft-direct',
          signedInUserId: _testUserId,
        );

        expect(
          syncLog,
          contains((SyncEntityType.audio, id, SyncAction.create)),
        );
      });

      test('title is not truncated when text is short', () async {
        final shortText = 'Short';
        final id = await repo.importCraftedFromText(
          audioBytes: Uint8List.fromList([30]),
          audioFormat: 'wav',
          learningLanguage: 'en',
          text: shortText,
          normalizedText: shortText,
          sourceFlag: 'craft-direct',
          signedInUserId: _testUserId,
        );

        final row = await db.audioDao.getById(id);
        expect(row!.title, shortText);
      });
    });

    group('CraftLibraryRepository.findExistingCrafted', () {
      test('voice differentiates lookup', () async {
        await repo.importCraftedFromText(
          audioBytes: Uint8List.fromList([40]),
          audioFormat: 'wav',
          learningLanguage: 'en',
          text: 'Voice find',
          normalizedText: 'Voice find',
          voice: 'alloy',
          sourceFlag: 'craft-direct',
          signedInUserId: _testUserId,
        );

        final withSameVoice = await repo.findExistingCrafted(
          learningLanguage: 'en',
          normalizedText: 'Voice find',
          sourceFlag: 'craft-direct',
          voice: 'alloy',
        );
        expect(withSameVoice, isNotNull);

        final withDifferentVoice = await repo.findExistingCrafted(
          learningLanguage: 'en',
          normalizedText: 'Voice find',
          sourceFlag: 'craft-direct',
          voice: 'nova',
        );
        expect(withDifferentVoice, isNull);
      });

      test('sourceFlag differentiates lookup', () async {
        await repo.importCraftedFromText(
          audioBytes: Uint8List.fromList([50]),
          audioFormat: 'wav',
          learningLanguage: 'en',
          text: 'Flag test',
          normalizedText: 'Flag test',
          sourceFlag: 'craft-direct',
          signedInUserId: _testUserId,
        );

        final sameFlag = await repo.findExistingCrafted(
          learningLanguage: 'en',
          normalizedText: 'Flag test',
          sourceFlag: 'craft-direct',
        );
        expect(sameFlag, isNotNull);

        final differentFlag = await repo.findExistingCrafted(
          learningLanguage: 'en',
          normalizedText: 'Flag test',
          sourceFlag: 'craft-translate',
        );
        expect(differentFlag, isNull);
      });
    });
  });
}
