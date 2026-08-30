// Issue #663 (rebuild scope, item E): the local loading stage must not stat
// the thumbnail on the UI thread per build, and must not decode the stored
// full-resolution artwork into a 16:9 slot.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:enjoy_player/core/utils/local_thumbnail.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/player/application/local_thumbnail_provider.dart';
import 'package:enjoy_player/features/player/presentation/expanded_player_widgets.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_loading_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

class _SignedInAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'u1', email: 't@test.com', name: 'Test'),
  );
}

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('loading_thumb_test_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget wrap(ProviderContainer container, Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets(
    'local loading stage decodes the thumbnail at the slot width, not full size',
    (tester) async {
      final thumb = File('${tempDir.path}/thumb.png');
      thumb.writeAsBytesSync(base64Decode(_onePixelPng));
      final now = DateTime(2026, 1, 1);
      await db.videoDao.insertRow(
        VideoRow(
          id: 'm1',
          vid: 'vid-1',
          provider: 'user',
          title: 'Local video',
          durationSeconds: 0,
          language: 'und',
          source: null,
          localUri: '/tmp/foo.mp4',
          bookmarkData: null,
          md5: 'deadbeef',
          size: 1024,
          localMtimeMs: now.millisecondsSinceEpoch,
          mediaUrl: null,
          createdAt: now,
          updatedAt: now,
          thumbnailUrl: thumb.path,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          deviceGlobalAppDatabaseProvider.overrideWithValue(db),
          authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
          // Resolve synchronously: real `File.exists()` never completes under
          // the test binding's fake async. The provider's own resolution and
          // memoization are covered by the test below.
          localThumbnailFileProvider(
            thumb.path,
          ).overrideWith((ref) async => File(thumb.path)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        wrap(
          container,
          ExpandedPlayerLoadingBody(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            mediaId: 'm1',
          ),
        ),
      );
      // Loading -> row data -> thumbnail file resolved.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // `Image.file` folds `cacheWidth` into a [ResizeImage] around the file
      // provider, so that is where the bound is observable.
      final provider = tester.widget<Image>(find.byType(Image)).image;
      final expected = thumbnailCacheWidthFor(
        tester.getSize(find.byType(PlayerLoadingStage)).width,
      );
      expect(provider, isA<ResizeImage>());
      expect((provider as ResizeImage).width, expected);
      // Bounded: never the unbounded decode the old code performed.
      expect(expected, lessThanOrEqualTo(2048));
    },
  );

  test('provider resolves a path once and memoizes the file per key', () async {
    final thumb = File('${tempDir.path}/thumb.png');
    thumb.writeAsBytesSync(base64Decode(_onePixelPng));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = await container.read(
      localThumbnailFileProvider(thumb.path).future,
    );
    final second = await container.read(
      localThumbnailFileProvider(thumb.path).future,
    );
    expect(first, isNotNull);
    expect(
      identical(first, second),
      isTrue,
      reason: 'One resolution per path — a rebuild must not re-stat',
    );

    // A different path is a different key.
    final other = await container.read(localThumbnailFileProvider(null).future);
    expect(other, isNull);
  });
}
