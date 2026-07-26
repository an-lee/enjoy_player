import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/files/file_storage.dart';
import 'package:enjoy_player/features/library/data/library_repository.dart';
import 'package:enjoy_player/features/share_poster/application/practice_poster_builder.dart';
import 'package:enjoy_player/features/transcript/data/transcript_repository.dart';
import 'package:flutter_test/flutter_test.dart';

VideoRow _video({
  required String id,
  String title = 'T',
  String language = 'en',
  String? localUri,
  String? thumbnailUrl,
  int durationSeconds = 60,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return VideoRow(
    id: id,
    vid: 'v_$id',
    provider: 'user',
    title: title,
    description: null,
    thumbnailUrl: thumbnailUrl,
    durationSeconds: durationSeconds,
    language: language,
    source: null,
    localUri: localUri,
    md5: null,
    size: localUri != null ? 1024 : null,
    mediaUrl: 'https://example.com/$id.mp4',
    syncStatus: null,
    serverUpdatedAt: null,
    createdAt: now,
    updatedAt: now,
  );
}

RecordingRow _recording({
  required String id,
  required String targetId,
  int durationMs = 1000,
  int start = 0,
  String referenceText = 'ref',
}) {
  final now = DateTime.utc(2026, 1, 1);
  return RecordingRow(
    id: id,
    targetType: 'Video',
    targetId: targetId,
    referenceStart: start,
    referenceDuration: durationMs,
    referenceText: referenceText,
    language: 'en',
    duration: durationMs,
    md5: null,
    audioUrl: null,
    pronunciationScore: null,
    assessmentJson: null,
    localPath: null,
    syncStatus: null,
    serverUpdatedAt: null,
    createdAt: now,
    updatedAt: now,
  );
}

TranscriptRow _transcriptRow({
  required String id,
  required String targetId,
  required List<Map<String, dynamic>> timeline,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return TranscriptRow(
    id: id,
    targetType: 'Video',
    targetId: targetId,
    language: 'en',
    source: 'user',
    label: '',
    trackIndex: 0,
    timelineJson: jsonEncode(timeline),
    syncStatus: null,
    serverUpdatedAt: null,
    createdAt: now,
    updatedAt: now,
  );
}

EchoSessionRow _echoSession({
  required String id,
  required String targetId,
  String? transcriptId,
  int startLine = -1,
  int endLine = -1,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return EchoSessionRow(
    id: id,
    targetType: 'Video',
    targetId: targetId,
    language: 'en',
    currentTimeMs: 0,
    playbackRate: 1.0,
    volume: 1.0,
    echoStartMs: null,
    echoEndMs: null,
    transcriptId: transcriptId,
    secondaryTranscriptId: null,
    recordingsCount: 0,
    recordingsDurationMs: 0,
    lastRecordingAt: null,
    currentSegmentIndex: -1,
    echoActive: false,
    echoStartLine: startLine,
    echoEndLine: endLine,
    blurActive: false,
    startedAt: now,
    lastActiveAt: now,
    completedAt: null,
    syncStatus: null,
    serverUpdatedAt: null,
    createdAt: now,
    updatedAt: now,
  );
}

List<Map<String, dynamic>> _timeline(int count) {
  return List.generate(
    count,
    (i) => {'t': i * 1000, 'd': 900, 'text': 'Line $i.'},
    growable: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MediaLibraryRepository repo;
  late TranscriptRepository transcriptRepo;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = MediaLibraryRepository(db, FileStorage());
    transcriptRepo = TranscriptRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('listRecordingsForTarget', () {
    test('returns recordings ordered by createdAt desc', () async {
      await db.videoDao.insertRow(_video(id: 'v1'));
      final old = DateTime.utc(2025, 1, 1);
      final mid = DateTime.utc(2025, 6, 1);
      final recent = DateTime.utc(2026, 1, 1);
      for (final t in [old, mid, recent]) {
        await db.recordingDao.insertRow(
          RecordingRow(
            id: 'r-${t.millisecondsSinceEpoch}',
            targetType: 'Video',
            targetId: 'v1',
            referenceStart: 0,
            referenceDuration: 100,
            referenceText: 'r',
            language: 'en',
            duration: 100,
            md5: null,
            audioUrl: null,
            pronunciationScore: null,
            assessmentJson: null,
            localPath: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: t,
            updatedAt: t,
          ),
        );
      }
      final rows = await listRecordingsForTarget(
        db,
        targetType: 'Video',
        targetId: 'v1',
      );
      expect(rows.map((r) => r.id), [
        'r-${recent.millisecondsSinceEpoch}',
        'r-${mid.millisecondsSinceEpoch}',
        'r-${old.millisecondsSinceEpoch}',
      ]);
    });

    test('returns empty when no recordings', () async {
      await db.videoDao.insertRow(_video(id: 'v1'));
      final rows = await listRecordingsForTarget(
        db,
        targetType: 'Video',
        targetId: 'v1',
      );
      expect(rows, isEmpty);
    });
  });

  group('primaryTranscriptLinesForMedia', () {
    test('returns empty when no echo session exists', () async {
      await db.videoDao.insertRow(_video(id: 'v1'));
      final lines = await primaryTranscriptLinesForMedia(
        db: db,
        transcriptRepo: transcriptRepo,
        targetType: 'Video',
        mediaId: 'v1',
      );
      expect(lines, isEmpty);
    });

    test('returns empty when echo has no transcriptId', () async {
      await db.videoDao.insertRow(_video(id: 'v1'));
      await db.echoSessionDao.upsert(_echoSession(id: 'es-1', targetId: 'v1'));
      final lines = await primaryTranscriptLinesForMedia(
        db: db,
        transcriptRepo: transcriptRepo,
        targetType: 'Video',
        mediaId: 'v1',
      );
      expect(lines, isEmpty);
    });

    test(
      'returns empty when echo transcriptId does not match any row',
      () async {
        await db.videoDao.insertRow(_video(id: 'v1'));
        await db.echoSessionDao.upsert(
          _echoSession(
            id: 'es-1',
            targetId: 'v1',
            transcriptId: 'missing-transcript',
          ),
        );
        final lines = await primaryTranscriptLinesForMedia(
          db: db,
          transcriptRepo: transcriptRepo,
          targetType: 'Video',
          mediaId: 'v1',
        );
        expect(lines, isEmpty);
      },
    );

    test('returns decoded lines for the active transcriptId', () async {
      await db.videoDao.insertRow(_video(id: 'v1'));
      await db.transcriptDao.upsert(
        _transcriptRow(id: 't-1', targetId: 'v1', timeline: _timeline(3)),
      );
      await db.echoSessionDao.upsert(
        _echoSession(id: 'es-1', targetId: 'v1', transcriptId: 't-1'),
      );
      final lines = await primaryTranscriptLinesForMedia(
        db: db,
        transcriptRepo: transcriptRepo,
        targetType: 'Video',
        mediaId: 'v1',
      );
      expect(lines, hasLength(3));
      expect(lines.first.text, 'Line 0.');
    });
  });

  group('buildPracticePosterData', () {
    test('returns null when mediaId is unknown', () async {
      final data = await buildPracticePosterData(
        db: db,
        library: repo,
        transcriptRepo: transcriptRepo,
        mediaId: 'missing',
      );
      expect(data, isNull);
    });

    test('returns null when media has no recordings', () async {
      await db.videoDao.insertRow(_video(id: 'v1'));
      final data = await buildPracticePosterData(
        db: db,
        library: repo,
        transcriptRepo: transcriptRepo,
        mediaId: 'v1',
      );
      expect(data, isNull);
    });

    test('returns poster data for video with recordings and no echo', () async {
      await db.videoDao.insertRow(_video(id: 'v1'));
      await db.recordingDao.insertRow(
        _recording(id: 'r-1', targetId: 'v1', durationMs: 1500),
      );
      await db.transcriptDao.upsert(
        _transcriptRow(id: 't-1', targetId: 'v1', timeline: _timeline(2)),
      );
      await db.echoSessionDao.upsert(
        _echoSession(id: 'es-1', targetId: 'v1', transcriptId: 't-1'),
      );

      final data = await buildPracticePosterData(
        db: db,
        library: repo,
        transcriptRepo: transcriptRepo,
        mediaId: 'v1',
      );
      expect(data, isNotNull);
      expect(data!.title, 'T');
      expect(data.isVideo, isTrue);
      expect(data.takes, 1);
      expect(data.spokenDurationMs, 1500);
    });

    test('echoCoverBytes passthrough preserves bytes', () async {
      await db.videoDao.insertRow(_video(id: 'v1'));
      await db.recordingDao.insertRow(_recording(id: 'r-1', targetId: 'v1'));

      final data = await buildPracticePosterData(
        db: db,
        library: repo,
        transcriptRepo: transcriptRepo,
        mediaId: 'v1',
        echoCoverBytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(data, isNotNull);
      expect(data!.echoCoverBytes, isNotNull);
      expect(data.echoCoverBytes!.length, 3);
      expect(data.echoCoverBytes, [1, 2, 3]);
    });

    test('audio media yields isVideo false', () async {
      final now = DateTime.utc(2026, 1, 1);
      await db.audioDao.insertRow(
        AudioRow(
          id: 'a1',
          aid: 'a',
          provider: 'user',
          title: 'Audio title',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 30,
          language: 'en',
          translationKey: null,
          sourceText: null,
          voice: null,
          source: null,
          localUri: 'file:///tmp/a.mp3',
          md5: null,
          size: 1,
          localMtimeMs: null,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.recordingDao.insertRow(
        RecordingRow(
          id: 'r-1',
          targetType: 'Audio',
          targetId: 'a1',
          referenceStart: 0,
          referenceDuration: 1000,
          referenceText: 'ref',
          language: 'en',
          duration: 1000,
          md5: null,
          audioUrl: null,
          pronunciationScore: null,
          assessmentJson: null,
          localPath: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final data = await buildPracticePosterData(
        db: db,
        library: repo,
        transcriptRepo: transcriptRepo,
        mediaId: 'a1',
      );
      expect(data, isNotNull);
      expect(data!.isVideo, isFalse);
      expect(data.title, 'Audio title');
    });
  });

  group('mediaHasPracticeRecordings', () {
    test('returns false when mediaId missing', () async {
      final has = await mediaHasPracticeRecordings(db: db, mediaId: 'nope');
      expect(has, isFalse);
    });

    test('returns false when video has no recordings', () async {
      await db.videoDao.insertRow(_video(id: 'v1'));
      final has = await mediaHasPracticeRecordings(db: db, mediaId: 'v1');
      expect(has, isFalse);
    });

    test('returns true when video has recordings', () async {
      await db.videoDao.insertRow(_video(id: 'v1'));
      await db.recordingDao.insertRow(_recording(id: 'r-1', targetId: 'v1'));
      final has = await mediaHasPracticeRecordings(db: db, mediaId: 'v1');
      expect(has, isTrue);
    });

    test('returns true when audio has recordings', () async {
      final now = DateTime.utc(2026, 1, 1);
      await db.audioDao.insertRow(
        AudioRow(
          id: 'a1',
          aid: 'a',
          provider: 'user',
          title: 'A',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 0,
          language: 'en',
          translationKey: null,
          sourceText: null,
          voice: null,
          source: null,
          localUri: null,
          md5: null,
          size: null,
          localMtimeMs: null,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.recordingDao.insertRow(
        RecordingRow(
          id: 'r-1',
          targetType: 'Audio',
          targetId: 'a1',
          referenceStart: 0,
          referenceDuration: 1000,
          referenceText: 'ref',
          language: 'en',
          duration: 1000,
          md5: null,
          audioUrl: null,
          pronunciationScore: null,
          assessmentJson: null,
          localPath: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final has = await mediaHasPracticeRecordings(db: db, mediaId: 'a1');
      expect(has, isTrue);
    });
  });
}
