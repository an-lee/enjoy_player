import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/youtube_open_preview_provider.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_surface_target.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_loading_video_stage.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_video_poster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_player_engine.dart';

void main() {
  late FakePlayerEngine fake;

  setUp(() {
    fake = FakePlayerEngine();
  });

  tearDown(() async {
    await fake.dispose();
  });

  Future<void> pumpStage(
    WidgetTester tester, {
    required String mediaId,
    required AsyncValue<({String videoId, String? thumbnailUrl})?> preview,
    PlayerEngine? engine,
  }) async {
    final overrides = <Override>[
      youtubeOpenPreviewProvider(mediaId).overrideWith((ref) async {
        return preview.when(
          data: (v) => v,
          loading: () async {
            // Sleep briefly so async loading state can settle.
            await Future<void>.delayed(const Duration(milliseconds: 1));
            return null;
          },
          error: (_, __) async => null,
        );
      }),
      playerEngineTestDoubleProvider.overrideWithValue(engine),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: YoutubeLoadingVideoStage(mediaId: 'media-1'),
            ),
          ),
        ),
      ),
    );
    // Allow the FutureProvider to resolve.
    await tester.pumpAndSettle();
  }

  group('YoutubeLoadingVideoStage', () {
    testWidgets(
      'renders a 16:9 AspectRatio with a PlayerSurfaceTarget and black backdrop',
      (tester) async {
        await pumpStage(
          tester,
          mediaId: 'media-1',
          preview: const AsyncValue.data((
            videoId: 'vid-1',
            thumbnailUrl: null,
          )),
          engine: fake,
        );

        expect(find.byType(YoutubeLoadingVideoStage), findsOneWidget);
        expect(find.byType(AspectRatio), findsOneWidget);

        final aspectRatio = tester.widget<AspectRatio>(
          find.byType(AspectRatio),
        );
        expect(aspectRatio.aspectRatio, closeTo(16 / 9, 1e-6));

        expect(find.byType(PlayerSurfaceTarget), findsOneWidget);
        expect(find.byType(Stack), findsWidgets);

        // The Stack children include a ColoredBox (black backdrop).
        expect(find.byType(ColoredBox), findsWidgets);
      },
    );

    testWidgets('forwards the thumbnail url to YoutubeVideoPoster', (
      tester,
    ) async {
      await pumpStage(
        tester,
        mediaId: 'media-1',
        preview: const AsyncValue.data((
          videoId: 'vid-1',
          thumbnailUrl: 'https://example.com/thumb.jpg',
        )),
        engine: fake,
      );

      expect(find.byType(YoutubeVideoPoster), findsOneWidget);
      final poster = tester.widget<YoutubeVideoPoster>(
        find.byType(YoutubeVideoPoster),
      );
      expect(poster.primaryUrl, 'https://example.com/thumb.jpg');
      expect(poster.visible, isTrue);
    });

    testWidgets(
      'passes null to YoutubeVideoPoster when preview has no thumbnail',
      (tester) async {
        await pumpStage(
          tester,
          mediaId: 'media-1',
          preview: const AsyncValue.data((
            videoId: 'vid-1',
            thumbnailUrl: null,
          )),
          engine: fake,
        );

        expect(find.byType(YoutubeVideoPoster), findsOneWidget);
        final poster = tester.widget<YoutubeVideoPoster>(
          find.byType(YoutubeVideoPoster),
        );
        expect(poster.primaryUrl, isNull);
      },
    );

    testWidgets(
      'passes null to YoutubeVideoPoster while the preview future is loading',
      (tester) async {
        await pumpStage(
          tester,
          mediaId: 'media-1',
          preview: const AsyncValue.loading(),
          engine: fake,
        );

        // Even while loading, a poster widget is rendered (with primaryUrl=null).
        expect(find.byType(YoutubeVideoPoster), findsOneWidget);
        final poster = tester.widget<YoutubeVideoPoster>(
          find.byType(YoutubeVideoPoster),
        );
        expect(poster.primaryUrl, isNull);
      },
    );

    testWidgets(
      'passes null to YoutubeVideoPoster when the preview future errors',
      (tester) async {
        await pumpStage(
          tester,
          mediaId: 'media-1',
          preview: AsyncValue.error(Exception('boom'), StackTrace.current),
          engine: fake,
        );

        expect(find.byType(YoutubeVideoPoster), findsOneWidget);
        final poster = tester.widget<YoutubeVideoPoster>(
          find.byType(YoutubeVideoPoster),
        );
        expect(poster.primaryUrl, isNull);
      },
    );

    testWidgets(
      'falls back to disabled PlayerSurfaceTarget when engine is non-YouTube',
      (tester) async {
        await pumpStage(
          tester,
          mediaId: 'media-1',
          preview: const AsyncValue.data((
            videoId: 'vid-1',
            thumbnailUrl: null,
          )),
          engine: fake,
        );

        final target = tester.widget<PlayerSurfaceTarget>(
          find.byType(PlayerSurfaceTarget),
        );
        // showSurface = (yt != null && yt.shouldMountWebView) is false for the
        // non-YouTube fake engine, so the target reports `enabled=false`.
        expect(target.enabled, isFalse);
      },
    );

    testWidgets(
      'passes PlayerSurfaceOverlayBuilder through to the PlayerSurfaceTarget',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              youtubeOpenPreviewProvider('media-1').overrideWith(
                (ref) async => (videoId: 'vid-1', thumbnailUrl: null),
              ),
              playerEngineTestDoubleProvider.overrideWithValue(fake),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  height: 180,
                  child: YoutubeLoadingVideoStage(
                    mediaId: 'media-1',
                    overlayBuilder: (context) =>
                        const ColoredBox(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final target = tester.widget<PlayerSurfaceTarget>(
          find.byType(PlayerSurfaceTarget),
        );
        expect(target.overlayBuilder, isNotNull);
      },
    );
  });
}
