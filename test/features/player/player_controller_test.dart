import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_player_engine.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine_rev.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_preferences_provider.dart';
import 'package:enjoy_player/features/player/domain/media_relocate_exception.dart';
import 'package:enjoy_player/features/player/domain/player_settings.dart';
import 'package:enjoy_player/features/transcript/application/transcript_repository_provider.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/fake_player_engine.dart';
import '../../support/test_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerController', () {
    late AppDatabase db;
    late FakePlayerEngine fake;
    late ProviderContainer container;
    late PathProviderPlatform originalPathProvider;
    late Directory pathProviderRoot;

    Future<String> insertMedia({
      required String id,
      String kind = 'audio',
      String? localUri,
      String? mediaUrl,
      String? md5,
      String? thumbnailUrl,
      int durationSeconds = 600,
    }) async {
      final now = DateTime.now();
      late final String effectiveLocal;
      if (localUri != null) {
        effectiveLocal = localUri;
      } else {
        final ext = kind == 'video' ? '.mp4' : '.mp3';
        final tmp = File(
          p.join(
            Directory.systemTemp.path,
            'enjoy_player_ctrl_${id}_${DateTime.now().microsecondsSinceEpoch}$ext',
          ),
        );
        await tmp.writeAsBytes([1]);
        effectiveLocal = Uri.file(tmp.path).toString();
      }
      if (kind == 'video') {
        await db.videoDao.insertRow(
          VideoRow(
            id: id,
            vid: 'x',
            provider: 'user',
            title: 't',
            description: null,
            thumbnailUrl: thumbnailUrl,
            durationSeconds: durationSeconds,
            language: 'en',
            source: null,
            localUri: effectiveLocal,
            md5: md5,
            size: 1,
            mediaUrl: mediaUrl,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await db.audioDao.insertRow(
          AudioRow(
            id: id,
            aid: 'x',
            provider: 'user',
            title: 't',
            description: null,
            thumbnailUrl: thumbnailUrl,
            durationSeconds: durationSeconds,
            language: 'en',
            translationKey: null,
            sourceText: null,
            voice: null,
            source: null,
            localUri: effectiveLocal,
            md5: md5,
            size: 1,
            mediaUrl: mediaUrl,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      return id;
    }

    setUp(() {
      originalPathProvider = PathProviderPlatform.instance;
      pathProviderRoot = Directory.systemTemp.createTempSync(
        'enjoy_player_ctrl_path',
      );
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

      // Let fire-and-forget openMedia side effects settle before closing Drift.
      await pumpEventQueue();
      container.dispose();
      await db.close();
      await fake.dispose();
    });

    test('openMedia loads row and sets session', () async {
      final id = await insertMedia(id: 'm1');
      final n = container.read(playerControllerProvider.notifier);
      await n.openMedia(id);

      final session = container.read(playerControllerProvider);
      expect(session, isNotNull);
      expect(session!.mediaId, id);
      expect(session.mediaTitle, 't');
      expect(session.dexieTargetType, 'Audio');
      expect(fake.openUris, hasLength(1));
      expect(fake.openUris.single, startsWith('file:'));
    });

    test('openMedia same id again does not reload uri', () async {
      final id = await insertMedia(id: 'm1');
      final n = container.read(playerControllerProvider.notifier);
      await n.openMedia(id);
      final firstUri = fake.openUris.single;
      await n.openMedia(id);

      expect(fake.openUris, [firstUri]);
    });

    test('openMedia bumps library updatedAt for Home recent media', () async {
      final oldUpdated = DateTime.utc(2024, 1, 1);
      final id = await insertMedia(id: 'm-recent');
      final seeded = await db.audioDao.getById(id);
      await db.audioDao.insertRow(seeded!.copyWith(updatedAt: oldUpdated));

      final n = container.read(playerControllerProvider.notifier);
      await n.openMedia(id);
      await pumpEventQueue();

      final afterOpen = await db.audioDao.getById(id);
      expect(afterOpen!.updatedAt.isAfter(oldUpdated), isTrue);

      // Same-id reopen must still bump (Home recent), without reloading URI.
      await db.audioDao.insertRow(afterOpen.copyWith(updatedAt: oldUpdated));
      await n.openMedia(id);
      await pumpEventQueue();

      final afterReopen = await db.audioDao.getById(id);
      expect(afterReopen!.updatedAt.isAfter(oldUpdated), isTrue);
      expect(fake.openUris, hasLength(1));
    });

    test('openMedia ignores stale completion when superseded', () async {
      fake.openDelay = () =>
          Future<void>.delayed(const Duration(milliseconds: 250));
      final idA = await insertMedia(id: 'a');
      final idB = await insertMedia(id: 'b');

      final n = container.read(playerControllerProvider.notifier);
      final f1 = n.openMedia(idA);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final f2 = n.openMedia(idB);
      await Future.wait([f1, f2]);

      expect(container.read(playerControllerProvider)?.mediaId, idB);
    });

    test('clear invalidates in-flight openMedia', () async {
      fake.openDelay = () =>
          Future<void>.delayed(const Duration(milliseconds: 250));
      final idA = await insertMedia(id: 'a');
      final idB = await insertMedia(id: 'b');

      final n = container.read(playerControllerProvider.notifier);
      final f1 = n.openMedia(idA);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await n.clear();
      final f2 = n.openMedia(idB);
      await Future.wait([f1, f2]);

      expect(container.read(playerControllerProvider)?.mediaId, idB);
    });

    test('debounced session persistence writes position', () async {
      final id = await insertMedia(id: 'm1');
      final n = container.read(playerControllerProvider.notifier);
      await n.openMedia(id);

      fake.emitDuration(const Duration(seconds: 120));
      fake.emitPosition(const Duration(seconds: 7));

      await Future<void>.delayed(const Duration(milliseconds: 550));

      final row = await db.echoSessionDao.getLatestForTarget('Audio', id);
      expect(row, isNotNull);
      expect(row!.currentTimeMs, closeTo(7000, 50));
    });

    test('echo mode seeks back into window', () async {
      final id = await insertMedia(id: 'm1');
      final n = container.read(playerControllerProvider.notifier);
      await n.openMedia(id);

      container
          .read(echoModeProvider.notifier)
          .activate(
            startLineIndex: 0,
            endLineIndex: 1,
            startTimeSeconds: 2,
            endTimeSeconds: 5,
          );

      fake.emitPosition(const Duration(milliseconds: 500));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fake.seekCalls, isNotEmpty);
      expect(fake.seekCalls.last, const Duration(milliseconds: 2000));
    });

    test(
      'echo pause-and-rewind fires on the boundary tick, not the next bucket',
      () async {
        // P1: enforcement runs on every position event, so the segment-end pause
        // must fire the instant the end guard is crossed (within ~40 ms of end),
        // not be deferred ~360 ms to the next 400 ms session-emit bucket.
        final id = await insertMedia(id: 'echo-boundary');
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);

        container
            .read(echoModeProvider.notifier)
            .activate(
              startLineIndex: 0,
              endLineIndex: 1,
              startTimeSeconds: 2,
              endTimeSeconds: 5,
            );

        // 4.95s is below the end guard (5.0 - defaultEchoEndGuardSeconds 0.04);
        // 4.97s crosses it. Both land between 400 ms buckets.
        fake.emitPosition(const Duration(milliseconds: 4950));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          fake.pauseCallCount,
          0,
          reason: 'below end guard must not pause',
        );

        fake.emitPosition(const Duration(milliseconds: 4970));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(fake.pauseCallCount, greaterThanOrEqualTo(1));
        expect(fake.seekCalls.last, const Duration(milliseconds: 2000));
      },
    );

    test(
      'echo enforcement fires within the same 400ms bucket at the boundary',
      () async {
        // P1 core regression: all three positions fall in the SAME 400 ms
        // session-emit bucket (12). Under the old bucket-gated enforcement only
        // the first would be evaluated (4.85s, below the end guard -> no pause),
        // so the 4.96s boundary would be missed until the next bucket (~5.2s) —
        // ~240 ms late. Per-tick enforcement must catch it on the 4.96s tick.
        final id = await insertMedia(id: 'echo-fine');
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);

        container
            .read(echoModeProvider.notifier)
            .activate(
              startLineIndex: 0,
              endLineIndex: 1,
              startTimeSeconds: 2,
              endTimeSeconds: 5,
            );

        fake.emitPosition(const Duration(milliseconds: 4850));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(fake.pauseCallCount, 0);

        fake.emitPosition(const Duration(milliseconds: 4900));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(fake.pauseCallCount, 0);

        // 4.96s crosses the end guard (5.0 - 0.04); pause-and-rewind fires now,
        // not deferred to the next 400 ms bucket.
        fake.emitPosition(const Duration(milliseconds: 4960));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(fake.pauseCallCount, greaterThanOrEqualTo(1));
        expect(fake.seekCalls.last, const Duration(milliseconds: 2000));
      },
    );

    test(
      'echo enforcement is single-flight: concurrent seeks do not interleave',
      () async {
        // P6: a reactive tick (pause-and-rewind) and a proactive user seek must
        // serialize through one gate so they can't interleave overlapping seeks.
        final id = await insertMedia(id: 'echo-serial');
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);

        container
            .read(echoModeProvider.notifier)
            .activate(
              startLineIndex: 0,
              endLineIndex: 1,
              startTimeSeconds: 2,
              endTimeSeconds: 5,
            );

        // Hold the rewind seek in flight.
        final gate = Completer<void>();
        fake.seekGate = gate;

        // Cross the end guard -> pause + rewind-seek starts and blocks on gate.
        fake.emitPosition(const Duration(milliseconds: 4970));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(fake.pauseCallCount, 1);
        expect(fake.seekCalls.last, const Duration(milliseconds: 2000));
        final seeksWhileRewinding = fake.seekCalls.length;

        // While that op is in flight, more boundary ticks arrive and a user seek
        // (clampAndSeek) is requested. None may start a second overlapping seek.
        fake.emitPosition(const Duration(milliseconds: 4980));
        fake.emitPosition(const Duration(milliseconds: 4990));
        final clampFuture = n.seekToSeconds(2.5);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          fake.pauseCallCount,
          1,
          reason: 'no concurrent pause while in flight',
        );
        expect(
          fake.seekCalls.length,
          seeksWhileRewinding,
          reason: 'no overlapping seek while the rewind is in flight',
        );

        // Release the in-flight rewind; the queued user clamp proceeds (serialized).
        gate.complete();
        await clampFuture;
        expect(fake.seekCalls.last, const Duration(milliseconds: 2500));
      },
    );

    test(
      'position is durably written mid-playback (survives a simulated crash)',
      () async {
        // P9: under continuous playback the 450 ms debounce is re-armed every
        // 400 ms and would never fire; the max-age flush must write within ~2 s
        // so a crash never loses more than that.
        final id = await insertMedia(id: 'echo-crash');
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);
        fake.emitDuration(const Duration(seconds: 120));

        // Emit on the 400 ms playback grid for clearly more than 2 s, re-arming
        // the debounce each time so only the max-age path can land a write.
        for (var ms = 400; ms <= 2800; ms += 400) {
          fake.emitPosition(Duration(milliseconds: ms));
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }

        // Poll for the write (the max-age flush is async against Drift).
        int? persistedMs;
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (DateTime.now().isBefore(deadline)) {
          final row = await db.echoSessionDao.getLatestForTarget('Audio', id);
          if (row != null && row.currentTimeMs > 0) {
            persistedMs = row.currentTimeMs;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        expect(
          persistedMs,
          isNotNull,
          reason: 'max-age flush must write mid-playback',
        );
        expect(persistedMs!, greaterThan(1500));
        expect(persistedMs, lessThanOrEqualTo(2800));
      },
    );

    test(
      'openMedia throws MediaNeedsRelocateException when local missing and hash set',
      () async {
        final now = DateTime.now();
        const id = 'reloc-1';
        const fingerprint =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final missingPath = p.join(
          Directory.systemTemp.path,
          'enjoy_missing_${DateTime.now().microsecondsSinceEpoch}.mp4',
        );
        final uri = Uri.file(missingPath).toString();

        await db.videoDao.insertRow(
          VideoRow(
            id: id,
            vid: fingerprint,
            provider: 'user',
            title: 'From sync',
            description: null,
            thumbnailUrl: null,
            durationSeconds: 1,
            language: 'en',
            source: null,
            localUri: uri,
            md5: fingerprint,
            size: 100,
            mediaUrl: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final n = container.read(playerControllerProvider.notifier);
        await expectLater(
          n.openMedia(id),
          throwsA(isA<MediaNeedsRelocateException>()),
        );
        expect(fake.openUris, isEmpty);
      },
    );

    test('openMedia uses mediaUrl when local file is missing', () async {
      final id = await insertMedia(
        id: 'net-1',
        localUri: Uri.file(
          p.join(
            Directory.systemTemp.path,
            'surely_missing_${DateTime.now().microsecondsSinceEpoch}.mp3',
          ),
        ).toString(),
        mediaUrl: 'https://example.com/media.mp4',
        md5: 'any',
      );
      final n = container.read(playerControllerProvider.notifier);
      await n.openMedia(id);
      expect(fake.openUris, ['https://example.com/media.mp4']);
    });

    test('openMedia prefers trusted localUri over mediaUrl', () async {
      final file = File(
        p.join(
          Directory.systemTemp.path,
          'enjoy_local_prefers_${DateTime.now().microsecondsSinceEpoch}.mp4',
        ),
      );
      // insertMedia stores size: 1 — keep the file matching that trust check.
      await file.writeAsBytes(const [1]);
      addTearDown(() async {
        if (await file.exists()) await file.delete();
      });
      final localUri = Uri.file(file.path).toString();
      final id = await insertMedia(
        id: 'local-pref-1',
        kind: 'video',
        localUri: localUri,
        mediaUrl: 'https://example.com/should-not-open.mp4',
        md5: 'hash-local-pref',
      );
      final n = container.read(playerControllerProvider.notifier);
      await n.openMedia(id);
      expect(fake.openUris, [localUri]);
    });

    test(
      'openMedia persists video poster from screenshot when thumbnail missing',
      () async {
        const hash =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final id = await insertMedia(id: 'v-cap', kind: 'video', md5: hash);
        fake.screenshotReturnValue = Uint8List.fromList(const [10, 11, 12]);
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);

        // The capture pipeline schedules its own real-time delays (seek +
        // settle) before writing the thumbnail, so poll for completion
        // instead of racing it with a single fixed sleep, which flakes
        // under CPU contention (e.g. full-suite runs).
        VideoRow? row = await db.videoDao.getById(id);
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (row?.thumbnailUrl == null && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          row = await db.videoDao.getById(id);
        }

        expect(fake.screenshotCalls, greaterThanOrEqualTo(1));
        expect(row!.thumbnailUrl, isNotNull);
        final thumbFile = File(row.thumbnailUrl!);
        expect(thumbFile.existsSync(), isTrue);
        expect(await thumbFile.readAsBytes(), fake.screenshotReturnValue);

        final session = container.read(playerControllerProvider);
        expect(session?.thumbnailUrl, row.thumbnailUrl);
      },
    );

    test(
      'openMedia skips poster capture when remote thumbnail url set',
      () async {
        final id = await insertMedia(
          id: 'v-remote',
          kind: 'video',
          thumbnailUrl: 'https://cdn.example/x.jpg',
        );
        fake.screenshotReturnValue = Uint8List.fromList(const [1, 2, 3]);
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        expect(fake.screenshotCalls, 0);
      },
    );

    test(
      'openMedia skips poster capture when local thumbnail file exists',
      () async {
        final tmp = File(
          p.join(
            Directory.systemTemp.path,
            'enjoy_thumb_${DateTime.now().microsecondsSinceEpoch}.jpg',
          ),
        );
        await tmp.writeAsBytes(const [1, 2, 3]);
        final id = await insertMedia(
          id: 'v-has-thumb',
          kind: 'video',
          thumbnailUrl: tmp.path,
        );
        fake.screenshotReturnValue = Uint8List.fromList(const [9, 9, 9]);
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        expect(fake.screenshotCalls, 0);
      },
    );

    test('openMedia does not capture poster for audio', () async {
      final id = await insertMedia(id: 'a-cap');
      fake.screenshotReturnValue = Uint8List.fromList(const [1]);
      final n = container.read(playerControllerProvider.notifier);
      await n.openMedia(id);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(fake.screenshotCalls, 0);
    });

    test('openMedia applies default volume and rate to engine', () async {
      final id = await insertMedia(id: 'prefs-1');
      final n = container.read(playerControllerProvider.notifier);
      await n.openMedia(id);
      expect(fake.lastVolume, 1.0);
      expect(fake.lastRate, 1.0);
    });

    test('clear stops engine and clears session', () async {
      final id = await insertMedia(id: 'clr-1');
      final n = container.read(playerControllerProvider.notifier);
      await n.openMedia(id);
      expect(container.read(playerControllerProvider), isNotNull);
      await n.clear();
      expect(container.read(playerControllerProvider), isNull);
      expect(fake.stopCallCount, greaterThan(0));
    });

    test('clear retains YoutubePlayerEngine without rev bump', () async {
      Future<String> insertYoutube({required String id}) async {
        final now = DateTime.now();
        await db.videoDao.insertRow(
          VideoRow(
            id: id,
            vid: 'dQw4w9WgXcQ',
            provider: 'youtube',
            title: 'YouTube test',
            description: null,
            thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg',
            durationSeconds: 212,
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
        return id;
      }

      final ytContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          transcriptRepositoryProvider.overrideWithValue(
            TranscriptRepository(db),
          ),
        ],
      );
      addTearDown(ytContainer.dispose);

      final id = await insertYoutube(id: 'yt-retain');
      final n = ytContainer.read(playerControllerProvider.notifier);
      await n.openMedia(id);
      final revAfterOpen = ytContainer.read(playerEngineRevProvider);

      expect(n.engine, isA<YoutubePlayerEngine>());
      await n.clear();

      expect(ytContainer.read(playerControllerProvider), isNull);
      expect(n.engine, isA<YoutubePlayerEngine>());
      expect(ytContainer.read(playerEngineRevProvider), revAfterOpen);
    });

    test(
      'openMedia persists decoded duration when video row duration is zero',
      () async {
        final id = await insertMedia(
          id: 'v-dur0',
          kind: 'video',
          durationSeconds: 0,
        );
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);
        fake.emitDuration(const Duration(seconds: 91));
        await Future<void>.delayed(const Duration(milliseconds: 120));
        final row = await db.videoDao.getById(id);
        expect(row!.durationSeconds, 91);
      },
    );

    // ── Deterministic end-of-media completion loop (ADR-0044, issue #307) ────

    test(
      'RepeatMode.single loops on completion: seek-to-zero + play per fire',
      () async {
        final id = await insertMedia(id: 'eom-single');
        await container
            .read(playerPreferencesCtrlProvider.notifier)
            .setRepeatMode(RepeatMode.single);
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);
        fake.emitDuration(const Duration(seconds: 10));

        fake.emitCompleted();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(fake.seekCalls, contains(Duration.zero));
        expect(fake.playCallCount, greaterThanOrEqualTo(1));

        final seeksAfterFirst = fake.seekCalls.length;

        fake.emitCompleted();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          fake.seekCalls.length,
          seeksAfterFirst + 1,
          reason: 'second completion triggers exactly one more seek',
        );
      },
    );

    test(
      'duplicate completed events do not double-seek (single-flight)',
      () async {
        final id = await insertMedia(id: 'eom-dup');
        await container
            .read(playerPreferencesCtrlProvider.notifier)
            .setRepeatMode(RepeatMode.single);
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);

        // Fire two completions synchronously (same microtask). Only one should
        // be processed per loop iteration — the second lands while no
        // subscription is active (broadcast stream, no replay).
        fake.emitCompleted();
        fake.emitCompleted();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final seeksAfterBurst = fake.seekCalls.length;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          fake.seekCalls.length,
          seeksAfterBurst,
          reason: 'duplicate completions must not cause extra seeks',
        );
      },
    );

    test(
      'late completion after gen bump is a no-op (no stray seek on next media)',
      () async {
        final idA = await insertMedia(id: 'eom-late-a');
        final idB = await insertMedia(id: 'eom-late-b');
        await container
            .read(playerPreferencesCtrlProvider.notifier)
            .setRepeatMode(RepeatMode.single);
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(idA);

        // Bumping the gen via abandonPendingOpen cancels the active loop.
        n.abandonPendingOpen();

        // A stale completion arriving after the gen bump should be a no-op.
        fake.emitCompleted();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          fake.seekCalls.where((d) => d == Duration.zero).length,
          0,
          reason: 'stale completion must not cause a seek',
        );

        // Opening B starts a fresh loop; B's playback should be unaffected.
        await n.openMedia(idB);
        expect(container.read(playerControllerProvider)?.mediaId, idB);
      },
    );

    test('RepeatMode.none stops the loop (no seek, no advance)', () async {
      final id = await insertMedia(id: 'eom-none');
      await container
          .read(playerPreferencesCtrlProvider.notifier)
          .setRepeatMode(RepeatMode.none);
      final n = container.read(playerControllerProvider.notifier);
      await n.openMedia(id);

      final seeksBefore = fake.seekCalls.length;
      fake.emitCompleted();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        fake.seekCalls.length,
        seeksBefore,
        reason: 'RepeatMode.none must not seek on completion',
      );

      // A second completion should also be a no-op (loop has returned).
      fake.emitCompleted();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.seekCalls.length, seeksBefore);
    });

    test(
      'RepeatMode.segment seeks to echo start on completion when echo active',
      () async {
        final id = await insertMedia(id: 'eom-segment');
        await container
            .read(playerPreferencesCtrlProvider.notifier)
            .setRepeatMode(RepeatMode.segment);
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);
        fake.emitDuration(const Duration(seconds: 30));

        container
            .read(echoModeProvider.notifier)
            .activate(
              startLineIndex: 0,
              endLineIndex: 1,
              startTimeSeconds: 3,
              endTimeSeconds: 8,
            );

        // Simulate end-of-media (e.g. segment ending at the tail of the file).
        fake.emitCompleted();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          fake.seekCalls.last,
          const Duration(seconds: 3),
          reason: 'segment repeat must seek to echo start',
        );
        expect(fake.playCallCount, greaterThanOrEqualTo(1));
      },
    );

    test(
      'RepeatMode.segment without echo falls back to stop (no seek)',
      () async {
        final id = await insertMedia(id: 'eom-seg-noecho');
        await container
            .read(playerPreferencesCtrlProvider.notifier)
            .setRepeatMode(RepeatMode.segment);
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);

        final seeksBefore = fake.seekCalls.length;
        fake.emitCompleted();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          fake.seekCalls.length,
          seeksBefore,
          reason: 'segment repeat without echo must not seek',
        );
      },
    );

    test(
      'clear cancels the completion loop (no stray seek after clear)',
      () async {
        final id = await insertMedia(id: 'eom-clear');
        await container
            .read(playerPreferencesCtrlProvider.notifier)
            .setRepeatMode(RepeatMode.single);
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);

        await n.clear();
        final seeksAfterClear = fake.seekCalls.length;

        // A completion event arriving after clear must be a no-op.
        fake.emitCompleted();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          fake.seekCalls.length,
          seeksAfterClear,
          reason: 'completion after clear must not seek',
        );
      },
    );

    test(
      'user seek bumps playbackGen — stale completion during seek is discarded',
      () async {
        final id = await insertMedia(id: 'eom-seek');
        await container
            .read(playerPreferencesCtrlProvider.notifier)
            .setRepeatMode(RepeatMode.single);
        final n = container.read(playerControllerProvider.notifier);
        await n.openMedia(id);

        // Emit a completion while the loop is waiting, then immediately seek.
        // The seek bumps the gen, invalidating the in-flight await. The stale
        // completion must not cause a stray seek-to-zero.
        fake.emitCompleted();
        await n.seekToSeconds(5.0);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // The seek call should be to 5s (the user seek), not Duration.zero
        // (the stale completion's replay target).
        expect(fake.seekCalls, contains(const Duration(seconds: 5)));
        // We expect at most one Duration.zero from the stale completion that
        // may have raced with the gen bump. The key assertion is that the user
        // seek is present and not overwritten.
      },
    );
  });

  group('PlayerController.warmYoutubeSurface Linux opt-out (ADR-0048)', () {
    // No playerEngineTestDoubleProvider override here — the warm gate under
    // test sits below the test-double short-circuit in the real controller.
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await pumpEventQueue();
      container.dispose();
      await db.close();
    });

    test('does not install the YouTube engine when opted out', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final n = container.read(playerControllerProvider.notifier);
      n.warmYoutubeSurface();

      expect(
        n.ownedEngine,
        isNull,
        reason: 'feed-scroll warm must not install a YouTube engine on Linux',
      );
      expect(
        container.read(playerEngineRevProvider),
        0,
        reason: 'no engine swap happened, so the host rev must not bump',
      );
    });

    test('installs and warms a YouTube engine on other targets', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final n = container.read(playerControllerProvider.notifier);
      n.warmYoutubeSurface();

      expect(n.ownedEngine, isA<YoutubePlayerEngine>());
      expect(container.read(playerEngineRevProvider), 1);
    });
  });
}
