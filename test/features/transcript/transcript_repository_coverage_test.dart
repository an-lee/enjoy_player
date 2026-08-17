/// Additional coverage tests for [TranscriptRepository].
///
/// Targets uncovered branches: resolveOnOpen orchestration, fetchCloudTranscripts
/// with a real (fake-HTTP) TranscriptApi, primaryTranscriptRowForMedia, watchTracks,
/// upsertAsrGeneratedTrack edge cases, deleteTranscript edge cases, and internal
/// helpers (_normalizeSource default, _parseServerDate, _transcriptRowFromServerMap).
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/transcript_api.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/data/transcript_repository.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_fetch_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ApiClient _fakeApiClient(MockClient client) {
  return ApiClient(
    httpClient: client,
    getBaseUrl: () async => 'https://fake.test',
    getAccessToken: () async => 'token',
    sendAuthHeader: false,
  );
}

TranscriptApi _transcriptApiReturning(List<Map<String, dynamic>> items) {
  final client = MockClient((request) async {
    return http.Response(
      jsonEncode(items),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return TranscriptApi(_fakeApiClient(client));
}

TranscriptApi _transcriptApiThrowing(String message) {
  final client = MockClient((request) async {
    throw Exception(message);
  });
  return TranscriptApi(_fakeApiClient(client));
}

Future<void> _insertAudio(AppDatabase db, String id) async {
  final now = DateTime.utc(2026, 1, 1);
  await db.audioDao.insertRow(
    AudioRow(
      id: id,
      aid: 'aid-$id',
      provider: 'user',
      title: 'Test Audio',
      description: null,
      thumbnailUrl: null,
      durationSeconds: 60,
      language: 'en',
      translationKey: null,
      sourceText: null,
      voice: null,
      source: null,
      localUri: 'file:///tmp/$id.mp3',
      md5: null,
      size: 100,
      mediaUrl: null,
      syncStatus: null,
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> _insertVideo(AppDatabase db, String id) async {
  final now = DateTime.utc(2026, 1, 1);
  await db.videoDao.insertRow(
    VideoRow(
      id: id,
      vid: 'vid-$id',
      provider: 'user',
      title: 'Test Video',
      description: null,
      thumbnailUrl: null,
      durationSeconds: 120,
      language: 'en',
      source: 'local',
      localUri: '/tmp/$id.mp4',
      md5: null,
      size: 200,
      mediaUrl: null,
      syncStatus: null,
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> _insertTranscriptRow(
  AppDatabase db, {
  required String id,
  String targetType = 'Audio',
  required String targetId,
  String language = 'en',
  String source = 'user',
  String? label,
  DateTime? createdAt,
}) async {
  final now = createdAt ?? DateTime.utc(2026, 1, 1);
  final timelineJson = jsonEncode([
    const TranscriptLine(text: 'hello', startMs: 0, durationMs: 1000).toJson(),
  ]);
  await db.transcriptDao.upsert(
    TranscriptRow(
      id: id,
      targetType: targetType,
      targetId: targetId,
      language: language,
      source: source,
      timelineJson: timelineJson,
      referenceId: null,
      label: label ?? 'Track $id',
      trackIndex: null,
      syncStatus: null,
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Map<String, dynamic> _serverTranscriptItem({
  required String id,
  String targetType = 'Audio',
  required String targetId,
  String language = 'en',
  String source = 'official',
  List<Map<String, dynamic>>? timeline,
  String? createdAt,
  String? updatedAt,
  String? label,
  String? referenceId,
}) {
  return {
    'id': id,
    'targetType': targetType,
    'targetId': targetId,
    'language': language,
    'source': source,
    'timeline':
        timeline ??
        [
          {'text': 'line1', 'start': 0, 'duration': 1000},
        ],
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
    if (label != null) 'label': label,
    if (referenceId != null) 'referenceId': referenceId,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('resolveOnOpen', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('returns hasTracks false for unknown media id', () async {
      final repo = TranscriptRepository(db);
      final result = await repo.resolveOnOpen('nonexistent-id');
      expect(result.hasTracks, isFalse);
      expect(result.cloud.status, TranscriptCloudFetchStatus.skipped);
    });

    test('skips cloud fetch when fetchCloud is false', () async {
      await _insertAudio(db, 'a1');
      await _insertTranscriptRow(db, id: 'tr1', targetId: 'a1');

      final repo = TranscriptRepository(db);
      final result = await repo.resolveOnOpen('a1', fetchCloud: false);

      expect(result.hasTracks, isTrue);
      expect(result.cloud.status, TranscriptCloudFetchStatus.skipped);
      expect(result.errorMessage, isNull);
    });

    test('reports error message when cloud fetch fails', () async {
      await _insertAudio(db, 'a2');
      final api = _transcriptApiThrowing('network down');
      final repo = TranscriptRepository(db, api);

      final result = await repo.resolveOnOpen('a2', fetchCloud: true);

      expect(result.cloud.status, TranscriptCloudFetchStatus.error);
      expect(result.errorMessage, contains('network down'));
    });

    test('persists fetch outcome on non-skipped cloud status', () async {
      await _insertAudio(db, 'a3');
      final api = _transcriptApiReturning([]);
      final repo = TranscriptRepository(db, api);

      await repo.resolveOnOpen('a3', fetchCloud: true);

      final state = await db.transcriptFetchStateDao.getForTarget(
        'Audio',
        'a3',
      );
      expect(state, isNotNull);
      expect(state!.lastStatus, 'empty');
    });

    test('does not persist fetch outcome when cloud is skipped', () async {
      await _insertAudio(db, 'a4');
      final repo = TranscriptRepository(db);

      await repo.resolveOnOpen('a4', fetchCloud: true);

      final state = await db.transcriptFetchStateDao.getForTarget(
        'Audio',
        'a4',
      );
      // api is null → skipped → no persist
      expect(state, isNull);
    });

    test('ensures primary transcript is set after resolve', () async {
      await _insertAudio(db, 'a5');
      await _insertTranscriptRow(db, id: 'tr-a5', targetId: 'a5');

      final repo = TranscriptRepository(db);
      await repo.resolveOnOpen('a5', fetchCloud: false);

      final session = await db.echoSessionDao.getLatestForTarget('Audio', 'a5');
      expect(session?.transcriptId, 'tr-a5');
    });
  });

  group('fetchCloudTranscripts', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('returns skipped for unknown media id', () async {
      final repo = TranscriptRepository(db);
      final result = await repo.fetchCloudTranscripts('ghost');
      expect(result.status, TranscriptCloudFetchStatus.skipped);
    });

    test('skips when prior fetch state is non-error and not forced', () async {
      await _insertAudio(db, 'b1');
      await db.transcriptFetchStateDao.upsertOutcome(
        targetType: 'Audio',
        targetId: 'b1',
        lastFetchedAt: DateTime.utc(2026),
        lastStatus: 'success',
      );

      final api = _transcriptApiReturning([
        _serverTranscriptItem(id: 'x', targetId: 'b1'),
      ]);
      final repo = TranscriptRepository(db, api);
      final result = await repo.fetchCloudTranscripts('b1');

      expect(result.status, TranscriptCloudFetchStatus.skipped);
    });

    test('retries when prior fetch state is error and not forced', () async {
      await _insertAudio(db, 'b2');
      await db.transcriptFetchStateDao.upsertOutcome(
        targetType: 'Audio',
        targetId: 'b2',
        lastFetchedAt: DateTime.utc(2026),
        lastStatus: 'error',
        lastError: 'prev failure',
      );

      final api = _transcriptApiReturning([
        _serverTranscriptItem(id: 'x2', targetId: 'b2'),
      ]);
      final repo = TranscriptRepository(db, api);
      final result = await repo.fetchCloudTranscripts('b2');

      expect(result.status, TranscriptCloudFetchStatus.success);
      expect(result.storedCount, 1);
    });

    test('returns skipped when api is null', () async {
      await _insertAudio(db, 'b3');
      final repo = TranscriptRepository(db);
      final result = await repo.fetchCloudTranscripts('b3');
      expect(result.status, TranscriptCloudFetchStatus.skipped);
    });

    test('stores transcripts and returns success', () async {
      await _insertAudio(db, 'b4');
      final api = _transcriptApiReturning([
        _serverTranscriptItem(
          id: 'srv-1',
          targetId: 'b4',
          language: 'en',
          source: 'official',
          label: 'English',
        ),
        _serverTranscriptItem(
          id: 'srv-2',
          targetId: 'b4',
          language: 'es',
          source: 'auto',
          label: 'Spanish',
        ),
      ]);
      final repo = TranscriptRepository(db, api);
      final result = await repo.fetchCloudTranscripts('b4', force: true);

      expect(result.status, TranscriptCloudFetchStatus.success);
      expect(result.storedCount, 2);

      final rows = await db.transcriptDao.listForTarget('Audio', 'b4');
      expect(rows, hasLength(2));
    });

    test('returns empty when api returns empty list', () async {
      await _insertAudio(db, 'b5');
      final api = _transcriptApiReturning([]);
      final repo = TranscriptRepository(db, api);
      final result = await repo.fetchCloudTranscripts('b5', force: true);

      expect(result.status, TranscriptCloudFetchStatus.empty);
    });

    test('returns error when api throws', () async {
      await _insertAudio(db, 'b6');
      final api = _transcriptApiThrowing('timeout');
      final repo = TranscriptRepository(db, api);
      final result = await repo.fetchCloudTranscripts('b6', force: true);

      expect(result.status, TranscriptCloudFetchStatus.error);
      expect(result.errorMessage, contains('timeout'));
    });

    test('returns error when all server items fail to produce rows', () async {
      await _insertAudio(db, 'b7');
      // Items missing required fields → _transcriptRowFromServerMap returns null
      final api = _transcriptApiReturning([
        {'id': null, 'targetType': 'Audio', 'targetId': 'b7'},
        {'id': 'x', 'targetType': null, 'targetId': 'b7'},
      ]);
      final repo = TranscriptRepository(db, api);
      final result = await repo.fetchCloudTranscripts('b7', force: true);

      expect(result.status, TranscriptCloudFetchStatus.error);
      expect(result.errorMessage, 'Could not store cloud transcripts');
    });

    test('normalizes unknown source to official', () async {
      await _insertAudio(db, 'b8');
      final api = _transcriptApiReturning([
        _serverTranscriptItem(
          id: 'srv-unk',
          targetId: 'b8',
          source: 'mystery_source',
        ),
      ]);
      final repo = TranscriptRepository(db, api);
      final result = await repo.fetchCloudTranscripts('b8', force: true);

      expect(result.status, TranscriptCloudFetchStatus.success);
      final rows = await db.transcriptDao.listForTarget('Audio', 'b8');
      expect(rows.single.source, 'official');
    });

    test('parses server dates from string fields', () async {
      await _insertAudio(db, 'b9');
      final api = _transcriptApiReturning([
        _serverTranscriptItem(
          id: 'srv-dates',
          targetId: 'b9',
          createdAt: '2025-06-15T10:30:00.000Z',
          updatedAt: '2025-07-01T12:00:00.000Z',
        ),
      ]);
      final repo = TranscriptRepository(db, api);
      await repo.fetchCloudTranscripts('b9', force: true);

      final row = await db.transcriptDao.getById('srv-dates');
      expect(row, isNotNull);
      // Drift stores as epoch millis and reads back as local time;
      // compare via millisecondsSinceEpoch to be timezone-independent.
      expect(
        row!.createdAt.millisecondsSinceEpoch,
        DateTime.utc(2025, 6, 15, 10, 30).millisecondsSinceEpoch,
      );
      expect(
        row.serverUpdatedAt!.millisecondsSinceEpoch,
        DateTime.utc(2025, 7, 1, 12).millisecondsSinceEpoch,
      );
    });

    test('uses fallback date when server date is not a string', () async {
      await _insertAudio(db, 'b10');
      final api = _transcriptApiReturning([
        {
          'id': 'srv-nodate',
          'targetType': 'Audio',
          'targetId': 'b10',
          'language': 'en',
          'source': 'official',
          'timeline': [
            {'text': 'hi', 'start': 0, 'duration': 500},
          ],
          'createdAt': 12345,
          'updatedAt': null,
        },
      ]);
      final repo = TranscriptRepository(db, api);
      await repo.fetchCloudTranscripts('b10', force: true);

      final row = await db.transcriptDao.getById('srv-nodate');
      expect(row, isNotNull);
      // fallback is DateTime.now() — just verify it's recent
      expect(
        row!.createdAt.isAfter(
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });

    test('skips items with empty timeline', () async {
      await _insertAudio(db, 'b11');
      final api = _transcriptApiReturning([
        _serverTranscriptItem(
          id: 'srv-empty-tl',
          targetId: 'b11',
          timeline: [],
        ),
        _serverTranscriptItem(id: 'srv-good', targetId: 'b11', language: 'fr'),
      ]);
      final repo = TranscriptRepository(db, api);
      final result = await repo.fetchCloudTranscripts('b11', force: true);

      expect(result.status, TranscriptCloudFetchStatus.success);
      expect(result.storedCount, 1);
      final rows = await db.transcriptDao.listForTarget('Audio', 'b11');
      expect(rows, hasLength(1));
      expect(rows.single.id, 'srv-good');
    });

    test('sets primary transcript after successful cloud fetch', () async {
      await _insertAudio(db, 'b12');
      final api = _transcriptApiReturning([
        _serverTranscriptItem(id: 'srv-pri', targetId: 'b12'),
      ]);
      final repo = TranscriptRepository(db, api);
      await repo.fetchCloudTranscripts('b12', force: true);

      final session = await db.echoSessionDao.getLatestForTarget(
        'Audio',
        'b12',
      );
      expect(session?.transcriptId, 'srv-pri');
    });
  });

  group('primaryTranscriptRowForMedia', () {
    late AppDatabase db;
    late TranscriptRepository repo;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
    });

    tearDown(() => db.close());

    test('returns null for unknown media id', () async {
      final row = await repo.primaryTranscriptRowForMedia('nope');
      expect(row, isNull);
    });

    test('returns null when no session exists', () async {
      await _insertAudio(db, 'c1');
      final row = await repo.primaryTranscriptRowForMedia('c1');
      expect(row, isNull);
    });

    test('returns null when session has no transcriptId', () async {
      await _insertAudio(db, 'c2');
      // Create a session without a transcript
      await db.echoSessionDao.updatePrimaryTranscriptForTarget(
        'Audio',
        'c2',
        null,
      );
      final row = await repo.primaryTranscriptRowForMedia('c2');
      expect(row, isNull);
    });

    test('returns the transcript row when session references one', () async {
      await _insertAudio(db, 'c3');
      await _insertTranscriptRow(db, id: 'tr-c3', targetId: 'c3');
      await db.echoSessionDao.updatePrimaryTranscriptForTarget(
        'Audio',
        'c3',
        'tr-c3',
      );

      final row = await repo.primaryTranscriptRowForMedia('c3');
      expect(row, isNotNull);
      expect(row!.id, 'tr-c3');
    });
  });

  group('watchTracks', () {
    late AppDatabase db;
    late TranscriptRepository repo;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
    });

    tearDown(() => db.close());

    test('emits empty list for unknown media id', () async {
      final tracks = await repo.watchTracks('ghost').first;
      expect(tracks, isEmpty);
    });

    test('emits sorted tracks by source priority', () async {
      await _insertAudio(db, 'd1');
      await _insertTranscriptRow(
        db,
        id: 'tr-user',
        targetId: 'd1',
        source: 'user',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      await _insertTranscriptRow(
        db,
        id: 'tr-official',
        targetId: 'd1',
        source: 'official',
        createdAt: DateTime.utc(2026, 1, 2),
      );
      await _insertTranscriptRow(
        db,
        id: 'tr-ai',
        targetId: 'd1',
        source: 'ai',
        createdAt: DateTime.utc(2026, 1, 3),
      );

      final tracks = await repo.watchTracks('d1').first;
      expect(tracks, hasLength(3));
      expect(tracks[0].id, 'tr-official');
      expect(tracks[1].id, 'tr-ai');
      expect(tracks[2].id, 'tr-user');
    });

    test('sorts by createdAt within same source priority', () async {
      await _insertAudio(db, 'd2');
      await _insertTranscriptRow(
        db,
        id: 'tr-later',
        targetId: 'd2',
        source: 'official',
        createdAt: DateTime.utc(2026, 3, 1),
      );
      await _insertTranscriptRow(
        db,
        id: 'tr-earlier',
        targetId: 'd2',
        source: 'official',
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final tracks = await repo.watchTracks('d2').first;
      expect(tracks[0].id, 'tr-earlier');
      expect(tracks[1].id, 'tr-later');
    });
  });

  group('upsertAsrGeneratedTrack edge cases', () {
    late AppDatabase db;
    late TranscriptRepository repo;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
    });

    tearDown(() => db.close());

    test('returns null for unknown media id', () async {
      final id = await repo.upsertAsrGeneratedTrack(
        mediaId: 'ghost',
        language: 'en',
        lines: const [TranscriptLine(text: 'hi', startMs: 0, durationMs: 100)],
      );
      expect(id, isNull);
    });

    test('returns null when lines is empty', () async {
      await _insertAudio(db, 'e1');
      final id = await repo.upsertAsrGeneratedTrack(
        mediaId: 'e1',
        language: 'en',
        lines: const [],
      );
      expect(id, isNull);
    });

    test(
      'does not activate as primary when activateAsPrimary is false',
      () async {
        await _insertAudio(db, 'e2');
        await repo.upsertAsrGeneratedTrack(
          mediaId: 'e2',
          language: 'en',
          lines: const [
            TranscriptLine(text: 'hi', startMs: 0, durationMs: 100),
          ],
          activateAsPrimary: false,
        );

        final session = await db.echoSessionDao.getLatestForTarget(
          'Audio',
          'e2',
        );
        expect(session?.transcriptId, isNull);
      },
    );

    test('preserves existing label on re-generation', () async {
      await _insertAudio(db, 'e3');
      await repo.upsertAsrGeneratedTrack(
        mediaId: 'e3',
        language: 'en',
        lines: const [
          TranscriptLine(text: 'first', startMs: 0, durationMs: 100),
        ],
        label: 'My Custom Label',
      );

      // Re-generate without a label
      final id = await repo.upsertAsrGeneratedTrack(
        mediaId: 'e3',
        language: 'en',
        lines: const [
          TranscriptLine(text: 'second', startMs: 0, durationMs: 200),
        ],
      );

      final row = await db.transcriptDao.getById(id!);
      expect(row!.label, 'My Custom Label');
    });

    test(
      'uses default label when no existing label and none provided',
      () async {
        await _insertAudio(db, 'e4');
        final id = await repo.upsertAsrGeneratedTrack(
          mediaId: 'e4',
          language: 'ja',
          lines: const [
            TranscriptLine(text: 'konnichiwa', startMs: 0, durationMs: 100),
          ],
        );

        final row = await db.transcriptDao.getById(id!);
        expect(row!.label, 'Generated (ja)');
      },
    );

    test('invalidates lines cache on upsert', () async {
      await _insertAudio(db, 'e5');
      final id = await repo.upsertAsrGeneratedTrack(
        mediaId: 'e5',
        language: 'en',
        lines: const [TranscriptLine(text: 'v1', startMs: 0, durationMs: 100)],
      );

      final row1 = await db.transcriptDao.getById(id!);
      final lines1 = repo.linesForRow(row1!);
      expect(lines1.first.text, 'v1');

      // Upsert again with different content
      await repo.upsertAsrGeneratedTrack(
        mediaId: 'e5',
        language: 'en',
        lines: const [TranscriptLine(text: 'v2', startMs: 0, durationMs: 200)],
      );

      final row2 = await db.transcriptDao.getById(id);
      final lines2 = repo.linesForRow(row2!);
      expect(lines2.first.text, 'v2');
    });
  });

  group('deleteTranscript edge cases', () {
    late AppDatabase db;
    late TranscriptRepository repo;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
    });

    tearDown(() => db.close());

    test('no-ops when transcript does not exist', () async {
      // Should not throw
      await repo.deleteTranscript('nonexistent');
    });

    test(
      'deletes row and no-ops session update when no session exists',
      () async {
        await _insertAudio(db, 'f1');
        await _insertTranscriptRow(db, id: 'tr-f1', targetId: 'f1');

        await repo.deleteTranscript('tr-f1');

        final row = await db.transcriptDao.getById('tr-f1');
        expect(row, isNull);
      },
    );

    test('sets primary to null when last transcript is deleted', () async {
      await _insertAudio(db, 'f2');
      await _insertTranscriptRow(db, id: 'tr-only', targetId: 'f2');
      await repo.setActiveTranscript('f2', 'tr-only');

      await repo.deleteTranscript('tr-only');

      final session = await db.echoSessionDao.getLatestForTarget('Audio', 'f2');
      expect(session?.transcriptId, isNull);
    });

    test(
      'does not update session when deleted transcript is not referenced',
      () async {
        await _insertAudio(db, 'f3');
        await _insertTranscriptRow(db, id: 'tr-keep', targetId: 'f3');
        await _insertTranscriptRow(db, id: 'tr-del', targetId: 'f3');
        await repo.setActiveTranscript('f3', 'tr-keep');

        await repo.deleteTranscript('tr-del');

        final session = await db.echoSessionDao.getLatestForTarget(
          'Audio',
          'f3',
        );
        expect(session?.transcriptId, 'tr-keep');
      },
    );
  });

  group('ensurePrimaryTranscript edge cases', () {
    late AppDatabase db;
    late TranscriptRepository repo;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
    });

    tearDown(() => db.close());

    test('returns false for unknown media id', () async {
      final result = await repo.ensurePrimaryTranscript('ghost');
      expect(result, isFalse);
    });

    test('returns false when no tracks exist', () async {
      await _insertAudio(db, 'g1');
      final result = await repo.ensurePrimaryTranscript('g1');
      expect(result, isFalse);
    });

    test('returns false when session already has valid primary', () async {
      await _insertAudio(db, 'g2');
      await _insertTranscriptRow(db, id: 'tr-g2', targetId: 'g2');
      await repo.setActiveTranscript('g2', 'tr-g2');

      final result = await repo.ensurePrimaryTranscript('g2');
      expect(result, isFalse);
    });
  });

  group('setActiveTranscript and setSecondaryTranscript edge cases', () {
    late AppDatabase db;
    late TranscriptRepository repo;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
    });

    tearDown(() => db.close());

    test('setActiveTranscript no-ops for unknown media id', () async {
      // Should not throw
      await repo.setActiveTranscript('ghost', 'tr-x');
    });

    test('setSecondaryTranscript no-ops for unknown media id', () async {
      // Should not throw
      await repo.setSecondaryTranscript('ghost', 'tr-x');
    });

    test('setSecondaryTranscript can clear secondary with null', () async {
      await _insertAudio(db, 'h1');
      await _insertTranscriptRow(db, id: 'tr-h1', targetId: 'h1');
      await repo.setActiveTranscript('h1', 'tr-h1');
      await repo.setSecondaryTranscript('h1', 'tr-h1');

      await repo.setSecondaryTranscript('h1', null);

      final session = await db.echoSessionDao.getLatestForTarget('Audio', 'h1');
      expect(session?.secondaryTranscriptId, isNull);
    });
  });

  group('transcriptRowById', () {
    late AppDatabase db;
    late TranscriptRepository repo;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
    });

    tearDown(() => db.close());

    test('returns null for nonexistent id', () async {
      final row = await repo.transcriptRowById('nope');
      expect(row, isNull);
    });

    test('returns the row when it exists', () async {
      await _insertAudio(db, 'i1');
      await _insertTranscriptRow(db, id: 'tr-i1', targetId: 'i1');

      final row = await repo.transcriptRowById('tr-i1');
      expect(row, isNotNull);
      expect(row!.id, 'tr-i1');
    });
  });

  group('_sourcePriority ordering via watchTracks', () {
    late AppDatabase db;
    late TranscriptRepository repo;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
    });

    tearDown(() => db.close());

    test('unknown source sorts after all known sources', () async {
      await _insertAudio(db, 'j1');
      await _insertTranscriptRow(
        db,
        id: 'tr-unknown',
        targetId: 'j1',
        source: 'weird',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      await _insertTranscriptRow(
        db,
        id: 'tr-user',
        targetId: 'j1',
        source: 'user',
        createdAt: DateTime.utc(2026, 1, 2),
      );
      await _insertTranscriptRow(
        db,
        id: 'tr-auto',
        targetId: 'j1',
        source: 'auto',
        createdAt: DateTime.utc(2026, 1, 3),
      );

      final tracks = await repo.watchTracks('j1').first;
      expect(tracks[0].id, 'tr-auto');
      expect(tracks[1].id, 'tr-user');
      expect(tracks[2].id, 'tr-unknown');
    });
  });

  group('linesForRow cache behavior', () {
    late AppDatabase db;
    late TranscriptRepository repo;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = TranscriptRepository(db);
    });

    tearDown(() => db.close());

    test('returns same instance for same content hash', () {
      final now = DateTime.utc(2026);
      final json = jsonEncode([
        const TranscriptLine(text: 'x', startMs: 0, durationMs: 100).toJson(),
      ]);
      final row = TranscriptRow(
        id: 'cache-1',
        targetType: 'Audio',
        targetId: 'm',
        language: 'en',
        source: 'user',
        timelineJson: json,
        referenceId: null,
        label: 'L',
        trackIndex: null,
        syncStatus: null,
        serverUpdatedAt: null,
        createdAt: now,
        updatedAt: now,
      );

      final a = repo.linesForRow(row);
      final b = repo.linesForRow(row);
      expect(identical(a, b), isTrue);
    });

    test('decodes fresh when content changes even with same id', () {
      final now = DateTime.utc(2026);
      final json1 = jsonEncode([
        const TranscriptLine(text: 'a', startMs: 0, durationMs: 100).toJson(),
      ]);
      final json2 = jsonEncode([
        const TranscriptLine(text: 'b', startMs: 0, durationMs: 200).toJson(),
      ]);

      final row1 = TranscriptRow(
        id: 'cache-2',
        targetType: 'Audio',
        targetId: 'm',
        language: 'en',
        source: 'user',
        timelineJson: json1,
        referenceId: null,
        label: 'L',
        trackIndex: null,
        syncStatus: null,
        serverUpdatedAt: null,
        createdAt: now,
        updatedAt: now,
      );
      final row2 = TranscriptRow(
        id: 'cache-2',
        targetType: 'Audio',
        targetId: 'm',
        language: 'en',
        source: 'user',
        timelineJson: json2,
        referenceId: null,
        label: 'L',
        trackIndex: null,
        syncStatus: null,
        serverUpdatedAt: null,
        createdAt: now,
        updatedAt: now.add(const Duration(seconds: 1)),
      );

      final a = repo.linesForRow(row1);
      final b = repo.linesForRow(row2);
      expect(identical(a, b), isFalse);
      expect(b.first.text, 'b');
    });
  });

  group('fetchCloudTranscripts with Video target (non-YouTube)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('uses transcript api for non-YouTube video', () async {
      await _insertVideo(db, 'v1');
      final api = _transcriptApiReturning([
        _serverTranscriptItem(
          id: 'srv-v1',
          targetType: 'Video',
          targetId: 'v1',
        ),
      ]);
      final repo = TranscriptRepository(db, api);
      final result = await repo.fetchCloudTranscripts('v1', force: true);

      expect(result.status, TranscriptCloudFetchStatus.success);
      expect(result.storedCount, 1);
    });

    test('returns skipped for YouTube video when fetcher is null', () async {
      final now = DateTime.utc(2026, 1, 1);
      await db.videoDao.insertRow(
        VideoRow(
          id: 'v-yt',
          vid: 'dQw4w9WgXcQ',
          provider: 'youtube',
          title: 'YT',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 60,
          language: 'en',
          source: 'youtube',
          localUri: null,
          md5: null,
          size: null,
          mediaUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // No fetcher, no youtube transcripts client
      final repo = TranscriptRepository(db);
      final result = await repo.fetchCloudTranscripts('v-yt', force: true);

      // YouTube path: fetcher is null → skipped
      expect(result.status, TranscriptCloudFetchStatus.skipped);
    });
  });

  group('_persistFetchOutcome via resolveOnOpen', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('persists error status with error message', () async {
      await _insertAudio(db, 'p1');
      final api = _transcriptApiThrowing('server error');
      final repo = TranscriptRepository(db, api);

      await repo.resolveOnOpen('p1', fetchCloud: true);

      final state = await db.transcriptFetchStateDao.getForTarget(
        'Audio',
        'p1',
      );
      expect(state, isNotNull);
      expect(state!.lastStatus, 'error');
      expect(state.lastError, contains('server error'));
    });

    test('persists success status', () async {
      await _insertAudio(db, 'p2');
      final api = _transcriptApiReturning([
        _serverTranscriptItem(id: 'srv-p2', targetId: 'p2'),
      ]);
      final repo = TranscriptRepository(db, api);

      await repo.resolveOnOpen('p2', fetchCloud: true);

      final state = await db.transcriptFetchStateDao.getForTarget(
        'Audio',
        'p2',
      );
      expect(state, isNotNull);
      expect(state!.lastStatus, 'success');
    });
  });

  group('replaceTimeline', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('rewrites JSON in place and preserves identity fields', () async {
      await _insertAudio(db, 'rt1');
      await _insertTranscriptRow(db, id: 'tr-rt', targetId: 'rt1');
      final repo = TranscriptRepository(db);
      final before = await db.transcriptDao.getById('tr-rt');
      expect(before, isNotNull);

      final ok = await repo.replaceTimeline(
        transcriptId: 'tr-rt',
        lines: const [
          TranscriptLine(
            text: 'hello',
            startMs: 0,
            durationMs: 1000,
            timeline: [
              TranscriptWord(text: 'hello', startMs: 0, durationMs: 800),
            ],
          ),
        ],
      );
      expect(ok, isTrue);
      final after = await db.transcriptDao.getById('tr-rt');
      expect(after!.id, before!.id);
      expect(after.source, before.source);
      expect(after.language, before.language);
      expect(after.label, before.label);
      expect(after.targetId, before.targetId);
      expect(after.timelineJson, contains('timeline'));
      expect(after.updatedAt.isAfter(before.updatedAt), isTrue);

      final cached = repo.linesForRow(after);
      expect(cached.single.timeline, isNotNull);
    });

    test('returns false when the row is missing', () async {
      final repo = TranscriptRepository(db);
      final ok = await repo.replaceTimeline(
        transcriptId: 'missing',
        lines: const [TranscriptLine(text: 'x', startMs: 0, durationMs: 1)],
      );
      expect(ok, isFalse);
    });
  });
}
