import 'package:drift/native.dart';
import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/recording_api.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/files/file_storage.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/library/application/library_repository_provider.dart';
import 'package:enjoy_player/features/library/data/library_repository.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_open_side_effects.dart';
import 'package:enjoy_player/features/sync/application/sync_providers.dart';
import 'package:enjoy_player/features/sync/data/recording_target_sync_service.dart';
import 'package:enjoy_player/features/sync/domain/sync_types.dart';
import 'package:enjoy_player/features/transcript/application/transcript_fetch_controller.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_fetch_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../support/fake_player_engine.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

const _profile = UserProfile(id: 'u1', email: 'a@b.com', name: 'Test');

class _SignedInAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(profile: _profile);
}

class _SignedOutAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

/// Records calls to [resolveOnOpen] without touching real DB / network.
class _FakeTranscriptFetchCtrl extends TranscriptFetchCtrl {
  static int resolveCalls = 0;
  static bool? lastSignedIn;
  static Object? throwError;

  static void reset() {
    resolveCalls = 0;
    lastSignedIn = null;
    throwError = null;
  }

  @override
  TranscriptFetchUiState build(String mediaId) {
    return const TranscriptFetchUiState();
  }

  @override
  Future<void> resolveOnOpen({required bool signedIn}) async {
    resolveCalls++;
    lastSignedIn = signedIn;
    if (throwError != null) throw throwError!;
  }
}

ApiClient _testApiClient() => ApiClient(
  httpClient: http.Client(),
  getBaseUrl: () async => 'https://enjoy.bot',
  getAccessToken: () async => null,
);

/// Records calls to [pullRecordingsForTarget] without real network.
class _FakeRecordingTargetSyncService extends RecordingTargetSyncService {
  _FakeRecordingTargetSyncService(AppDatabase db)
    : super(db: db, recordingApi: RecordingApi(_testApiClient()));

  static int pullCalls = 0;
  static String? lastTargetType;
  static String? lastTargetId;
  static Object? throwError;

  static void reset() {
    pullCalls = 0;
    lastTargetType = null;
    lastTargetId = null;
    throwError = null;
  }

  @override
  Future<SyncResult> pullRecordingsForTarget({
    required String targetType,
    required String targetId,
    DateTime? now,
  }) async {
    pullCalls++;
    lastTargetType = targetType;
    lastTargetId = targetId;
    if (throwError != null) throw throwError!;
    return const SyncResult(success: true, synced: 0, failed: 0);
  }
}

/// Records refresh calls without touching real DB / network.
class _FakeMediaLibraryRepository extends MediaLibraryRepository {
  _FakeMediaLibraryRepository(AppDatabase db)
    : super(db, FileStorage(), enqueueSync: null);

  static List<String> refreshCalls = [];
  static Object? throwError;

  static void reset() {
    refreshCalls = [];
    throwError = null;
  }

