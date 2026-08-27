import 'package:enjoy_player/features/player/application/engines/youtube/youtube_player_engine.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_events.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YoutubePlayerEngine contract surface', () {
    test('open sets the video id and arms buffering transport', () async {
      final engine = YoutubePlayerEngine();
      await engine.open(const YoutubePlayableSource('abc12345678'));
      expect(engine.currentVideoId, 'abc12345678');
      expect(engine.transportSnapshot.buffering, isTrue);
      await engine.dispose();
    });

    test('teardownAfterClear idles the engine', () async {
      final engine = YoutubePlayerEngine();
      await engine.open(const YoutubePlayableSource('abc12345678'));

      await engine.teardownAfterClear(keepSurfaceMounted: false);

      expect(engine.currentVideoId, isEmpty);
      expect(engine.transportSnapshot.playing, isFalse);
      expect(engine.transportSnapshot.buffering, isFalse);
      await engine.dispose();
    });

    test('warmVideoSurface does not throw and keeps no video open', () {
      final engine = YoutubePlayerEngine();
      engine.warmVideoSurface();
      expect(engine.currentVideoId, isEmpty);
    });
  });

  group('YoutubeSession mount lifecycle', () {
    // The mount latches live on the session; the engine only forwards them
    // through warmVideoSurface / teardownAfterClear (issue #630).
    test('requestMount arms the mount without duplicate host ticks', () {
      final session = YoutubeSession();
      expect(session.shouldMountWebView, isFalse);
      expect(session.webViewMounted, isFalse);

      session.requestMount();
      final tickAfterFirst = session.mountTick.value;
      session.requestMount();
      session.requestMount();

      expect(session.shouldMountWebView, isTrue);
      expect(session.mountTick.value, tickAfterFirst);
      expect(session.webViewMounted, isFalse);
    });

    test('resetForClear unmounts unless asked to keep the host', () {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      session.requestMount();

      session.resetForClear();
      expect(session.shouldMountWebView, isFalse);
      expect(session.videoId, isEmpty);

      session.resetForOpen('abc12345678');
      session.requestMount();
      session.resetForClear(keepMounted: true);
      expect(session.shouldMountWebView, isTrue);
      expect(session.videoId, isEmpty);
    });
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
      Duration? postRestoreHealDelay,
      Future<void> Function(InAppWebViewController? web)? healPlay,
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
        postRestoreHealDelay: postRestoreHealDelay,
        healPlay: healPlay,
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

    test(
      'does not touch volume on later playing events in same document',
      () async {
        final session = YoutubeSession()
          ..resetForOpen('abc12345678')
          ..noteVolumeRestored();
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

        // Redundant programmatic unMutes are pause triggers under Chromium's
        // autoplay gesture lock (play-then-pause root cause): an already
        // restored document must skip the restore entirely.
        expect(volumeRestoreCalls, 0);
        expect(session.volumeRestorePending, isFalse);
        expect(session.volumeRestoredDocGen, session.documentGen);

        events.cancelPendingVolumeRestore();
        await session.closeStreams();
      },
    );

    test(
      're-arms restore for a fresh watch document (post-ad reload)',
      () async {
        final session = YoutubeSession()
          ..resetForOpen('abc12345678')
          ..noteVolumeRestored();
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

        // Ad reload lands a brand-new document whose <video> starts muted.
        session.noteWatchDocumentLoaded();
        events.handle(['playing']);
        expect(session.volumeRestorePending, isTrue);
        expect(volumeRestoreCalls, 0);

        // Progress gate still applies within the new document.
        events.onPlaybackProgress(const Duration(milliseconds: 100));
        events.onPlaybackProgress(const Duration(milliseconds: 200));
        expect(volumeRestoreCalls, 1);
        await Future<void>.delayed(Duration.zero);
        expect(session.volumeRestoredDocGen, session.documentGen);

        events.cancelPendingVolumeRestore();
        await session.closeStreams();
      },
    );

    test(
      'heals a pause that immediately followed the volume restore',
      () async {
        final session = YoutubeSession()..resetForOpen('abc12345678');
        var healCalls = 0;
        final events = buildEvents(
          session,
          onFirstPlaying: () {},
          startPolling: () {},
          stopPolling: () {},
          reapplyVolume: () async {},
          volumeRestoreDelay: Duration.zero,
          postRestoreHealDelay: const Duration(milliseconds: 20),
          healPlay: (_) async {
            healCalls++;
          },
        );

        events.handle(['playing']);
        events.onPlaybackProgress(const Duration(milliseconds: 100));
        events.onPlaybackProgress(const Duration(milliseconds: 200));

        // The unmute tripped the WebView's autoplay gesture lock and playback
        // stopped; simulate the poll loop's pause confirmation.
        await Future<void>.delayed(Duration.zero);
        session.emitPlaying(false);

        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(healCalls, 1);
        await session.closeStreams();
      },
    );

    test('no heal when playback survives the volume restore', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var healCalls = 0;
      final events = buildEvents(
        session,
        onFirstPlaying: () {},
        startPolling: () {},
        stopPolling: () {},
        reapplyVolume: () async {},
        volumeRestoreDelay: Duration.zero,
        postRestoreHealDelay: const Duration(milliseconds: 20),
        healPlay: (_) async {
          healCalls++;
        },
      );

      events.handle(['playing']);
      events.onPlaybackProgress(const Duration(milliseconds: 100));
      events.onPlaybackProgress(const Duration(milliseconds: 200));

      // Video kept playing after the unmute (the healthy case).
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(healCalls, 0);
      await session.closeStreams();
    });

    test('stale heal is skipped when a new document re-arms restore', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var healCalls = 0;
      final events = buildEvents(
        session,
        onFirstPlaying: () {},
        startPolling: () {},
        stopPolling: () {},
        reapplyVolume: () async {},
        volumeRestoreDelay: Duration.zero,
        postRestoreHealDelay: const Duration(milliseconds: 20),
        healPlay: (_) async {
          healCalls++;
        },
      );

      events.handle(['playing']);
      events.onPlaybackProgress(const Duration(milliseconds: 100));
      events.onPlaybackProgress(const Duration(milliseconds: 200));
      await Future<void>.delayed(Duration.zero);

      // Ad reload lands a new document before the heal fires.
      session.noteWatchDocumentLoaded();
      session.emitPlaying(false);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(healCalls, 0);
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

    test('playing and playRejected resolve an in-flight user play', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      final events = buildEvents(
        session,
        onFirstPlaying: () {},
        startPolling: () {},
        stopPolling: () {},
        reapplyVolume: () async {},
      );

      session.userPlayInFlight = true;
      events.handle(['playing']);
      expect(session.userPlayInFlight, isFalse);

      session.userPlayInFlight = true;
      events.handle(['playRejected', 'NotAllowedError']);
      expect(session.userPlayInFlight, isFalse);

      events.cancelPendingVolumeRestore();
      await session.closeStreams();
    });

    test('resetForOpen and resetForClear reset userPlayInFlight', () {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      session.userPlayInFlight = true;
      session.resetForOpen('other123456');
      expect(session.userPlayInFlight, isFalse);

      session.userPlayInFlight = true;
      session.resetForClear();
      expect(session.userPlayInFlight, isFalse);
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
