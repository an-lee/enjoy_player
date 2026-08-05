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
    YoutubeWebViewEvents buildEvents(
      YoutubeSession session, {
      required void Function() onFirstPlaying,
      required void Function() startPolling,
      required void Function() stopPolling,
      required Future<void> Function() reapplyVolume,
      Duration? volumeRestoreDelay,
      Duration? volumeRestoreFallback,
    }) {
      return YoutubeWebViewEvents(
        session: session,
        webController: () => null,
        onFirstPlaying: onFirstPlaying,
        startPolling: startPolling,
        stopPolling: stopPolling,
        reapplyVolume: reapplyVolume,
        seekTo: (_) async {},
        volumeRestoreDelay:
            volumeRestoreDelay ??
            YoutubeWebViewEvents.windowsVolumeRestoreDelay,
        volumeRestoreFallback:
            volumeRestoreFallback ?? const Duration(seconds: 30),
      );
    }

    test('does not report playing from the optimistic play event', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var firstPlayingCalls = 0;
      var pollStartCalls = 0;
      var volumeRestoreCalls = 0;
      final events = buildEvents(
        session,
        onFirstPlaying: () => firstPlayingCalls++,
        startPolling: () => pollStartCalls++,
        stopPolling: () {},
        reapplyVolume: () async {
          volumeRestoreCalls++;
        },
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
      expect(session.volumeRestorePending, isTrue);

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });

    test('restores volume after playback progress settles', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var volumeRestoreCalls = 0;
      final events = buildEvents(
        session,
        onFirstPlaying: () {},
        startPolling: () {},
        stopPolling: () {},
        reapplyVolume: () async {
          volumeRestoreCalls++;
        },
        volumeRestoreDelay: Duration.zero,
      );

      events.handle(['playing']);
      expect(session.volumeRestorePending, isTrue);
      expect(volumeRestoreCalls, 0);

      // Need [progressConfirmTicks] advancing samples.
      events.onPlaybackProgress(const Duration(milliseconds: 100));
      expect(volumeRestoreCalls, 0);
      events.onPlaybackProgress(const Duration(milliseconds: 200));

      expect(volumeRestoreCalls, 1);
      expect(session.volumeRestorePending, isFalse);

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });

    test('restores volume via fallback when progress never arrives', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var volumeRestoreCalls = 0;
      final events = buildEvents(
        session,
        onFirstPlaying: () {},
        startPolling: () {},
        stopPolling: () {},
        reapplyVolume: () async {
          volumeRestoreCalls++;
        },
        volumeRestoreDelay: Duration.zero,
        volumeRestoreFallback: const Duration(milliseconds: 80),
      );

      events.handle(['playing']);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(volumeRestoreCalls, 1);

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });

    test('restores volume immediately on later playing events', () async {
      final session = YoutubeSession()
        ..resetForOpen('abc12345678')
        ..loggedFirstPlaying = true;
      var volumeRestoreCalls = 0;
      final events = buildEvents(
        session,
        onFirstPlaying: () {},
        startPolling: () {},
        stopPolling: () {},
        reapplyVolume: () async {
          volumeRestoreCalls++;
        },
      );

      events.handle(['playing']);

      expect(volumeRestoreCalls, 1);
      expect(session.volumeRestorePending, isFalse);

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });

    test('play rejection rolls back state and volume restore', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var volumeRestoreCalls = 0;
      var pollStartCalls = 0;
      final events = buildEvents(
        session,
        onFirstPlaying: () {},
        startPolling: () => pollStartCalls++,
        stopPolling: () {},
        reapplyVolume: () async {
          volumeRestoreCalls++;
        },
        volumeRestoreFallback: const Duration(milliseconds: 80),
      );

      events.handle(['playing']);
      session.emitBuffering(true);
      events.handle(['playRejected', 'NotAllowedError']);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(session.playing, isFalse);
      expect(session.buffering, isFalse);
      expect(volumeRestoreCalls, 0);
      expect(pollStartCalls, greaterThanOrEqualTo(1));

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });

    test(
      'pause cancels pending volume restore without resetting streak',
      () async {
        final session = YoutubeSession()..resetForOpen('abc12345678');
        var volumeRestoreCalls = 0;
        final events = buildEvents(
          session,
          onFirstPlaying: () {},
          startPolling: () {},
          stopPolling: () {},
          reapplyVolume: () async {
            volumeRestoreCalls++;
          },
          volumeRestoreFallback: const Duration(milliseconds: 80),
        );

        events.handle(['playing']);
        session.pausedPollStreak = 2;
        events.handle(['pause']);

        // Streak must survive so poll confirmation is not delayed.
        expect(session.pausedPollStreak, 2);
        expect(session.volumeRestorePending, isFalse);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(volumeRestoreCalls, 0);

        events.cancelPendingVolumeRestore();
        await session.closeStreams();
      },
    );

    test('pause does not clear session.playing (poll confirms)', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      final events = buildEvents(
        session,
        onFirstPlaying: () {},
        startPolling: () {},
        stopPolling: () {},
        reapplyVolume: () async {},
      );

      events.handle(['playing']);
      events.handle(['pause']);
      expect(session.playing, isTrue);

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });

    test('error clears playing and buffering', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      final events = buildEvents(
        session,
        onFirstPlaying: () {},
        startPolling: () {},
        stopPolling: () {},
        reapplyVolume: () async {},
      );

      events.handle(['playing']);
      session.emitBuffering(true);
      events.handle(['error']);

      expect(session.playing, isFalse);
      expect(session.buffering, isFalse);

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });
  });

  group('YoutubeSession volume restore progress', () {
    test('noteProgressForVolumeRestore requires consecutive advances', () {
      final session = YoutubeSession()..resetForOpen('vid');
      session.armVolumeRestorePending(baseline: Duration.zero);
      expect(session.noteProgressForVolumeRestore(Duration.zero), isFalse);
      expect(
        session.noteProgressForVolumeRestore(const Duration(milliseconds: 50)),
        isFalse,
      );
      expect(
        session.noteProgressForVolumeRestore(const Duration(milliseconds: 100)),
        isTrue,
      );
    });

    test('isImmediatePause is true within the window', () {
      final session = YoutubeSession()..resetForOpen('vid');
      session.emitPlaying(true);
      expect(session.isImmediatePause(DateTime.now()), isTrue);
      expect(
        session.isImmediatePause(
          DateTime.now().add(const Duration(seconds: 5)),
        ),
        isFalse,
      );
    });

    test('emitBuffering false then true then false bumps mountTick once', () {
      final session = YoutubeSession()..resetForOpen('vid');
      final tickAfterOpen = session.mountTick.value;
      // resetForOpen already emitted buffering=true.
      session.emitBuffering(false);
      final tickAfterFirstOff = session.mountTick.value;
      expect(tickAfterFirstOff, greaterThan(tickAfterOpen));
      session.emitBuffering(true);
      session.emitBuffering(false);
      expect(session.mountTick.value, tickAfterFirstOff);
    });
  });
}
