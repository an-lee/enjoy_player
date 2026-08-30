import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/open_media_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/domain/player_launch_request.dart';
import 'package:enjoy_player/features/transcript/application/transcript_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/fake_player_engine.dart';
import '../../support/test_path_provider.dart';

EchoSessionRow _session({
  required String targetId,
  required int currentTimeMs,
  required bool echoActive,
}) {
  final now = DateTime.utc(2020);
  return EchoSessionRow(
    id: 'echo-$targetId',
    targetType: 'Audio',
    targetId: targetId,
    language: 'und',
    currentTimeMs: currentTimeMs,
    playbackRate: 1,
    volume: 1,
    echoStartMs: echoActive ? 0 : null,
    echoEndMs: echoActive ? 20000 : null,
    transcriptId: null,
    secondaryTranscriptId: null,
    recordingsCount: 0,
    recordingsDurationMs: 0,
    lastRecordingAt: null,
    currentSegmentIndex: 0,
    echoActive: echoActive,
    echoStartLine: echoActive ? 0 : -1,
    echoEndLine: echoActive ? 2 : -1,
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

/// [FakePlayerEngine] whose [awaitSurfaceReady] blocks until released, so a
/// test can hold the launch pipeline mid-flight (the YouTube readiness wait).
class GatedSurfaceEngine extends FakePlayerEngine {
  Completer<void>? surfaceReadyGate;
  int awaitSurfaceReadyCalls = 0;

  @override
  Future<void> awaitSurfaceReady() async {
    awaitSurfaceReadyCalls++;
    final gate = surfaceReadyGate;
    if (gate != null) await gate.future;
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late FakePlayerEngine fake;
  late Directory pathProviderRoot;
  late PathProviderPlatform originalPathProvider;

  Future<String> insertAudio({
    required String id,
    required String localUri,
  }) async {
    final now = DateTime.utc(2020);
    await db.audioDao.insertRow(
      AudioRow(
        id: id,
        aid: 'x',
        provider: 'user',
        title: 't',
        description: null,
        thumbnailUrl: null,
        durationSeconds: 900,
        language: 'en',
        translationKey: null,
        sourceText: null,
        voice: null,
        source: null,
        localUri: localUri,
        md5: 'm',
        size: 1,
        mediaUrl: null,
        syncStatus: null,
        serverUpdatedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  setUp(() {
    originalPathProvider = PathProviderPlatform.instance;
    pathProviderRoot = Directory.systemTemp.createTempSync('enjoy_launch_path');
    PathProviderPlatform.instance = TestPathProvider(pathProviderRoot.path);

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
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    if (pathProviderRoot.existsSync()) {
      pathProviderRoot.deleteSync(recursive: true);
    }
    await pumpEventQueue();
    container.dispose();
    await db.close();
    await fake.dispose();
  });

  test(
    'explicit launch seeks to start, skips restore, then autoplays',
    () async {
      final file = File('${pathProviderRoot.path}/a.mp3')
        ..writeAsStringSync('x');
      final id = await insertAudio(id: 'm1', localUri: file.uri.toString());
      await db.echoSessionDao.upsert(
        _session(targetId: id, currentTimeMs: 712000, echoActive: true),
      );

      final req = PlayerLaunchRequest.vocabularyOpenSource(
        mediaId: id,
        startSec: 3.0,
        endSec: 5.0,
      );

      await container.read(openMediaLaunchProvider(req).future);

      expect(container.read(playerControllerProvider)?.mediaId, id);
      expect(fake.seekCalls, isNotEmpty);
      expect(fake.seekCalls.last, const Duration(seconds: 3));
      expect(fake.seekCalls.where((d) => d.inMilliseconds == 712000), isEmpty);
      expect(fake.playCallCount, 1);
      final echo = container.read(echoModeProvider);
      expect(echo.active, isTrue);
      expect(echo.startTimeSeconds, 3.0);
      expect(echo.endTimeSeconds, 5.0);
    },
  );

  test('default launch restores persisted position', () async {
    final file = File('${pathProviderRoot.path}/b.mp3')..writeAsStringSync('x');
    final id = await insertAudio(id: 'm2', localUri: file.uri.toString());
    await db.echoSessionDao.upsert(
      _session(targetId: id, currentTimeMs: 45000, echoActive: false),
    );

    await container.read(
      openMediaLaunchProvider(PlayerLaunchRequest(mediaId: id)).future,
    );

    expect(fake.seekCalls, contains(const Duration(milliseconds: 45000)));
    expect(fake.playCallCount, 0);
  });

  test('clear() mid-launch leaves the engine untouched after resume', () async {
    final file = File('${pathProviderRoot.path}/c.mp3')..writeAsStringSync('x');
    final id = await insertAudio(id: 'm3', localUri: file.uri.toString());
    await db.echoSessionDao.upsert(
      _session(targetId: id, currentTimeMs: 712000, echoActive: true),
    );

    final gated = GatedSurfaceEngine();
    final gate = Completer<void>();
    gated.surfaceReadyGate = gate;
    final gatedContainer = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        playerEngineTestDoubleProvider.overrideWithValue(gated),
        transcriptRepositoryProvider.overrideWithValue(
          TranscriptRepository(db),
        ),
      ],
    );
    addTearDown(gatedContainer.dispose);

    final request = PlayerLaunchRequest.vocabularyOpenSource(
      mediaId: id,
      startSec: 3.0,
      endSec: 5.0,
    );
    final launch = gatedContainer.read(openMediaLaunchProvider(request).future);

    // Hold the pipeline inside the readiness wait, then leave the player —
    // clearLivePlaybackSessionIfNeeded clears the controller mid-launch.
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (gated.awaitSurfaceReadyCalls == 0 &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      gated.awaitSurfaceReadyCalls,
      1,
      reason: 'pipeline reached readiness',
    );
    await gatedContainer.read(playerControllerProvider.notifier).clear();

    gate.complete();
    await launch;

    expect(
      gated.seekCalls,
      isEmpty,
      reason: 'cleared engine must not be seeked',
    );
    expect(gated.playCallCount, 0, reason: 'cleared engine must not be played');
    expect(gatedContainer.read(echoModeProvider).active, isFalse);
  });
}
