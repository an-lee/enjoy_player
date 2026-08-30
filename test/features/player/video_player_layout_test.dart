import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_state_providers.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/presentation/layouts/video_player_layout.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_frosted_back_button.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_surface_host.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_surface_target.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_login_video_frame_button.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_player_engine.dart';

class _SessionPlayerController extends PlayerController {
  _SessionPlayerController(this._session);

  final PlaybackSession _session;

  @override
  PlaybackSession? build() => _session;
}

PlaybackSession _testSession() {
  final now = DateTime(2026, 1, 1);
  return PlaybackSession(
    mediaId: 'video-layout-test',
    dexieTargetType: 'Video',
    mediaType: 'video',
    mediaTitle: 'Layout test',
    durationSeconds: 120,
    currentTimeSeconds: 0,
    currentSegmentIndex: 0,
    language: 'en',
    startedAt: now,
    lastActiveAt: now,
  );
}

void main() {
  Future<void> pumpLayout(
    WidgetTester tester, {
    required double width,
    required double height,
    FakePlayerEngine? engine,
    List<Override> overrides = const [],
  }) async {
    final fake = engine ?? FakePlayerEngine();
    if (engine == null) {
      addTearDown(() async {
        await fake.dispose();
      });
    }
    // Ensure the test surface can host tall portrait fixtures (aspect layout).
    final view = tester.view;
    view.physicalSize = Size(width * 3, height * 3);
    view.devicePixelRatio = 3;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerEngineTestDoubleProvider.overrideWithValue(fake),
          ...overrides,
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: scheme,
            extensions: [EnjoyThemeTokens.build(scheme)],
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: VideoPlayerLayout(
                      engine: fake,
                      transcript: const Text('TR_STUB'),
                    ),
                  ),
                ),
                // Overlay chrome (tap-to-toggle) lives on the permanent host.
                const PlayerSurfaceHost(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('VideoPlayerLayout shows transcript beside video in landscape', (
    tester,
  ) async {
    await pumpLayout(tester, width: 900, height: 600);
    expect(find.text('TR_STUB'), findsOneWidget);
    expect(find.byType(Row), findsWidgets);
  });

  testWidgets('VideoPlayerLayout stacks transcript in portrait', (
    tester,
  ) async {
    await pumpLayout(tester, width: 500, height: 700);
    expect(find.text('TR_STUB'), findsOneWidget);
    expect(find.byType(Column), findsWidgets);
  });

  testWidgets(
    'VideoPlayerLayout stacks in wide portrait (aspect, not 720 breakpoint)',
    (tester) async {
      await pumpLayout(tester, width: 800, height: 1000);
      final layout = find.byType(VideoPlayerLayout);
      expect(
        find.descendant(of: layout, matching: find.byType(AspectRatio)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: layout, matching: find.byType(Column)),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'VideoPlayerLayout uses side-by-side in landscape below former 720 width',
    (tester) async {
      await pumpLayout(tester, width: 700, height: 400);
      final layout = find.byType(VideoPlayerLayout);
      expect(
        find.descendant(of: layout, matching: find.byType(AspectRatio)),
        findsNothing,
      );
      expect(
        find.descendant(of: layout, matching: find.byType(Row)),
        findsWidgets,
      );
    },
  );

  testWidgets('VideoPlayerLayout stacks when square', (tester) async {
    await pumpLayout(tester, width: 600, height: 600);
    final layout = find.byType(VideoPlayerLayout);
    expect(
      find.descendant(of: layout, matching: find.byType(AspectRatio)),
      findsOneWidget,
    );
  });

  testWidgets(
    'layout and transcript survive landscape↔portrait without remount',
    (tester) async {
      final fake = FakePlayerEngine();
      addTearDown(() async {
        await fake.dispose();
      });
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
      final size = ValueNotifier(const Size(900, 600));
      final view = tester.view;
      view.physicalSize = const Size(1200 * 3, 1200 * 3);
      view.devicePixelRatio = 3;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [playerEngineTestDoubleProvider.overrideWithValue(fake)],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: scheme,
              extensions: [EnjoyThemeTokens.build(scheme)],
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder<Size>(
                valueListenable: size,
                builder: (context, s, _) {
                  return Center(
                    child: SizedBox(
                      width: s.width,
                      height: s.height,
                      child: VideoPlayerLayout(
                        engine: fake,
                        transcript: const Text('TR_STUB'),
                        initialTranscriptSplitWidthPx: 420,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final stateBefore = tester.state(find.byType(VideoPlayerLayout));
      expect(find.byType(Row), findsWidgets);

      size.value = const Size(800, 1000);
      await tester.pump();
      expect(find.byType(Column), findsWidgets);
      expect(find.text('TR_STUB'), findsOneWidget);
      expect(
        identical(tester.state(find.byType(VideoPlayerLayout)), stateBefore),
        isTrue,
      );

      size.value = const Size(900, 600);
      await tester.pump();
      expect(find.byType(Row), findsWidgets);
      expect(find.text('TR_STUB'), findsOneWidget);
      expect(
        identical(tester.state(find.byType(VideoPlayerLayout)), stateBefore),
        isTrue,
      );
    },
  );

  testWidgets('tapping local video stage toggles play/pause', (tester) async {
    final fake = FakePlayerEngine();
    addTearDown(() async {
      await fake.dispose();
    });
    await pumpLayout(
      tester,
      width: 900,
      height: 600,
      engine: fake,
      overrides: [
        playerControllerProvider.overrideWith(
          () => _SessionPlayerController(_testSession()),
        ),
      ],
    );

    expect(fake.playOrPauseCallCount, 0);
    // Tap chrome lives on [PlayerSurfaceHost] over the registered target.
    await tester.tapAt(tester.getCenter(find.byType(PlayerSurfaceTarget)));
    await tester.pump();
    expect(fake.playOrPauseCallCount, 1);
  });

  testWidgets('video title chrome is painted by the surface host', (
    tester,
  ) async {
    await pumpLayout(
      tester,
      width: 900,
      height: 600,
      overrides: [
        playerControllerProvider.overrideWith(
          () => _SessionPlayerController(_testSession()),
        ),
      ],
    );

    final title = find.text('Layout test');
    expect(title, findsOneWidget);
    expect(
      find.ancestor(of: title, matching: find.byType(PlayerSurfaceHost)),
      findsOneWidget,
    );
  });

  testWidgets('back button stays visible while playing; title hides', (
    tester,
  ) async {
    await pumpLayout(
      tester,
      width: 900,
      height: 600,
      overrides: [
        playerControllerProvider.overrideWith(
          () => _SessionPlayerController(_testSession()),
        ),
        playerIsPlayingProvider.overrideWith((ref) => Stream.value(true)),
        playerIsBufferingProvider.overrideWith((ref) => Stream.value(false)),
      ],
    );

    expect(find.byType(PlayerFrostedBackButton), findsOneWidget);
    final titleOpacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('Layout test'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(titleOpacity.opacity, 0.0);
  });

  testWidgets('YouTube login chrome is absent for local video', (tester) async {
    await pumpLayout(tester, width: 900, height: 600);
    expect(find.byType(YoutubeLoginVideoFrameButton), findsNothing);
  });

  testWidgets(
    'YouTube login chrome sits bottom-right on the stage for YouTube video',
    (tester) async {
      final fake = FakePlayerEngine()..supportsYouTubePlaybackValue = true;
      addTearDown(() async {
        await fake.dispose();
      });
      await pumpLayout(tester, width: 500, height: 700, engine: fake);

      expect(find.byType(YoutubeLoginVideoFrameButton), findsOneWidget);
      final login = tester.getRect(find.byType(YoutubeLoginVideoFrameButton));
      final stage = tester.getRect(find.byType(PlayerSurfaceTarget).first);
      expect(login.bottom, closeTo(stage.bottom, 20));
      expect(login.right, closeTo(stage.right, 20));
      expect(find.byType(PlayerFrostedBackButton), findsOneWidget);
    },
  );

  testWidgets(
    'host overlay MouseRegion is pass-through so WebView can receive hits',
    (tester) async {
      await pumpLayout(tester, width: 900, height: 600);

      final hostRegions = find.descendant(
        of: find.byType(PlayerSurfaceHost),
        matching: find.byType(MouseRegion),
      );
      expect(hostRegions, findsWidgets);

      final passThrough = tester
          .widgetList<MouseRegion>(hostRegions)
          .where((r) => !r.opaque);
      expect(
        passThrough,
        isNotEmpty,
        reason:
            'Host chrome MouseRegion must use opaque: false so empty '
            'regions pass hits through to the YouTube WebView',
      );
    },
  );

  /// Mirrors [ExpandedPlayerChromeBody] narrow video layout: [VideoPlayerLayout]
  /// fills the stack; paused title chrome is an overlay and must not change the
  /// 16:9 stage geometry.
  testWidgets(
    'Stacked title overlay does not move 16:9 stage when shown (expanded player pattern)',
    (tester) async {
      final fake = FakePlayerEngine();
      addTearDown(() async {
        await fake.dispose();
      });
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
      final overlayVisible = ValueNotifier<bool>(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [playerEngineTestDoubleProvider.overrideWithValue(fake)],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: scheme,
              extensions: [EnjoyThemeTokens.build(scheme)],
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Center(
              child: SizedBox(
                width: 390,
                height: 844,
                child: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(390, 844),
                    padding: EdgeInsets.only(top: 47, bottom: 34),
                  ),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: overlayVisible,
                    builder: (context, showOverlay, _) {
                      return Scaffold(
                        body: Stack(
                          fit: StackFit.expand,
                          children: [
                            VideoPlayerLayout(
                              engine: fake,
                              transcript: const Text('TR_STUB'),
                            ),
                            if (showOverlay)
                              Align(
                                alignment: Alignment.topCenter,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.55),
                                        Colors.black.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                  child: const SafeArea(
                                    bottom: false,
                                    left: false,
                                    right: false,
                                    child: SizedBox(
                                      height: kToolbarHeight,
                                      child: Row(
                                        children: [
                                          SizedBox(width: 48, height: 48),
                                          Expanded(child: Text('Title')),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const PlayerSurfaceHost(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final layout = find.byType(VideoPlayerLayout);
      final aspectFinder = find.descendant(
        of: layout,
        matching: find.byType(AspectRatio),
      );
      expect(aspectFinder, findsOneWidget);
      final rectHidden = tester.getRect(aspectFinder);

      overlayVisible.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final rectShown = tester.getRect(aspectFinder);
      expect(rectShown, rectHidden);
    },
  );
}
