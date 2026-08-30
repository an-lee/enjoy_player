// ignore_for_file: avoid_redundant_argument_values
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/video_poster_capture_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../support/fake_player_engine.dart';
import '../../../support/test_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoPosterCaptureService', () {
    const mediaId = 'v-cap-echo';

    late AppDatabase db;
    late FakePlayerEngine fake;
    late ProviderContainer container;
    late PathProviderPlatform originalPathProvider;
    late Directory pathProviderRoot;
    late VideoRow video;

    setUp(() async {
      originalPathProvider = PathProviderPlatform.instance;
      pathProviderRoot = Directory.systemTemp.createTempSync(
        'enjoy_poster_cap',
      );
      PathProviderPlatform.instance = TestPathProvider(pathProviderRoot.path);

      db = AppDatabase(executor: NativeDatabase.memory());
      fake = FakePlayerEngine()
        ..screenshotReturnValue = Uint8List.fromList(const [1, 2, 3]);
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );

      final now = DateTime.now();
      await db.videoDao.insertRow(
        VideoRow(
          id: mediaId,
          vid: 'x',
          provider: 'user',
          title: 't',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 600,
          language: 'en',
          source: null,
          localUri: null,
          md5: 'a' * 64,
          size: 1,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      video = (await db.videoDao.getById(mediaId))!;
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      if (pathProviderRoot.existsSync()) {
        pathProviderRoot.deleteSync(recursive: true);
      }
      container.dispose();
      await db.close();
      await fake.dispose();
    });

    Future<void> capture({required int restoredPositionMs}) {
      return container
          .read(videoPosterCaptureServiceProvider)
          .captureAndPersist(
            mediaId: mediaId,
            video: video,
            restoredPositionMs: restoredPositionMs,
            gen: 1,
            currentOpenGeneration: () => 1,
            currentSessionMediaId: () => mediaId,
            sessionDurationSeconds: () => 600,
            activeEngine: fake,
            onSessionThumbnail: (_) {},
          );
    }

    void activateEcho() {
      container
          .read(echoModeProvider.notifier)
          .activate(
            startLineIndex: 0,
            endLineIndex: 0,
            startTimeSeconds: 4,
            endTimeSeconds: 6,
          );
    }

    test(
      'skips capture when echo is active and the open starts at 0',
      () async {
        activateEcho();

        await capture(restoredPositionMs: 0);

        // No poster seek, no seek-back-to-zero, no screenshot: enforcement must
        // not be fighting the capture right after open (issue #659).
        expect(fake.seekCalls, isEmpty);
        expect(fake.screenshotCalls, 0);
        expect((await db.videoDao.getById(mediaId))!.thumbnailUrl, isNull);
      },
    );

    test('still captures without echo when the open starts at 0', () async {
      await capture(restoredPositionMs: 0);

      expect(fake.screenshotCalls, 1);
      // Poster seek, then the restore back to position zero.
      expect(fake.seekCalls, hasLength(2));
      expect(fake.seekCalls.first, const Duration(seconds: 72));
      expect(fake.seekCalls.last, Duration.zero);

      final row = await db.videoDao.getById(mediaId);
      expect(row!.thumbnailUrl, isNotNull);
      expect(File(row.thumbnailUrl!).existsSync(), isTrue);
    });

    test('captures mid-media even with echo active (no poster seek)', () async {
      activateEcho();

      await capture(restoredPositionMs: 12000);

      expect(fake.seekCalls, isEmpty);
      expect(fake.screenshotCalls, 1);
      expect((await db.videoDao.getById(mediaId))!.thumbnailUrl, isNotNull);
    });
  });
}
