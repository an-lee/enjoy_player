import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Transition-rule coverage for the encapsulated [YoutubeSession] latches
/// (issue #627). No WebView, no poll loop — the verbs are the test surface.
void main() {
  group('user-play in-flight invariant', () {
    // The invariant the field's doc comment states: an explicit user play
    // resolves on ANY of these transitions. Previously hand-enforced at 8
    // call sites across five modules; now asserted once, here.
    test('every resolving transition clears the in-flight latch', () {
      final resolvers = <String, void Function(YoutubeSession)>{
        'playing confirmed': (s) => s.notePlayingConfirmed(),
        'play rejected': (s) => s.noteUserPlayUnresolved(),
        'element error': (s) => s.noteUserPlayUnresolved(),
        'ended': (s) => s.noteEnded(),
        'reset for open': (s) => s.resetForOpen('next1234567'),
        'reset for clear': (s) => s.resetForClear(),
      };
      for (final entry in resolvers.entries) {
        final session = YoutubeSession()..resetForOpen('abc12345678');
        session.beginUserPlay();
        expect(session.userPlayInFlight, isTrue, reason: 'seed: ${entry.key}');
        entry.value(session);
        expect(
          session.userPlayInFlight,
          isFalse,
          reason: '${entry.key} must resolve the in-flight play',
        );
      }
    });

    test('beginUserPlay clears stale buffering while not playing', () {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      expect(session.buffering, isTrue); // resetForOpen arms buffering.
      session.beginUserPlay();
      expect(session.userPlayInFlight, isTrue);
      expect(session.buffering, isFalse);
    });

    test('clearUserPlayInFlight consumes the one-shot retry budget', () {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      session.beginUserPlay();
      session.clearUserPlayInFlight();
      expect(session.userPlayInFlight, isFalse);
    });
  });

  group('notePlayingConfirmed', () {
    test(
      'clears streak, completion latch, and in-flight; emits playing',
      () async {
        final session = YoutubeSession()..resetForOpen('abc12345678');
        session
          ..notePauseStreak(2)
          ..markCompleted()
          ..beginUserPlay();

        final playingEvents = <bool>[];
        final sub = session.playingStream.listen(playingEvents.add);
        addTearDown(sub.cancel);

        session.notePlayingConfirmed();
        await Future<void>.delayed(Duration.zero);

        expect(session.playing, isTrue);
        expect(session.pausedPollStreak, 0);
        expect(session.playbackCompleted, isFalse);
        expect(session.userPlayInFlight, isFalse);
        expect(playingEvents, [true]);
      },
    );
  });

  group('noteEnded', () {
    test('emits completed exactly once and clears transport latches', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      session
        ..emitPlaying(true)
        ..notePauseStreak(1)
        ..beginUserPlay();

      final completedEvents = <void>[];
      final sub = session.completed.listen(completedEvents.add);
      addTearDown(sub.cancel);

      session.noteEnded();
      session.noteEnded(); // idempotent
      await Future<void>.delayed(Duration.zero);

      expect(completedEvents, hasLength(1));
      expect(session.playbackCompleted, isTrue);
      expect(session.playing, isFalse);
      expect(session.buffering, isFalse);
      expect(session.userPlayInFlight, isFalse);
      expect(session.pausedPollStreak, 0);
    });

    test('notePlayingConfirmed after end re-arms the completion latch', () {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      session.noteEnded();
      expect(session.playbackCompleted, isTrue);
      session.notePlayingConfirmed();
      expect(session.playbackCompleted, isFalse);
    });

    test(
      'resetCompletionFlag lets markCompleted emit again (ADR-0044)',
      () async {
        final session = YoutubeSession()..resetForOpen('abc12345678');
        session.noteEnded();
        final completedEvents = <void>[];
        final sub = session.completed.listen(completedEvents.add);
        addTearDown(sub.cancel);

        session.resetCompletionFlag();
        session.noteEnded();
        await Future<void>.delayed(Duration.zero);
        expect(completedEvents, hasLength(1));
      },
    );
  });

  group('noteUserPlayUnresolved / notePauseConfirmed', () {
    test('unresolved settles as not playing, not buffering', () {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      session
        ..emitPlaying(true)
        ..beginUserPlay();
      session.noteUserPlayUnresolved();
      expect(session.playing, isFalse);
      expect(session.buffering, isFalse);
      expect(session.userPlayInFlight, isFalse);
    });

    test('pause confirmation resets the streak and stops transport', () {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      session
        ..emitPlaying(true)
        ..notePauseStreak(3);
      session.notePauseConfirmed();
      expect(session.pausedPollStreak, 0);
      expect(session.playing, isFalse);
      expect(session.buffering, isFalse);
    });
  });

  group('watch-page expectations', () {
    test(
      'noteWatchPageLoaded records the stop and clears recovery latches',
      () {
        final session = YoutubeSession()..resetForOpen('abc12345678');
        session
          ..noteAwaitingColdInitialNavigation()
          ..scheduleNonWatchRecovery();

        session.noteWatchPageLoaded();

        expect(session.watchPageLoadStopReceived, isTrue);
        expect(session.awaitingColdInitialNavigation, isFalse);
        expect(session.nonWatchRecoveryScheduled, isFalse);
      },
    );

    test(
      'resetWatchPageExpectations clears latches; firstPlaying optional',
      () {
        final session = YoutubeSession()
          ..resetForOpen('abc12345678')
          ..markFirstPlayingLogged()
          ..noteWatchPageLoaded();

        session.resetWatchPageExpectations(firstPlaying: false);
        expect(session.loggedFirstPlaying, isTrue);
        expect(session.watchPageLoadStopReceived, isFalse);

        session.resetWatchPageExpectations(firstPlaying: true);
        expect(session.loggedFirstPlaying, isFalse);
      },
    );

    test('clearAwaitingColdInitialNavigation leaves sibling latches alone', () {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      session
        ..noteAwaitingColdInitialNavigation()
        ..noteWatchPageLoaded()
        ..noteAwaitingColdInitialNavigation();

      session.clearAwaitingColdInitialNavigation();

      expect(session.awaitingColdInitialNavigation, isFalse);
      expect(session.watchPageLoadStopReceived, isTrue);
    });
  });

  group('pending seek + volume', () {
    test('takePendingSeekSeconds claims and clears', () {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      expect(session.takePendingSeekSeconds(), isNull);

      session.setPendingSeekSeconds(12.5);
      expect(session.takePendingSeekSeconds(), 12.5);
      expect(session.takePendingSeekSeconds(), isNull);
    });

    test('storeVolumeNormalized clamps into 0..1', () {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      expect(session.storeVolumeNormalized(1.7), 1.0);
      expect(session.storeVolumeNormalized(-0.3), 0.0);
      expect(session.storeVolumeNormalized(0.4), 0.4);
      expect(session.volumeNormalized, 0.4);
    });
  });

  group('mount state', () {
    test('mount tick notifies exactly once per mount request', () {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var ticks = 0;
      void onTick() => ticks++;
      session.mountTick.addListener(onTick);
      addTearDown(() => session.mountTick.removeListener(onTick));

      session.requestMount();
      final afterFirst = ticks;
      session.requestMount();
      expect(ticks, afterFirst);
      expect(session.shouldMountWebView, isTrue);

      session.noteWebViewMounted();
      expect(session.webViewMounted, isTrue);
      session.noteWebViewUnmounted();
      expect(session.webViewMounted, isFalse);
      expect(session.shouldMountWebView, isTrue); // unmount ≠ clear request
    });
  });
}
