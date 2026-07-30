import 'package:enjoy_player/features/player/application/engines/youtube/youtube_player_engine.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_events.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YoutubePlayerEngine mount lifecycle', () {
    test(
      'ensureWebViewAttached sets shouldMountWebView without duplicate hosts',
      () async {
        final engine = YoutubePlayerEngine();
        expect(engine.shouldMountWebView, isFalse);
        expect(engine.webViewMounted, isFalse);

        engine.ensureWebViewAttached();
        expect(engine.shouldMountWebView, isTrue);
        expect(engine.webViewMounted, isFalse);

        await engine.idleAfterClear();
        expect(engine.shouldMountWebView, isFalse);
        expect(engine.currentVideoId, isEmpty);
      },
    );

    test('ensureWebViewAttached is idempotent for mountTick', () {
      final engine = YoutubePlayerEngine();
      engine.ensureWebViewAttached();
      final tickAfterFirst = engine.mountTick.value;
      engine.ensureWebViewAttached();
      engine.ensureWebViewAttached();
      expect(engine.mountTick.value, tickAfterFirst);
      expect(engine.shouldMountWebView, isTrue);
    });

    test('open requests mount and sets video id', () async {
      final engine = YoutubePlayerEngine();
      await engine.open(const YoutubePlayableSource('abc12345678'));
      expect(engine.currentVideoId, 'abc12345678');
      expect(engine.shouldMountWebView, isTrue);
    });

    test('practice clear idles content but keeps WebView mounted', () async {
      final engine = YoutubePlayerEngine();
      await engine.open(const YoutubePlayableSource('abc12345678'));

      await engine.idleAfterClear(keepMounted: true);

      expect(engine.currentVideoId, isEmpty);
      expect(engine.shouldMountWebView, isTrue);
    });

    test(
      'warmVideoSurface only requests mount (no redundant idle navigation)',
      () {
        final engine = YoutubePlayerEngine();
        engine.warmVideoSurface();
        expect(engine.shouldMountWebView, isTrue);
        expect(engine.currentVideoId, isEmpty);
      },
    );
  });

  group('YoutubeWebViewEvents playback state', () {
    test('does not report playing from the optimistic play event', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var firstPlayingCalls = 0;
      var pollStartCalls = 0;
      var volumeRestoreCalls = 0;
      final events = YoutubeWebViewEvents(
        session: session,
        webController: () => null,
        onFirstPlaying: () => firstPlayingCalls++,
        startPolling: () => pollStartCalls++,
        stopPolling: () {},
        reapplyVolume: () async {
          volumeRestoreCalls++;
        },
        seekTo: (_) async {},
        volumeRestoreDelay: YoutubeWebViewEvents.windowsVolumeRestoreDelay,
      );

      events.handle(['play']);

      expect(session.playing, isFalse);
      expect(firstPlayingCalls, 0);
      expect(pollStartCalls, 0);
      expect(volumeRestoreCalls, 0);

      events.handle(['playing']);

      expect(session.playing, isTrue);
      expect(firstPlayingCalls, 1);
      expect(pollStartCalls, 1);
      expect(volumeRestoreCalls, 0);

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });

    test('restores volume after confirmed playback settles', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var volumeRestoreCalls = 0;
      final events = YoutubeWebViewEvents(
        session: session,
        webController: () => null,
        onFirstPlaying: () {},
        startPolling: () {},
        stopPolling: () {},
        reapplyVolume: () async {
          volumeRestoreCalls++;
        },
        seekTo: (_) async {},
        volumeRestoreDelay: YoutubeWebViewEvents.windowsVolumeRestoreDelay,
      );

      events.handle(['playing']);
      await Future<void>.delayed(
        YoutubeWebViewEvents.windowsVolumeRestoreDelay +
            const Duration(milliseconds: 50),
      );

      expect(volumeRestoreCalls, 1);

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });

    test('restores volume immediately on later playing events', () async {
      final session = YoutubeSession()
        ..resetForOpen('abc12345678')
        ..loggedFirstPlaying = true;
      var volumeRestoreCalls = 0;
      final events = YoutubeWebViewEvents(
        session: session,
        webController: () => null,
        onFirstPlaying: () {},
        startPolling: () {},
        stopPolling: () {},
        reapplyVolume: () async {
          volumeRestoreCalls++;
        },
        seekTo: (_) async {},
        volumeRestoreDelay: YoutubeWebViewEvents.windowsVolumeRestoreDelay,
      );

      events.handle(['playing']);

      expect(volumeRestoreCalls, 1);

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });

    test('play rejection rolls back state and volume restore', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var volumeRestoreCalls = 0;
      final events = YoutubeWebViewEvents(
        session: session,
        webController: () => null,
        onFirstPlaying: () {},
        startPolling: () {},
        stopPolling: () {},
        reapplyVolume: () async {
          volumeRestoreCalls++;
        },
        seekTo: (_) async {},
        volumeRestoreDelay: YoutubeWebViewEvents.windowsVolumeRestoreDelay,
      );

      events.handle(['playing']);
      events.handle(['playRejected', 'NotAllowedError']);
      await Future<void>.delayed(
        YoutubeWebViewEvents.windowsVolumeRestoreDelay +
            const Duration(milliseconds: 50),
      );

      expect(session.playing, isFalse);
      expect(volumeRestoreCalls, 0);

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });

    test('pause cancels the delayed volume restore', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var volumeRestoreCalls = 0;
      final events = YoutubeWebViewEvents(
        session: session,
        webController: () => null,
        onFirstPlaying: () {},
        startPolling: () {},
        stopPolling: () {},
        reapplyVolume: () async {
          volumeRestoreCalls++;
        },
        seekTo: (_) async {},
        volumeRestoreDelay: YoutubeWebViewEvents.windowsVolumeRestoreDelay,
      );

      events.handle(['playing']);
      events.handle(['pause']);
      await Future<void>.delayed(
        YoutubeWebViewEvents.windowsVolumeRestoreDelay +
            const Duration(milliseconds: 50),
      );

      expect(volumeRestoreCalls, 0);

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });
  });
}
