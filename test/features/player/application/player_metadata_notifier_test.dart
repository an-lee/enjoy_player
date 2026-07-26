import 'dart:io';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_metadata_notifier.dart';
import 'package:enjoy_player/features/transcript/application/transcript_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../support/fake_player_engine.dart';
import '../../../support/test_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePlayerEngine fake;
  late ProviderContainer container;
  late PathProviderPlatform originalPathProvider;
  late Directory pathProviderRoot;

  Future<String> insertAudio(String id) async {
    final now = DateTime.now();
    final tmp = File(
      p.join(
        Directory.systemTemp.path,
        'enjoy_player_meta_${id}_${DateTime.now().microsecondsSinceEpoch}.mp3',
      ),
    );
    await tmp.writeAsBytes([1]);
    final effectiveLocal = Uri.file(tmp.path).toString();
    await db.audioDao.insertRow(
      AudioRow(
        id: id,
        aid: 'aid_$id',
        provider: 'user',
        title: 'old title',
        description: null,
        thumbnailUrl: null,
        durationSeconds: 600,
        language: 'en',
        translationKey: null,
        sourceText: null,
        voice: null,
        source: null,
        localUri: effectiveLocal,
        md5: null,
        size: 1,
        mediaUrl: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  setUp(() {
    originalPathProvider = PathProviderPlatform.instance;
    pathProviderRoot = Directory.systemTemp.createTempSync(
      'enjoy_player_meta_path',
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
    await pumpEventQueue();
    container.dispose();
    await db.close();
    await fake.dispose();
  });

  test('patches session when mediaId and openGeneration match', () async {
    final id = await insertAudio('m1');
    final controller = container.read(playerControllerProvider.notifier);
    await controller.openMedia(id);

    final sessionBefore = container.read(playerControllerProvider);
    expect(sessionBefore!.mediaTitle, 'old title');
    expect(sessionBefore.thumbnailUrl, isNull);

    final captureGen = controller.openGeneration;
    container
        .read(playerMetadataProvider.notifier)
        .patchIfCurrent(
          mediaId: id,
          openGeneration: captureGen,
          title: 'patched title',
          thumbnailUrl: 'https://example.com/cover.jpg',
        );

    final patched = container.read(playerControllerProvider);
    expect(patched!.mediaTitle, 'patched title');
    expect(patched.thumbnailUrl, 'https://example.com/cover.jpg');
    // The patch is a copyWith — every other field is preserved.
    expect(patched.mediaId, sessionBefore.mediaId);
    expect(patched.durationSeconds, sessionBefore.durationSeconds);
  });

  test('skips patch when mediaId no longer matches', () async {
    final idA = await insertAudio('mA');
    final idB = await insertAudio('mB');
    final controller = container.read(playerControllerProvider.notifier);
    await controller.openMedia(idA);
    final captureGen = controller.openGeneration;

    await controller.openMedia(idB);

    container
        .read(playerMetadataProvider.notifier)
        .patchIfCurrent(
          mediaId: idA,
          openGeneration: captureGen,
          title: 'stale-A',
          thumbnailUrl: 'https://example.com/a.jpg',
        );

    final session = container.read(playerControllerProvider);
    expect(session!.mediaId, idB);
    expect(session.mediaTitle, isNot('stale-A'));
  });

  test('skips patch when openGeneration has bumped since capture', () async {
    final idA = await insertAudio('mA');
    final idB = await insertAudio('mB');
    final controller = container.read(playerControllerProvider.notifier);
    await controller.openMedia(idA);
    final captureGen = controller.openGeneration;

    // Open another media — this bumps openGeneration.
    await controller.openMedia(idB);
    final newGen = controller.openGeneration;
    expect(newGen, isNot(captureGen));

    container
        .read(playerMetadataProvider.notifier)
        .patchIfCurrent(
          mediaId: idB,
          openGeneration: captureGen, // stale snapshot
          title: 'stale-gen',
          thumbnailUrl: 'https://example.com/x.jpg',
        );

    final session = container.read(playerControllerProvider);
    expect(session!.mediaTitle, isNot('stale-gen'));
  });

  test('no-op when session is null (no media open)', () async {
    // No openMedia call — session is null.
    container
        .read(playerMetadataProvider.notifier)
        .patchIfCurrent(
          mediaId: 'whatever',
          openGeneration: 0,
          title: 'never-applied',
        );

    final session = container.read(playerControllerProvider);
    expect(session, isNull);
  });

  test('keeps existing thumbnailUrl when patched with null', () async {
    final id = await insertAudio('m-thumb');
    final controller = container.read(playerControllerProvider.notifier);
    await controller.openMedia(id);

    final captureGen = controller.openGeneration;

    // First, set a thumbnail.
    container
        .read(playerMetadataProvider.notifier)
        .patchIfCurrent(
          mediaId: id,
          openGeneration: captureGen,
          title: 'new-title',
          thumbnailUrl: 'https://example.com/first.jpg',
        );
    expect(
      container.read(playerControllerProvider)!.thumbnailUrl,
      'https://example.com/first.jpg',
    );

    // Now patch again with null thumbnail — implementation must preserve.
    container
        .read(playerMetadataProvider.notifier)
        .patchIfCurrent(
          mediaId: id,
          openGeneration: controller.openGeneration,
          title: 'newer-title',
          // thumbnailUrl: null (default)
        );
    final session = container.read(playerControllerProvider);
    expect(session!.mediaTitle, 'newer-title');
    expect(session.thumbnailUrl, 'https://example.com/first.jpg');
  });

  test('matches the captured openGeneration exactly', () async {
    final id = await insertAudio('m-match');
    final controller = container.read(playerControllerProvider.notifier);
    await controller.openMedia(id);

    final exactGen = controller.openGeneration;
    expect(controller.openGeneration, exactGen);

    container
        .read(playerMetadataProvider.notifier)
        .patchIfCurrent(
          mediaId: id,
          openGeneration: exactGen + 1, // not the real gen
          title: 'wrong-gen',
        );

    final session = container.read(playerControllerProvider);
    expect(session!.mediaTitle, isNot('wrong-gen'));
  });
}
