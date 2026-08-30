import 'dart:async';

import 'package:enjoy_player/features/player/application/engines/youtube/youtube_monotonic_clock.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_play_retry_policy.dart';
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

/// Poll double whose reads never resolve on their own: the test settles them
/// one at a time and chooses the ORDER. That order is exactly what the real
/// loop cannot control — a read that outlives a tick resolves after a later
/// one (issue #655).
class _GatedPollDriver {
  final List<_ResultFn> reads = [];
  final List<Completer<void>> _gates = [];

  Future<void> poll({
    required bool disposed,
    required InAppWebViewController? web,
    required _ResultFn onResult,
  }) async {
    reads.add(onResult);
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
  }

  /// Applies DOM [state] through the read issued at index [call] (issue
  /// order) and lets that poll future settle.
  void settle(
    int call, {
    Duration position = Duration.zero,
    Duration? newDuration,
    bool jsPaused = false,
    bool jsEnded = false,
  }) {
    reads[call](
      position: position,
      newDuration: newDuration,
      jsPaused: jsPaused,
      jsEnded: jsEnded,
    );
    _gates[call].complete();
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

    test('skips the tick while a poll is still in flight', () async {
      // Timer.periodic does not wait for the previous callback: a read that
      // outlives one pollTick (heavy page, the 300 ms inject interval, GC)
      // used to let the next tick start a second read, and the two resolved
      // in completion order rather than issue order. One read at a time is
      // the whole invariant (issue #655).
      final driver = _GatedPollDriver();
      var firstPlayingCalls = 0;
      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () => firstPlayingCalls++,
        pollFn: driver.poll,
      );

      loop.start();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      // One full extra period elapses while read #0 is still awaited.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        driver.reads,
        hasLength(1),
        reason: 'the overlapping tick must not issue a second read',
      );
      expect(firstPlayingCalls, 0);

      // Skipping the tick costs nothing: settling the one read still drives
      // the transport.
      driver.settle(0, position: const Duration(milliseconds: 250));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(session.playing, isTrue);
      expect(firstPlayingCalls, 1);

      loop.stop();
    });

    test('a late read cannot resurrect playing after end-of-media', () async {
      // Issue #655's worst case: the read issued first resolved LAST with a
      // stale s=1 and landed after the fresher read had reported ended —
      // notePlayingConfirmed() then cleared _playbackCompleted and re-emitted
      // playing=true on a video that was already over.
      final driver = _GatedPollDriver();
      var completedFired = false;
      var playingTrueAfterCompleted = 0;
      final completedSub = session.completed.listen((_) {
        completedFired = true;
      });
      final playingSub = session.playingStream.listen((v) {
        // The `playing=false` of the ended transition itself is delivered
        // after `completed` (both controllers deliver asynchronously); only a
        // later `true` is a resurrection.
        if (completedFired && v) playingTrueAfterCompleted++;
      });
      session.emitPlaying(true);

      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () {},
        pollFn: driver.poll,
      );

      loop.start();
      // Two full periods: read #0 is still awaited and the overlapping tick
      // has been skipped.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(
        driver.reads,
        hasLength(1),
        reason:
            'no second read may be issued — a second read is what let a '
            'stale snapshot apply after the end-of-media one',
      );

      // The DOM truth arrives through the only in-flight read: ended.
      driver.settle(
        0,
        position: const Duration(seconds: 60),
        jsPaused: true,
        jsEnded: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(session.playbackCompleted, isTrue);
      expect(session.playing, isFalse);
      // Nothing may follow the completion — above all no stale `playing`.
      expect(playingTrueAfterCompleted, 0);
      expect(loop.isRunning, isFalse);

      await completedSub.cancel();
      await playingSub.cancel();
      loop.stop();
    });

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
        // Retry #1's play resolves to playing (attribution latches)…
        session.notePlayingConfirmed();
        // …and the poll loop keeps re-confirming playing every tick while
        // the episode lives — those ticks must not erase the attribution
        // (round-5 field bug: they did, and retry #2 never fired).
        driver.emit(
          position: const Duration(milliseconds: 400),
          jsPaused: false,
        );
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
        // The protocol advanced before the throw: the budget was spent and
        // the retry counted against the escalation cap.
        expect(session.playRetry.autoRetriesIssued, 1);

        loop.stop();
      },
    );

    test('budget expires once playback outlives the attempt window', () async {
      // A page-UI resume the app never commanded refreshes the playing
      // clock without arming a new budget; a pause confirmed long after
      // the budget's episode must not spend it — even when the pause is
      // "immediate" relative to the resume. The retry protocol's
      // monotonic clock is injected, so the expiry is deterministic
      // instead of sleeping past the real 2 s window.
      final clock = FakeMonotonicClock();
      final fastSession = YoutubeSession(
        playRetry: YouTubePlayRetryPolicy(
          clock: clock,
          playAttemptExpiry: const Duration(milliseconds: 200),
        ),
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
      clock.advance(const Duration(milliseconds: 400));
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

    group('cadence (issue #662)', () {
      // `onFirstPlaying` is wired the way the controller wires it. That is
      // not cosmetic: without the first-playing latch the session's
      // recovery-hint timer would be armed on every pause confirmation and
      // would still be pending when the testWidgets zone is verified.
      YoutubeWebViewPollLoop buildLoop(_FakePollDriver driver) {
        return YoutubeWebViewPollLoop(
          session: session,
          webController: () => null,
          onFirstPlaying: session.markFirstPlayingLogged,
          pollFn: driver.poll,
        );
      }

      /// Advances fake time [window] in 50 ms steps and returns how many poll
      /// reads the loop issued. 50 ms < pollTick, so the step size can never
      /// skip a tick, and every cadence used here is a multiple of the step.
      Future<int> readsOver(
        WidgetTester tester,
        _FakePollDriver driver,
        Duration window,
      ) async {
        final start = driver.calls;
        var elapsed = Duration.zero;
        while (elapsed < window) {
          await tester.pump(const Duration(milliseconds: 50));
          await tester.idle();
          elapsed += const Duration(milliseconds: 50);
        }
        return driver.calls - start;
      }

      testWidgets('playing is sampled every pollTick', (tester) async {
        final driver = _FakePollDriver();
        final loop = buildLoop(driver);
        session.emitPlaying(true);

        loop.start();
        for (var i = 1; i <= 4; i++) {
          await tester.pump(loop.pollTick);
          await tester.idle();
          driver.emit(
            position: Duration(milliseconds: 250 * i),
            jsPaused: false,
          );
        }

        expect(driver.calls, 4, reason: 'one read per 250 ms while playing');
        expect(session.loggedFirstPlaying, isTrue);

        // The fake-async zone is verified for pending timers before the
        // tearDowns run, so the chain must be stopped inside the body.
        loop.stop();
      });

      testWidgets('a document that never played is NOT backed off', (
        tester,
      ) async {
        // Dart never believed this document was playing, so no pause is ever
        // confirmed (every paused read is a PollIdleTick). The loop must stay
        // fast: this is the document still waiting for its first metadata,
        // and the backoff may only follow a confirmed pause.
        final driver = _FakePollDriver();
        final loop = buildLoop(driver);

        loop.start();
        final reads = await readsOver(
          tester,
          driver,
          const Duration(seconds: 2),
        );
        driver.emit(position: Duration.zero, jsPaused: true);

        expect(reads, 8, reason: '250 ms cadence before any confirmed pause');
        expect(session.playing, isFalse);
        expect(session.loggedFirstPlaying, isFalse);

        loop.stop();
      });

      testWidgets(
        'a confirmed quiet pause backs off to ~1/s; a play intent restores '
        'the fast cadence immediately',
        (tester) async {
          final driver = _FakePollDriver();
          final loop = buildLoop(driver);
          const position = Duration(seconds: 30);
          session.emitPlaying(true);

          loop.start();
          // Playing: four full-cadence samples.
          for (var i = 1; i <= 4; i++) {
            await tester.pump(loop.pollTick);
            await tester.idle();
            driver.emit(
              position: Duration(milliseconds: 250 * i),
              jsPaused: false,
            );
          }
          // Then a pause confirming at a still position.
          for (var i = 0; i < YoutubeSession.pauseConfirmPollTicks; i++) {
            await tester.pump(loop.pollTick);
            await tester.idle();
            driver.emit(position: position, jsPaused: true);
          }
          expect(session.playing, isFalse);

          // The tick armed BEFORE the confirming read is still fast; consume
          // it so the measurement below starts on a backoff-armed boundary.
          await tester.pump(loop.pollTick);
          await tester.idle();

          expect(
            await readsOver(tester, driver, const Duration(seconds: 2)),
            2,
            reason: 'a confirmed quiet pause is sampled about once a second',
          );
          expect(
            await readsOver(tester, driver, const Duration(seconds: 2)),
            2,
            reason: 'the backoff holds while nothing changes',
          );

          // A play intent must not wait out the backed-off period.
          loop.start();
          expect(
            await readsOver(tester, driver, loop.pollTick),
            1,
            reason: 'start() re-arms at pollTick',
          );
          expect(
            await readsOver(tester, driver, const Duration(seconds: 1)),
            4,
            reason: 'the fast cadence is back',
          );

          loop.stop();
        },
      );

      testWidgets(
        'a seek while paused un-quiets the loop, then it re-settles',
        (tester) async {
          final driver = _FakePollDriver();
          final loop = buildLoop(driver);
          session.emitPlaying(true);

          loop.start();
          for (var i = 1; i <= 2; i++) {
            await tester.pump(loop.pollTick);
            await tester.idle();
            driver.emit(
              position: Duration(milliseconds: 250 * i),
              jsPaused: false,
            );
          }
          for (var i = 0; i < YoutubeSession.pauseConfirmPollTicks; i++) {
            await tester.pump(loop.pollTick);
            await tester.idle();
            driver.emit(position: const Duration(seconds: 30), jsPaused: true);
          }
          await tester.pump(loop.pollTick);
          await tester.idle();
          expect(
            await readsOver(tester, driver, const Duration(seconds: 1)),
            1,
            reason: 'precondition: backed off',
          );

          // The user seeks while paused. The tick armed before this delivery is
          // still backed off; the one after it runs at the fast cadence.
          driver.emit(position: const Duration(seconds: 45), jsPaused: true);
          expect(
            await readsOver(tester, driver, loop.pausedPollBackoff),
            1,
            reason: 'the arming predates the moved position',
          );
          expect(
            await readsOver(tester, driver, loop.pollTick),
            1,
            reason: 'a moving position is live state — pollTick cadence',
          );

          // The position settles again, and the loop backs off with it.
          driver.emit(position: const Duration(seconds: 45), jsPaused: true);
          expect(
            await readsOver(tester, driver, const Duration(seconds: 1)),
            1,
            reason: 'the backoff resumes once the position is quiet',
          );

          loop.stop();
        },
      );
    });
  });
}
