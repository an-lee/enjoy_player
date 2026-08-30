import 'dart:async';

import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_poll_loop.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _ResultFn =
    void Function({
      required Duration position,
      Duration? newDuration,
      required bool jsPaused,
      required bool jsEnded,
    });

class _FakePollDriver {
  _ResultFn? latest;
  int calls = 0;

  Future<void> poll({
    required bool disposed,
    required InAppWebViewController? web,
    required void Function({
      required Duration position,
      Duration? newDuration,
      required bool jsPaused,
      required bool jsEnded,
    })
    onResult,
  }) async {
    calls++;
    latest = onResult;
  }

  void emit({
    Duration position = Duration.zero,
    Duration? newDuration,
    required bool jsPaused,
    bool jsEnded = false,
  }) {
    latest?.call(
      position: position,
      newDuration: newDuration,
      jsPaused: jsPaused,
      jsEnded: jsEnded,
    );
  }
}

void main() {
  group('YoutubeWebViewPollLoop', () {
    late YoutubeSession session;

    setUp(() {
      session = YoutubeSession();
    });

    tearDown(() async {
      await session.closeStreams();
    });

    test('scheduleKick defers start by ~500ms (timer cancellation)', () async {
      var firstPlayingCalls = 0;
      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () => firstPlayingCalls++,
      );

      loop.scheduleKick();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(firstPlayingCalls, 0);

      loop.stop();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(firstPlayingCalls, 0);
    });

    test('start() is idempotent: second call does not double the timer', () {
      var firstPlayingCalls = 0;
      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () => firstPlayingCalls++,
      );

      loop.start();
      loop.start();
      loop.stop();
      expect(firstPlayingCalls, 0);
    });

    test('stop() is safe to call without start()', () {
      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () {},
      );
      loop.stop();
      loop.stop();
    });

    test('scheduleKick then stop cancels the pending kick', () async {
      var firstPlayingCalls = 0;
      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () => firstPlayingCalls++,
      );

      loop.scheduleKick();
      loop.stop();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(firstPlayingCalls, 0);
    });

    test(
      'media end stops polling and surfaces completion (ADR-0044)',
      () async {
        // Repeat policy is NOT decided here — the transport's CompletionLoop is
        // the single consumer of `completed`.
        final driver = _FakePollDriver();
        final completedEvents = <void>[];
        final sub = session.completed.listen(completedEvents.add);
        session.emitPlaying(true);

        final loop = YoutubeWebViewPollLoop(
          session: session,
          webController: () => null,
          onFirstPlaying: () {},
          pollFn: driver.poll,
        );

        loop.start();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        driver.emit(
          position: const Duration(seconds: 60),
          jsPaused: true,
          jsEnded: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(session.playbackCompleted, isTrue);
        expect(completedEvents, hasLength(1));
        expect(session.playing, isFalse);
        expect(session.buffering, isFalse);
        expect(loop.isRunning, isFalse);

        await sub.cancel();
        loop.stop();
      },
    );

    test('does not start the poll timer when session is disposed', () async {
      var firstPlayingCalls = 0;
      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () => firstPlayingCalls++,
      );

      unawaited(session.closeStreams());
      loop.start();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(firstPlayingCalls, 0);
      loop.stop();
    });

    test('resets pausedPollStreak to 0 on start()', () {
      session.notePauseStreak(5);
      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () {},
      );

      loop.start();
      expect(session.pausedPollStreak, 0);
      loop.stop();
    });

    test('confirms pause after streak and keeps polling', () async {
      final driver = _FakePollDriver();
      session.emitPlaying(true);
      session.markExplicitPlayAttempt();

      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () {},
        pollFn: driver.poll,
      );

      loop.start();
      // Wait for at least one periodic tick to capture [latest].
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(driver.latest, isNotNull);

      for (var i = 0; i < YoutubeSession.pauseConfirmPollTicks; i++) {
        driver.emit(position: Duration(milliseconds: i * 10), jsPaused: true);
      }

      expect(session.playing, isFalse);
      expect(session.buffering, isFalse);
      expect(loop.isRunning, isTrue);

      loop.stop();
    });

    test('PollPlaying clears buffering and reports first playing', () async {
      final driver = _FakePollDriver();
      var firstPlaying = 0;
      session.emitBuffering(true);

      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () => firstPlaying++,
        pollFn: driver.poll,
      );

      loop.start();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      driver.emit(position: const Duration(milliseconds: 250), jsPaused: false);

      expect(session.playing, isTrue);
      expect(session.buffering, isFalse);
      expect(firstPlaying, 1);

      loop.stop();
    });

    test('forwards progress while playing for volume restore', () async {
      final driver = _FakePollDriver();
      final progress = <Duration>[];

      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () {},
        onPlaybackProgress: progress.add,
        pollFn: driver.poll,
      );

      loop.start();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      driver.emit(position: const Duration(milliseconds: 100), jsPaused: false);
      driver.emit(position: const Duration(milliseconds: 200), jsPaused: true);

      expect(progress, [const Duration(milliseconds: 100)]);

      loop.stop();
    });

    test(
      'play → playing → page pauses again: retries once (production order)',
      () async {
        // Regression (PR #620 follow-up): the page player state machine can
        // correct a freshly started video back to paused. This is the exact
        // field sequence — beginUserPlay, playing resolves the command, THEN
        // the pause confirms — and the retry must still fire. Seeding
        // emitPlaying(true) after beginUserPlay() hid the bug: production can
        // only reach playing via notePlayingConfirmed, which used to consume
        // the budget ~750 ms before the pause could confirm.
        final driver = _FakePollDriver();
        var retryCalls = 0;
        session.beginUserPlay();
        session.notePlayingConfirmed();

        final loop = YoutubeWebViewPollLoop(
          session: session,
          webController: () => null,
          onFirstPlaying: () {},
          pollFn: driver.poll,
          retryPlay: (_) async => retryCalls++,
        );

        loop.start();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        // Position magnitude is irrelevant — the immediate-pause decision is
        // wall-clock from the playing transition; simple increasing ticks.
        for (var i = 0; i < YoutubeSession.pauseConfirmPollTicks; i++) {
          driver.emit(position: Duration(milliseconds: i * 10), jsPaused: true);
        }

        expect(retryCalls, 1);
        expect(session.userPlayInFlight, isFalse);
        expect(session.playing, isFalse);

        loop.stop();
      },
    );

    test(
      'deliberate user pause within the immediate window is not retried',
      () async {
        // The inverse defect: a pause-intent command (toggle while playing)
        // must consume the budget, or the retry un-pauses a video the user
        // just paused.
        final driver = _FakePollDriver();
        var retryCalls = 0;
        session.beginUserPlay();
        session.notePlayingConfirmed();
        session.noteUserPauseCommand();

        final loop = YoutubeWebViewPollLoop(
          session: session,
          webController: () => null,
          onFirstPlaying: () {},
          pollFn: driver.poll,
          retryPlay: (_) async => retryCalls++,
        );

        loop.start();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        for (var i = 0; i < YoutubeSession.pauseConfirmPollTicks; i++) {
          driver.emit(position: Duration(milliseconds: i * 10), jsPaused: true);
        }

        expect(retryCalls, 0);
        expect(session.playing, isFalse);

        loop.stop();
      },
    );

    test('second immediate pause is not retried (one-shot budget)', () async {
      final driver = _FakePollDriver();
      var retryCalls = 0;
      session.beginUserPlay();
      session.notePlayingConfirmed();

      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () {},
        pollFn: driver.poll,
        retryPlay: (_) async => retryCalls++,
      );

      loop.start();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      for (var round = 0; round < 2; round++) {
        for (var i = 0; i < YoutubeSession.pauseConfirmPollTicks; i++) {
          driver.emit(
            position: Duration(milliseconds: round * 100 + i * 10),
            jsPaused: true,
          );
        }
      }

      expect(retryCalls, 1);
      expect(session.playing, isFalse);

      loop.stop();
    });

    test(
      'echo wedge: escalation retries the retried episode, capped',
      () async {
        // Field sequence (Android, echo mode): the user-commanded play dies
        // immediately (retry #1), the RETRIED play dies immediately too —
        // the old one-shot budget wedged here. Escalation grants retry #2
        // because the dying episode was our own, then surfaces at the cap.
        final driver = _FakePollDriver();
        var retryCalls = 0;
        session.beginUserPlay();
        session.notePlayingConfirmed();

        final loop = YoutubeWebViewPollLoop(
          session: session,
          webController: () => null,
          onFirstPlaying: () {},
          pollFn: driver.poll,
          retryPlay: (_) async => retryCalls++,
        );

        loop.start();
        await Future<void>.delayed(const Duration(milliseconds: 300));

        void confirmPause() {
          for (var i = 0; i < YoutubeSession.pauseConfirmPollTicks; i++) {
            driver.emit(
              position: Duration(milliseconds: i * 10),
              jsPaused: true,
            );
          }
        }

        // Episode 1 (user command) dies → retry #1.
        confirmPause();
        expect(retryCalls, 1);
        // Retry #1's play resolves to playing (attribution consumed).
        session.notePlayingConfirmed();
        // Episode 2 (auto-retry) dies → escalation retry #2.
        confirmPause();
        expect(retryCalls, 2);
        // Retry #2's play resolves to playing.
        session.notePlayingConfirmed();
        // Episode 3 dies at the cap → surfaced, no third retry.
        confirmPause();
        expect(retryCalls, 2);

        loop.stop();
      },
    );

    test('deliberate pause command stops the escalation chain', () async {
      // A user pausing while an escalation chain is live must not be
      // un-paused: the pause-intent command drops the attribution.
      final driver = _FakePollDriver();
      var retryCalls = 0;
      session.beginUserPlay();
      session.notePlayingConfirmed();

      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () {},
        pollFn: driver.poll,
        retryPlay: (_) async => retryCalls++,
      );

      loop.start();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      for (var i = 0; i < YoutubeSession.pauseConfirmPollTicks; i++) {
        driver.emit(position: Duration(milliseconds: i * 10), jsPaused: true);
      }
      expect(retryCalls, 1);
      session.notePlayingConfirmed(); // retry #1 produced playing
      session.noteUserPauseCommand(); // …but the user just chose pause

      for (var i = 0; i < YoutubeSession.pauseConfirmPollTicks; i++) {
        driver.emit(position: Duration(milliseconds: i * 10), jsPaused: true);
      }
      expect(retryCalls, 1);

      loop.stop();
    });

    test(
      'failed retry surfaces a warning instead of an unhandled rejection',
      () async {
        // The one-shot budget is spent before retryPlay runs; a rejected
        // evaluateJavascript (e.g. renderer gone) must not escape as a
        // context-free zone error.
        final driver = _FakePollDriver();
        session.beginUserPlay();
        session.notePlayingConfirmed();

        final loop = YoutubeWebViewPollLoop(
          session: session,
          webController: () => null,
          onFirstPlaying: () {},
          pollFn: driver.poll,
          retryPlay: (_) async => throw StateError('renderer gone'),
        );

        loop.start();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        for (var i = 0; i < YoutubeSession.pauseConfirmPollTicks; i++) {
          driver.emit(position: Duration(milliseconds: i * 10), jsPaused: true);
        }
        // Give the rejected future a microtask turn to prove it is caught.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(session.playing, isFalse);
        expect(session.lastAutoPlayRetryAt, isNotNull);

        loop.stop();
      },
    );

    test('budget expires once playback outlives the attempt window', () async {
      // A page-UI resume the app never commanded refreshes the playing
      // clock without arming a new budget; a pause confirmed long after
      // the budget's episode must not spend it — even when the pause is
      // "immediate" relative to the resume. Injectable expiry keeps this
      // deterministic instead of sleeping past the real 2 s window.
      final fastSession = YoutubeSession(
        playAttemptExpiry: const Duration(milliseconds: 200),
      )..resetForOpen('abc12345678');
      addTearDown(fastSession.closeStreams);
      final driver = _FakePollDriver();
      var retryCalls = 0;
      fastSession.beginUserPlay();
      fastSession.notePlayingConfirmed();

      final loop = YoutubeWebViewPollLoop(
        session: fastSession,
        webController: () => null,
        onFirstPlaying: () {},
        pollFn: driver.poll,
        retryPlay: (_) async => retryCalls++,
      );

      loop.start();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(fastSession.userPlayInFlight, isFalse);

      // A later playing episode (page-UI resume: no beginUserPlay) inside
      // the 2 s immediate window, then a quick pause — the stale budget
      // must not be spent.
      fastSession.emitPlaying(false);
      fastSession.notePlayingConfirmed();
      for (var i = 0; i < YoutubeSession.pauseConfirmPollTicks; i++) {
        driver.emit(position: Duration(milliseconds: i * 10), jsPaused: true);
      }
      expect(retryCalls, 0);

      loop.stop();
    });

    test(
      'immediate pause without in-flight user play does not retry',
      () async {
        final driver = _FakePollDriver();
        var retryCalls = 0;
        session.emitPlaying(true);

        final loop = YoutubeWebViewPollLoop(
          session: session,
          webController: () => null,
          onFirstPlaying: () {},
          pollFn: driver.poll,
          retryPlay: (_) async => retryCalls++,
        );

        loop.start();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        for (var i = 0; i < YoutubeSession.pauseConfirmPollTicks; i++) {
          driver.emit(position: Duration(milliseconds: i * 10), jsPaused: true);
        }

        expect(retryCalls, 0);

        loop.stop();
      },
    );
  });
}