  @override
  Future<YoutubeMetadataPatch?> refreshYoutubeMetadataIfNeeded(
    String mediaId,
  ) async {
    refreshCalls.add(mediaId);
    if (throwError != null) throw throwError!;
    return null;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Captures a [Ref] from the container so top-level functions that accept
/// [Ref] can be called in tests.
final _refCapture = Provider<Ref>((ref) => ref);

ProviderContainer _container({
  required AppDatabase db,
  required bool signedIn,
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      playerEngineTestDoubleProvider.overrideWithValue(FakePlayerEngine()),
      mediaLibraryRepositoryProvider.overrideWithValue(
        _FakeMediaLibraryRepository(db),
      ),
      authCtrlProvider.overrideWith(
        signedIn ? _SignedInAuthCtrl.new : _SignedOutAuthCtrl.new,
      ),
      // ignore: deprecated_member_use
      transcriptFetchCtrlProvider.overrideWith(_FakeTranscriptFetchCtrl.new),
      recordingTargetSyncServiceProvider.overrideWithValue(
        _FakeRecordingTargetSyncService(db),
      ),
    ],
  );
}

Ref _ref(ProviderContainer container) => container.read(_refCapture);

/// Schedules the refresh with [engine] plus host-style freshness callbacks,
/// mirroring what [runPlayerOpen] passes — the helper itself must never read
/// `playerControllerProvider` (issue #676).
void _scheduleYoutubeRefresh(
  ProviderContainer container, {
  required String mediaId,
  int openGeneration = 1,
  PlayerEngine? engine,
  int Function()? currentOpenGeneration,
  String? Function()? currentSessionMediaId,
}) {
  scheduleYoutubeMetadataRefresh(
    _ref(container),
    mediaId: mediaId,
    openGeneration: openGeneration,
    engine: engine ?? FakePlayerEngine(),
    currentOpenGeneration: currentOpenGeneration ?? () => openGeneration,
    currentSessionMediaId: currentSessionMediaId ?? () => mediaId,
  );
}

/// Emits `buffering=false` repeatedly for a short window so the helper
/// catches it whenever it subscribes (its first DB read yields past the
/// schedule call), then lets the whole side effect drain.
Future<void> _driveYoutubeRefreshReady(FakePlayerEngine engine) async {
  for (var i = 0; i < 20; i++) {
    engine.emitBuffering(false);
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await pumpEventQueue();
}

Future<void> _insertVideoRow(
  AppDatabase db, {
  required String id,
  required String vid,
  required String provider,
  required String title,
  String? thumbnailUrl,
}) async {
  final now = DateTime.now();
  await db.videoDao.insertRow(
    VideoRow(
      id: id,
      vid: vid,
      provider: provider,
      title: title,
      description: null,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: 120,
      language: 'en',
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
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    _FakeTranscriptFetchCtrl.reset();
    _FakeRecordingTargetSyncService.reset();
    _FakeMediaLibraryRepository.reset();
  });

  tearDown(() async {
    await pumpEventQueue();
    await db.close();
  });

  group('schedulePlayerOpenSideEffects', () {
    test('signed out: resolves transcript but skips recording pull', () async {
      final container = _container(db: db, signedIn: false);
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);

      schedulePlayerOpenSideEffects(
        _ref(container),
        openGeneration: 1,
        isStale: () => false,
        mediaId: 'media-1',
        dexieTargetType: 'Video',
      );

      await pumpEventQueue();

      expect(_FakeTranscriptFetchCtrl.resolveCalls, 1);
      expect(_FakeTranscriptFetchCtrl.lastSignedIn, isFalse);
      expect(_FakeRecordingTargetSyncService.pullCalls, 0);
    });

    test('signed in: resolves transcript AND pulls recordings', () async {
      final container = _container(db: db, signedIn: true);
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);

      schedulePlayerOpenSideEffects(
        _ref(container),
        openGeneration: 1,
        isStale: () => false,
        mediaId: 'media-2',
        dexieTargetType: 'Audio',
      );

      await pumpEventQueue();

      expect(_FakeTranscriptFetchCtrl.resolveCalls, 1);
      expect(_FakeTranscriptFetchCtrl.lastSignedIn, isTrue);
      expect(_FakeRecordingTargetSyncService.pullCalls, 1);
      expect(_FakeRecordingTargetSyncService.lastTargetType, 'Audio');
      expect(_FakeRecordingTargetSyncService.lastTargetId, 'media-2');
    });

    test('stale: skips both transcript and recording pull', () async {
      final container = _container(db: db, signedIn: true);
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);

      schedulePlayerOpenSideEffects(
        _ref(container),
        openGeneration: 1,
        isStale: () => true,
        mediaId: 'media-3',
        dexieTargetType: 'Video',
      );

      await pumpEventQueue();

      expect(_FakeTranscriptFetchCtrl.resolveCalls, 0);
      expect(_FakeRecordingTargetSyncService.pullCalls, 0);
    });

    test('transcript error is caught and does not propagate', () async {
      _FakeTranscriptFetchCtrl.throwError = StateError('transcript_boom');
      final container = _container(db: db, signedIn: true);
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);

      // Should not throw despite transcript error.
      schedulePlayerOpenSideEffects(
        _ref(container),
        openGeneration: 1,
        isStale: () => false,
        mediaId: 'media-4',
        dexieTargetType: 'Video',
      );

      await pumpEventQueue();

      expect(_FakeTranscriptFetchCtrl.resolveCalls, 1);
      // Recording pull still runs independently.
      expect(_FakeRecordingTargetSyncService.pullCalls, 1);
    });

