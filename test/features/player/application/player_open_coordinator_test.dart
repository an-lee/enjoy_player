import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_open_coordinator.dart';
import 'package:enjoy_player/features/player/application/player_position_tracker.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/transcript/application/transcript_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../support/fake_player_engine.dart';
import '../../../support/test_path_provider.dart';

/// Minimal [PlayerOpenHost] driving [runPlayerOpen] without the controller.
class _Host implements PlayerOpenHost {
  _Host(this.ref, this.engine);

  final Ref ref;
  final PlayerEngine engine;

  @override
  int openGeneration = 1;

  @override
  bool isOpenStale(int gen) => gen != openGeneration;

  @override
  PlayerEngine get activeEngine => engine;

  PlayerEngine? _ownedEngine;

  @override
  PlayerEngine? get ownedEngine => _ownedEngine;

  @override
  set ownedEngine(PlayerEngine? engine) => _ownedEngine = engine;

  @override
  PlaybackSession? session;

  @override
  PlayerPositionTracker get positionTracker => PlayerPositionTracker(
    ref: ref,
    getEngine: () => engine,
    getSession: () => session,
    setSession: (next) => session = next,
    currentOpenGeneration: () => openGeneration,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('runPlayerOpen engine.open timeout', () {
    late AppDatabase db;
    late FakePlayerEngine fake;
    late ProviderContainer container;
    late PathProviderPlatform originalPathProvider;

    setUp(() async {
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPathProvider(
        Directory.systemTemp.createTempSync('enjoy_player_open_coord').path,
      );
      db = AppDatabase(executor: NativeDatabase.memory());
      fake = FakePlayerEngine();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          playerEngineTestDoubleProvider.overrideWithValue(fake),
          transcriptRepositoryProvider.overrideWithValue(
            TranscriptRepository(db),
          ),
        ],
      );

      final now = DateTime.now();
      final file = File(
        p.join(
          Directory.systemTemp.path,
          'enjoy_open_coord_${DateTime.now().microsecondsSinceEpoch}.mp3',
        ),
      );
      await file.writeAsBytes([1]);
      addTearDown(() async {
        if (await file.exists()) await file.delete();
      });
      await db.audioDao.insertRow(
        AudioRow(
          id: 'hang-1',
          aid: 'x',
          provider: 'user',
          title: 't',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 600,
          language: 'en',
          translationKey: null,
          sourceText: null,
          voice: null,
          source: null,
          localUri: Uri.file(file.path).toString(),
          md5: null,
          size: 1,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      await pumpEventQueue();
      container.dispose();
      await db.close();
      await fake.dispose();
    });

    test('a wedged engine.open fails with TimeoutException instead of hanging, '
        'and invalidates the open generation', () async {
      final hang = Completer<void>();
      fake.openDelay = () => hang.future;

      final host = _Host(_refOf(container), fake);
      final controller = container.read(playerControllerProvider.notifier);
      final genBefore = controller.openGeneration;

      await expectLater(
        runPlayerOpen(
          host,
          _refOf(container),
          'hang-1',
          openTimeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );

      expect(host.session, isNull);
      // The zombie open's continuation must be stale at its next check.
      expect(controller.openGeneration, greaterThan(genBefore));

      // Releasing the wedged open later must not publish a session.
      hang.complete();
      await pumpEventQueue();
      expect(host.session, isNull);
    });

    test(
      'a wedged post-open command degrades instead of hanging the open',
      () async {
        // Field report 2026-08-30: local audio opened right after a YouTube
        // session stuck on the loading skeleton (back + reopen recovered).
        // engine.open is bounded, but the mpv-command steps after it were
        // not — a wedged event pump held the open forever because the
        // session (which dismisses the skeleton) publishes only after them.
        final now = DateTime.now();
        await db.echoSessionDao.upsert(
          EchoSessionRow(
            id: 'es-wedge-1',
            targetType: 'Audio',
            targetId: 'hang-1',
            language: 'en',
            currentTimeMs: 120000,
            playbackRate: 1,
            volume: 1,
            recordingsCount: 0,
            recordingsDurationMs: 0,
            currentSegmentIndex: -1,
            echoActive: false,
            echoStartLine: -1,
            echoEndLine: -1,
            blurActive: false,
            createdAt: now,
            updatedAt: now,
            startedAt: now,
            lastActiveAt: now,
          ),
        );
        final gate = Completer<void>();
        fake.seekGate = gate;
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });

        final host = _Host(_refOf(container), fake);
        await runPlayerOpen(
          host,
          _refOf(container),
          'hang-1',
          engineCommandTimeout: const Duration(milliseconds: 50),
        );

        expect(
          host.session,
          isNotNull,
          reason: 'session must publish despite the never-completing seek',
        );
        expect(fake.seekCalls, isNotEmpty, reason: 'the seek was attempted');
      },
    );
  });

  group('runBoundedEngineStep', () {
    test('completes when the step completes', () async {
      var ran = false;
      await runBoundedEngineStep('x', () async => ran = true);
      expect(ran, isTrue);
    });

    test('a wedged step times out, logs, and does not throw', () async {
      final logs = <String>[];
      await runBoundedEngineStep(
        'wedged step',
        () => Completer<void>().future,
        limit: const Duration(milliseconds: 20),
        logWarning: logs.add,
      );
      expect(logs, hasLength(1));
      expect(logs.single, contains('wedged step timed out'));
    });

    test('a failing step still throws (only timeouts are swallowed)', () async {
      await expectLater(
        runBoundedEngineStep('boom', () async => throw StateError('boom')),
        throwsStateError,
      );
    });
  });
}

Ref _refOf(ProviderContainer container) {
  late Ref captured;
  container.read(
    Provider<int>((ref) {
      captured = ref;
      return 0;
    }),
  );
  return captured;
}
