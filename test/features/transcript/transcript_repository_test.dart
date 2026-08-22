import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/data/transcript_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('TranscriptRepository', () {
    late AppDatabase db;
    late TranscriptRepository repo;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    TranscriptRow makeRow({
      required String id,
      required DateTime updatedAt,
      String timelineJson = '[{"text":"a","start":0,"duration":1000}]',
    }) {
      final now = DateTime.now();
      return TranscriptRow(
        id: id,
        targetType: 'Audio',
        targetId: 'm1',
        language: 'und',
        source: 'user',
        timelineJson: timelineJson,
        referenceId: null,
        label: 'L',
        trackIndex: null,
        syncStatus: null,
        serverUpdatedAt: null,
        createdAt: now,
        updatedAt: updatedAt,
      );
    }

    test('linesForRow memoizes until updatedAt changes', () {
      final t = DateTime.utc(2025, 1, 1);
      final r1 = makeRow(id: 't1', updatedAt: t);
      final a = repo.linesForRow(r1);
      final b = repo.linesForRow(r1);
      expect(identical(a, b), isTrue);

      final r2 = makeRow(
        id: 't1',
        updatedAt: t.add(const Duration(seconds: 1)),
        timelineJson: '[{"text":"b","start":0,"duration":500}]',
      );
      final c = repo.linesForRow(r2);
      expect(identical(a, c), isFalse);
      expect(c.first.text, 'b');
    });

    test(
      'setActiveTranscript and setSecondaryTranscript update session',
      () async {
        final now = DateTime.now();
        await db.audioDao.insertRow(
          AudioRow(
            id: 'm1',
            aid: 'f',
            provider: 'user',
            title: 't',
            description: null,
            thumbnailUrl: null,
            durationSeconds: 0,
            language: 'und',
            translationKey: null,
            sourceText: null,
            voice: null,
            source: null,
            localUri: 'file:///a.mp3',
            md5: null,
            size: 1,
            mediaUrl: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final tid = 'tr-1';
        final timelineJson = jsonEncode([
          const TranscriptLine(text: 'x', startMs: 0, durationMs: 100).toJson(),
        ]);

        await db.transcriptDao.upsert(
          TranscriptRow(
            id: tid,
            targetType: 'Audio',
            targetId: 'm1',
            language: 'en',
            source: 'user',
            timelineJson: timelineJson,
            referenceId: null,
            label: 'en',
            trackIndex: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repo.setActiveTranscript('m1', tid);
        await repo.setSecondaryTranscript('m1', tid);

        final s = await db.echoSessionDao.getLatestForTarget('Audio', 'm1');
        expect(s?.transcriptId, tid);
        expect(s?.secondaryTranscriptId, tid);
      },
    );

    test(
      'deleteTranscript clears secondary when session referenced deleted id',
      () async {
        final now = DateTime.now();
        await db.audioDao.insertRow(
          AudioRow(
            id: 'm1',
            aid: 'f',
            provider: 'user',
            title: 't',
            description: null,
            thumbnailUrl: null,
            durationSeconds: 0,
            language: 'und',
            translationKey: null,
            sourceText: null,
            voice: null,
            source: null,
            localUri: 'file:///a.mp3',
            md5: null,
            size: 1,
            mediaUrl: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final primaryJson = jsonEncode([
          const TranscriptLine(text: 'a', startMs: 0, durationMs: 100).toJson(),
        ]);
        final secondaryJson = jsonEncode([
          const TranscriptLine(text: 'b', startMs: 0, durationMs: 100).toJson(),
        ]);

        await db.transcriptDao.upsert(
          TranscriptRow(
            id: 'tr-primary',
            targetType: 'Audio',
            targetId: 'm1',
            language: 'en',
            source: 'user',
            timelineJson: primaryJson,
            referenceId: null,
            label: 'Primary',
            trackIndex: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await db.transcriptDao.upsert(
          TranscriptRow(
            id: 'tr-secondary',
            targetType: 'Audio',
            targetId: 'm1',
            language: 'es',
            source: 'user',
            timelineJson: secondaryJson,
            referenceId: null,
            label: 'Secondary',
            trackIndex: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now.add(const Duration(seconds: 1)),
            updatedAt: now.add(const Duration(seconds: 1)),
          ),
        );

        await repo.setActiveTranscript('m1', 'tr-primary');
        await repo.setSecondaryTranscript('m1', 'tr-secondary');

        await repo.deleteTranscript('tr-secondary');

        final row = await db.transcriptDao.getById('tr-secondary');
        expect(row, isNull);

        final s = await db.echoSessionDao.getLatestForTarget('Audio', 'm1');
        expect(s?.transcriptId, 'tr-primary');
        expect(s?.secondaryTranscriptId, isNull);
      },
    );

    test(
      'deleteTranscript reassigns primary to next track when primary deleted',
      () async {
        final now = DateTime.now();
        await db.audioDao.insertRow(
          AudioRow(
            id: 'm1',
            aid: 'f',
            provider: 'user',
            title: 't',
            description: null,
            thumbnailUrl: null,
            durationSeconds: 0,
            language: 'und',
            translationKey: null,
            sourceText: null,
            voice: null,
            source: null,
            localUri: 'file:///a.mp3',
            md5: null,
            size: 1,
            mediaUrl: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final jsonA = jsonEncode([
          const TranscriptLine(text: 'a', startMs: 0, durationMs: 100).toJson(),
        ]);
        final jsonB = jsonEncode([
          const TranscriptLine(text: 'b', startMs: 0, durationMs: 100).toJson(),
        ]);

        await db.transcriptDao.upsert(
          TranscriptRow(
            id: 'tr-embedded',
            targetType: 'Audio',
            targetId: 'm1',
            language: 'en',
            source: 'official',
            timelineJson: jsonA,
            referenceId: null,
            label: 'Embedded',
            trackIndex: 0,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await db.transcriptDao.upsert(
          TranscriptRow(
            id: 'tr-imported',
            targetType: 'Audio',
            targetId: 'm1',
            language: 'und',
            source: 'user',
            timelineJson: jsonB,
            referenceId: null,
            label: 'Imported',
            trackIndex: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now.add(const Duration(seconds: 1)),
            updatedAt: now.add(const Duration(seconds: 1)),
          ),
        );

        await repo.setActiveTranscript('m1', 'tr-imported');
        await repo.setSecondaryTranscript('m1', null);

        await repo.deleteTranscript('tr-imported');

        final s = await db.echoSessionDao.getLatestForTarget('Audio', 'm1');
        expect(s?.transcriptId, 'tr-embedded');
        expect(s?.secondaryTranscriptId, isNull);
      },
    );

    test(
      'deleteTranscript clears secondary when new primary collides with it',
      () async {
        final now = DateTime.now();
        await db.audioDao.insertRow(
          AudioRow(
            id: 'm1',
            aid: 'f',
            provider: 'user',
            title: 't',
            description: null,
            thumbnailUrl: null,
            durationSeconds: 0,
            language: 'und',
            translationKey: null,
            sourceText: null,
            voice: null,
            source: null,
            localUri: 'file:///a.mp3',
            md5: null,
            size: 1,
            mediaUrl: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final jsonA = jsonEncode([
          const TranscriptLine(text: 'a', startMs: 0, durationMs: 100).toJson(),
        ]);
        final jsonB = jsonEncode([
          const TranscriptLine(text: 'b', startMs: 0, durationMs: 100).toJson(),
        ]);

        await db.transcriptDao.upsert(
          TranscriptRow(
            id: 'tr-embedded',
            targetType: 'Audio',
            targetId: 'm1',
            language: 'en',
            source: 'official',
            timelineJson: jsonA,
            referenceId: null,
            label: 'Embedded',
            trackIndex: 0,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await db.transcriptDao.upsert(
          TranscriptRow(
            id: 'tr-imported',
            targetType: 'Audio',
            targetId: 'm1',
            language: 'und',
            source: 'user',
            timelineJson: jsonB,
            referenceId: null,
            label: 'Imported',
            trackIndex: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now.add(const Duration(seconds: 1)),
            updatedAt: now.add(const Duration(seconds: 1)),
          ),
        );

        await repo.setActiveTranscript('m1', 'tr-imported');
        await repo.setSecondaryTranscript('m1', 'tr-embedded');

        await repo.deleteTranscript('tr-imported');

        final s = await db.echoSessionDao.getLatestForTarget('Audio', 'm1');
        expect(s?.transcriptId, 'tr-embedded');
        expect(s?.secondaryTranscriptId, isNull);
      },
    );
  });

  group('resolveOnOpen orchestration', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('resolveOnOpen assigns highest-priority track as primary', () async {
      final now = DateTime.now();
      await db.audioDao.insertRow(
        AudioRow(
          id: 'm1',
          aid: 'f',
          provider: 'user',
          title: 't',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 0,
          language: 'und',
          translationKey: null,
          sourceText: null,
          voice: null,
          source: null,
          localUri: 'file:///a.mp3',
          md5: null,
          size: 1,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final timelineJson = jsonEncode([
        const TranscriptLine(text: 'x', startMs: 0, durationMs: 100).toJson(),
      ]);

      await db.transcriptDao.upsert(
        TranscriptRow(
          id: 'tr-user',
          targetType: 'Audio',
          targetId: 'm1',
          language: 'en',
          source: 'user',
          timelineJson: timelineJson,
          referenceId: null,
          label: 'user',
          trackIndex: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.transcriptDao.upsert(
        TranscriptRow(
          id: 'tr-official',
          targetType: 'Audio',
          targetId: 'm1',
          language: 'en',
          source: 'official',
          timelineJson: timelineJson,
          referenceId: null,
          label: 'official',
          trackIndex: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now.add(const Duration(seconds: 1)),
          updatedAt: now.add(const Duration(seconds: 1)),
        ),
      );

      final repo = TranscriptRepository(db);
      final result = await repo.resolveOnOpen('m1', fetchCloud: false);
      expect(result.hasTracks, isTrue);

      final session = await db.echoSessionDao.getLatestForTarget('Audio', 'm1');
      expect(session?.transcriptId, 'tr-official');
    });

    test('resolveOnOpen reassigns stale session transcript id', () async {
      final now = DateTime.now();
      await db.audioDao.insertRow(
        AudioRow(
          id: 'm1',
          aid: 'f',
          provider: 'user',
          title: 't',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 0,
          language: 'und',
          translationKey: null,
          sourceText: null,
          voice: null,
          source: null,
          localUri: 'file:///a.mp3',
          md5: null,
          size: 1,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final timelineJson = jsonEncode([
        const TranscriptLine(text: 'x', startMs: 0, durationMs: 100).toJson(),
      ]);

      await db.transcriptDao.upsert(
        TranscriptRow(
          id: 'tr-official',
          targetType: 'Audio',
          targetId: 'm1',
          language: 'en',
          source: 'official',
          timelineJson: timelineJson,
          referenceId: null,
          label: 'official',
          trackIndex: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.echoSessionDao.updatePrimaryTranscriptForTarget(
        'Audio',
        'm1',
        'tr-missing',
      );

      final repo = TranscriptRepository(db);
      final result = await repo.resolveOnOpen('m1', fetchCloud: false);
      expect(result.hasTracks, isTrue);

      final session = await db.echoSessionDao.getLatestForTarget('Audio', 'm1');
      expect(session?.transcriptId, 'tr-official');
    });

    test('resolveOnOpen imports adjacent srt for local media', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'enjoy_repo_sidecar_',
      );
      try {
        final mediaFile = File(p.join(tempDir.path, 'clip.mp3'));
        await mediaFile.writeAsString('audio');
        await File(
          p.join(tempDir.path, 'clip.en.srt'),
        ).writeAsString('1\n00:00:00,000 --> 00:00:01,000\nHello');

        final now = DateTime.now();
        final mediaStat = await mediaFile.stat();
        await db.audioDao.insertRow(
          AudioRow(
            id: 'm-sidecar',
            aid: 'f',
            provider: 'user',
            title: 't',
            description: null,
            thumbnailUrl: null,
            durationSeconds: 0,
            language: 'und',
            translationKey: null,
            sourceText: null,
            voice: null,
            source: null,
            localUri: mediaFile.uri.toString(),
            md5: null,
            size: mediaStat.size,
            localMtimeMs: mediaStat.modified.millisecondsSinceEpoch,
            mediaUrl: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final repo = TranscriptRepository(db);
        final result = await repo.resolveOnOpen('m-sidecar', fetchCloud: false);
        expect(result.hasTracks, isTrue);

        final rows = await db.transcriptDao.listForTarget('Audio', 'm-sidecar');
        expect(rows, hasLength(1));
        expect(rows.single.language, 'en');
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