    test('recording pull error is caught and does not propagate', () async {
      _FakeRecordingTargetSyncService.throwError = StateError('pull_boom');
      final container = _container(db: db, signedIn: true);
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);

      // Should not throw despite recording pull error.
      schedulePlayerOpenSideEffects(
        _ref(container),
        openGeneration: 1,
        isStale: () => false,
        mediaId: 'media-5',
        dexieTargetType: 'Audio',
      );

      await pumpEventQueue();

      expect(_FakeTranscriptFetchCtrl.resolveCalls, 1);
      expect(_FakeRecordingTargetSyncService.pullCalls, 1);
    });
  });

  group('scheduleYoutubeMetadataRefresh', () {
    test('early return when video row is null', () async {
      final container = _container(db: db, signedIn: false);
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);

      // No row inserted for 'missing-id' — should return early.
      _scheduleYoutubeRefresh(container, mediaId: 'missing-id');

      await pumpEventQueue();
      expect(_FakeMediaLibraryRepository.refreshCalls, isEmpty);
    });

    test('early return when provider is not youtube', () async {
      await _insertVideoRow(
        db,
        id: 'v-user',
        vid: 'abc123',
        provider: 'user',
        title: 'YouTube video abc123',
      );
      final container = _container(db: db, signedIn: false);
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);

      _scheduleYoutubeRefresh(container, mediaId: 'v-user');

      await pumpEventQueue();
      // Returned early because provider != 'youtube'.
      expect(_FakeMediaLibraryRepository.refreshCalls, isEmpty);
    });

    test('early return when metadata does not need refresh', () async {
      await _insertVideoRow(
        db,
        id: 'v-complete',
        vid: 'dQw4w9WgXcQ',
        provider: 'youtube',
        title: 'Real YouTube Title',
        thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg',
      );
      final container = _container(db: db, signedIn: false);
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);

      _scheduleYoutubeRefresh(container, mediaId: 'v-complete');

      await pumpEventQueue();
      // Returned early because title is real and thumbnail exists.
      expect(_FakeMediaLibraryRepository.refreshCalls, isEmpty);
    });

    test('proceeds when title is placeholder (needs refresh)', () async {
      await _insertVideoRow(
        db,
        id: 'v-placeholder',
        vid: 'dQw4w9WgXcQ',
        provider: 'youtube',
        title: 'YouTube video dQw4w9WgXcQ',
        thumbnailUrl: null,
      );
      final container = _container(db: db, signedIn: false);
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);

      // Buffering settles so the readiness gate resolves.
      final engine = FakePlayerEngine();
      _scheduleYoutubeRefresh(
        container,
        mediaId: 'v-placeholder',
        engine: engine,
      );
      await _driveYoutubeRefreshReady(engine);
      expect(_FakeMediaLibraryRepository.refreshCalls, ['v-placeholder']);
    });

    test('proceeds when thumbnail is empty string (needs refresh)', () async {
      await _insertVideoRow(
        db,
        id: 'v-empty-thumb',
        vid: 'dQw4w9WgXcQ',
        provider: 'youtube',
        title: 'Real Title',
        thumbnailUrl: '   ',
      );
      final container = _container(db: db, signedIn: false);
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);

      final engine = FakePlayerEngine();
      _scheduleYoutubeRefresh(
        container,
        mediaId: 'v-empty-thumb',
        engine: engine,
      );
      await _driveYoutubeRefreshReady(engine);
      expect(_FakeMediaLibraryRepository.refreshCalls, ['v-empty-thumb']);
    });

    test('skips refresh when open generation went stale', () async {
      await _insertVideoRow(
        db,
        id: 'v-stale',
        vid: 'dQw4w9WgXcQ',
        provider: 'youtube',
        title: 'YouTube video dQw4w9WgXcQ',
      );
      final container = _container(db: db, signedIn: false);
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);

      final engine = FakePlayerEngine();
      scheduleYoutubeMetadataRefresh(
        _ref(container),
        mediaId: 'v-stale',
        openGeneration: 1,
        engine: engine,
        // A newer open landed meanwhile — the host reports generation 2.
        currentOpenGeneration: () => 2,
        currentSessionMediaId: () => 'v-stale',
      );
      await _driveYoutubeRefreshReady(engine);
      expect(_FakeMediaLibraryRepository.refreshCalls, isEmpty);
    });

    test('repository error is caught and does not escape', () async {
      await _insertVideoRow(
        db,
        id: 'v-boom',
        vid: 'dQw4w9WgXcQ',
        provider: 'youtube',
        title: 'YouTube video dQw4w9WgXcQ',
      );
      _FakeMediaLibraryRepository.throwError = StateError('oembed_boom');
      final container = _container(db: db, signedIn: false);
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);

      // Should not surface as an unhandled async error despite the throw.
      final engine = FakePlayerEngine();
      _scheduleYoutubeRefresh(container, mediaId: 'v-boom', engine: engine);
      await _driveYoutubeRefreshReady(engine);
      expect(_FakeMediaLibraryRepository.refreshCalls, ['v-boom']);
    });
  });
}
