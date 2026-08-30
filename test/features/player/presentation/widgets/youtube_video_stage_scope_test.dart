// Issue #663 (rebuild scope, item A): the YouTube stage root must not rebuild
// on buffering flips.
//
// A `StreamBuilder<bool>` used to sit at the stage root, so every
// `waiting` → `playing` flip re-created the whole [Stack] — including the
// [YoutubeWebViewHost] subtree and a fresh `InAppWebViewSettings` object. The
// buffering stream now lives in a leaf above the host; the assertions below
// read widget-instance identity, so they are structural, not timed
// (docs/perf-measurement.md).
import 'package:flutter/foundation.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_player_engine.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_bridge.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_video_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The stage root [Stack] — the outermost of the two (root + buffering leaf).
/// It is not const, so its widget instance is replaced only when the stage
/// root itself rebuilds.
Stack _stageRootStack(WidgetTester tester) =>
    tester.widgetList<Stack>(find.byType(Stack)).first;

void main() {
  testWidgets('a buffering flip leaves the stage root subtree untouched', (
    tester,
  ) async {
    // No InAppWebView backend in a unit test, so the session never mounts the
    // host — the transport latches are driven directly instead (mirrors the
    // issue #662 stage tests).
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final session = YoutubeSession()..resetForOpen('abc12345678');
    final engine = YoutubePlayerEngine(session: session);
    try {
      engine.setPosterUrl('https://example.com/thumb.jpg');

      // Past the poster's 220 ms fade-out, plus one frame for the poster's
      // `onEnd` setState to actually drop it from the tree.
      Future<void> settle() async {
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
      }

      // Mounts the stage once. Re-pumping would rebuild the root through the
      // test harness itself, which is exactly what must NOT happen per flip.
      Future<void> mount() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: YoutubeVideoStage(
                engine: engine,
                maxWidth: 320,
                maxHeight: 180,
              ),
            ),
          ),
        );
        await settle();
      }

      await mount();

      // Start playback, so a stall is signalled by the spinner (issue #662)
      // rather than by the poster. The buffering → playing transition is what
      // bumps [YoutubeSession.mountTick], so the root legitimately rebuilds
      // here; the stage root is captured after it.
      session.notePlayingConfirmed();
      session.markFirstPlayingLogged();
      session.emitBuffering(false);
      await settle();
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final stageRootBefore = _stageRootStack(tester);

      // Mid-playback stall: the spinner appears…
      session.emitBuffering(true);
      await settle();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        _stageRootStack(tester),
        same(stageRootBefore),
        reason:
            'A buffering flip must not rebuild the stage root (issue #663 A)',
      );

      // …and the recovery flip behaves the same way.
      session.emitBuffering(false);
      await settle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        _stageRootStack(tester),
        same(stageRootBefore),
        reason:
            'A buffering flip must not rebuild the stage root (issue #663 A)',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    await engine.dispose();
  });

  test('player WebView settings are a cached instance', () {
    // The host hands [InAppWebView] the same object on every stage rebuild, so
    // a settings push per rebuild is pointless work (issue #663).
    expect(
      identical(
        YoutubeWebViewSettings.forPlayer(),
        YoutubeWebViewSettings.forPlayer(),
      ),
      isTrue,
    );
  });
}
