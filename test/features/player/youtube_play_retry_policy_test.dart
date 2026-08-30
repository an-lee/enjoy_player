import 'package:enjoy_player/features/player/application/engines/youtube/youtube_audible_playback_policy.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_monotonic_clock.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_play_retry_policy.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Protocol coverage for [YouTubePlayRetryPolicy] — the immediate-pause
/// retry budget (D8), the transport-toggle latch (D9), and the clocks both
/// read (issue #665). Drives the policy directly: no WebView, no session
/// beyond the timing constants the joint invariant is checked against.
void main() {
  group('joint timing invariant', () {
    // The three-way constraint that previously spanned four files with no
    // owner. If any constant changes, this fails before the play-then-pause
    // bug ships.
    test('a pause can be confirmed inside the immediate window, and the budget '
        'outlives that window', () {
      final confirmWindow =
          YoutubeAudiblePlaybackPolicy.pollTick *
          YoutubeSession.pauseConfirmPollTicks;
      expect(
        YouTubePlayRetryPolicy.defaultImmediatePauseWindow,
        greaterThan(confirmWindow),
        reason:
            'a pause is only retried while it is immediate, so the poll '
            'loop must be able to CONFIRM a pause (~$confirmWindow) '
            'before the window closes — a shorter window makes the whole '
            'retry protocol unreachable',
      );
      expect(
        YouTubePlayRetryPolicy.defaultPlayAttemptExpiry,
        greaterThanOrEqualTo(
          YouTubePlayRetryPolicy.defaultImmediatePauseWindow,
        ),
        reason:
            'a budget that retires before the immediate window closes '
            'opens a dead zone where a pause is immediate but uncovered',
      );
      expect(
        YouTubePlayRetryPolicy.defaultMaxAutoRetries,
        greaterThanOrEqualTo(1),
        reason:
            'a zero cap makes the escalation arm unreachable, which is '
            'the echo-mode wedge (the page re-paused the retried play) '
            'the cap exists to bound, not to reintroduce',
      );
    });

    test('a default-constructed policy carries the asserted constants', () {
      // Guards the wiring, not just the constants: the instance fields must
      // not silently drift from what the joint invariant above asserts.
      final policy = YouTubePlayRetryPolicy();
      expect(
        policy.immediatePauseWindow,
        YouTubePlayRetryPolicy.defaultImmediatePauseWindow,
      );
      expect(
        policy.playAttemptExpiry,
        YouTubePlayRetryPolicy.defaultPlayAttemptExpiry,
      );
      expect(
        policy.maxAutoRetries,
        YouTubePlayRetryPolicy.defaultMaxAutoRetries,
      );
    });
  });

  group('D8 — decideConfirmedPause', () {
    test('retries once for an immediate pause with an in-flight user play', () {
      final policy = YouTubePlayRetryPolicy()..beginUserPlay();
      expect(
        policy.decideConfirmedPause(
          immediate: true,
          disposed: false,
          playbackCompleted: false,
        ),
        isA<RetryPlayOnce>(),
      );
    });

    test('surfaces a pause that is not immediate', () {
      final policy = YouTubePlayRetryPolicy()..beginUserPlay();
      expect(
        policy.decideConfirmedPause(
          immediate: false,
          disposed: false,
          playbackCompleted: false,
        ),
        isA<SurfacePause>(),
      );
    });

    test('surfaces when no user play is in flight', () {
      final policy = YouTubePlayRetryPolicy();
      expect(
        policy.decideConfirmedPause(
          immediate: true,
          disposed: false,
          playbackCompleted: false,
        ),
        isA<SurfacePause>(),
      );
    });

    test('never retries when disposed', () {
      final policy = YouTubePlayRetryPolicy()..beginUserPlay();
      expect(
        policy.decideConfirmedPause(
          immediate: true,
          disposed: true,
          playbackCompleted: false,
        ),
        isA<SurfacePause>(),
      );
    });

    test('never retries after end-of-media', () {
      final policy = YouTubePlayRetryPolicy()..beginUserPlay();
      expect(
        policy.decideConfirmedPause(
          immediate: true,
          disposed: false,
          playbackCompleted: true,
        ),
        isA<SurfacePause>(),
      );
    });

    test(
      'escalates when the dying episode was an auto retry, under the cap',
      () {
        // Field wedge (echo mode, Android): the page re-paused the retried
        // play too; the command budget is spent but the episode was ours.
        final policy = YouTubePlayRetryPolicy()
          ..beginUserPlay()
          ..notePlayingTransition(true) // the user episode
          ..notePlayingTransition(false) // it dies
          ..consumeBudget() // the poll loop spent the budget on it
          ..noteAutoPlayRetry() // retry #1
          ..notePlayingTransition(true); // the retried episode

        expect(policy.userPlayInFlight, isFalse);
        expect(policy.lastPlayingFromAutoRetry, isTrue);
        expect(policy.autoRetriesIssued, 1);
        expect(
          policy.decideConfirmedPause(
            immediate: true,
            disposed: false,
            playbackCompleted: false,
          ),
          isA<RetryPlayOnce>(),
        );
      },
    );

    test('stops escalating at the auto-retry cap', () {
      final policy = YouTubePlayRetryPolicy()
        ..beginUserPlay()
        ..notePlayingTransition(true) // the user episode
        ..notePlayingTransition(false)
        ..consumeBudget()
        ..noteAutoPlayRetry() // retry #1
        ..notePlayingTransition(true) // the retried episode
        ..notePlayingTransition(false)
        ..consumeBudget()
        ..noteAutoPlayRetry() // retry #2 — at the cap
        ..notePlayingTransition(true);

      expect(policy.autoRetriesIssued, 2);
      expect(policy.lastPlayingFromAutoRetry, isTrue);
      expect(
        policy.decideConfirmedPause(
          immediate: true,
          disposed: false,
          playbackCompleted: false,
        ),
        isA<SurfacePause>(),
      );
    });

    test('no escalation when the dying episode was not an auto retry', () {
      // e.g. a page-UI resume the app never commanded: no coverage.
      final policy = YouTubePlayRetryPolicy()
        ..beginUserPlay()
        ..notePlayingTransition(true)
        ..consumeBudget();

      expect(policy.lastPlayingFromAutoRetry, isFalse);
      expect(
        policy.decideConfirmedPause(
          immediate: true,
          disposed: false,
          playbackCompleted: false,
        ),
        isA<SurfacePause>(),
      );
    });
  });

  group('D9 — classifyTransportToggle', () {
    test('DOM play arms the retry budget', () {
      expect(
        YouTubePlayRetryPolicy().classifyTransportToggle(domDirection: 'play'),
        isA<ArmRetryBudget>(),
      );
    });

    test('DOM pause consumes the retry budget', () {
      expect(
        YouTubePlayRetryPolicy().classifyTransportToggle(domDirection: 'pause'),
        isA<ConsumeRetryBudget>(),
      );
    });

    test('no video found leaves the latch untouched', () {
      expect(
        YouTubePlayRetryPolicy().classifyTransportToggle(domDirection: null),
        isA<LeaveRetryBudget>(),
      );
    });

    test('unknown direction leaves the latch untouched', () {
      expect(
        YouTubePlayRetryPolicy().classifyTransportToggle(
          domDirection: 'nonsense',
        ),
        isA<LeaveRetryBudget>(),
      );
    });
  });

  group('budget lifecycle', () {
    test('every consuming transition clears the in-flight latch', () {
      final consumers = <String, void Function(YouTubePlayRetryPolicy)>{
        'retry issued': (p) => p.consumeBudget(),
        'play rejected': (p) => p.noteUserPlayUnresolved(),
        'element error': (p) => p.noteUserPlayUnresolved(),
        'user pause command': (p) => p.noteUserPauseCommand(),
        'ended': (p) => p.noteEnded(),
        'reset': (p) => p.reset(),
      };
      for (final entry in consumers.entries) {
        final policy = YouTubePlayRetryPolicy()..beginUserPlay();
        expect(policy.userPlayInFlight, isTrue, reason: 'seed: ${entry.key}');
        entry.value(policy);
        expect(
          policy.userPlayInFlight,
          isFalse,
          reason: '${entry.key} must consume the in-flight play',
        );
      }
    });

    test('the latch survives the first playing (play not yet fulfilled)', () {
      final policy = YouTubePlayRetryPolicy()
        ..beginUserPlay()
        ..notePlayingTransition(true);
      expect(
        policy.userPlayInFlight,
        isTrue,
        reason:
            'the D8 retry must remain reachable for the page correcting a '
            'fresh start back to paused — clearing here made it dead code',
      );
    });

    test('a fresh attempt does not inherit the previous fulfilment clock', () {
      final clock = FakeMonotonicClock();
      final policy =
          YouTubePlayRetryPolicy(
              clock: clock,
              playAttemptExpiry: const Duration(seconds: 1),
            )
            ..beginUserPlay()
            ..notePlayingTransition(true);

      clock.advance(const Duration(seconds: 2));
      expect(policy.userPlayInFlight, isFalse, reason: 'expired');

      policy.beginUserPlay();
      expect(
        policy.userPlayInFlight,
        isTrue,
        reason: 'a new attempt has no resolving episode yet',
      );
    });
  });

  group('clocks', () {
    test('the budget retires once playback outlives the attempt window', () {
      // The fulfilment condition from the field doc, made literal: without
      // the expiry a budget armed minutes ago could be spent by a pause
      // after a page-UI resume the app never commanded.
      final clock = FakeMonotonicClock();
      final policy = YouTubePlayRetryPolicy(
        clock: clock,
        playAttemptExpiry: const Duration(seconds: 2),
      )..beginUserPlay();

      policy.notePlayingTransition(true);
      expect(policy.userPlayInFlight, isTrue, reason: 'still inside');

      clock.advance(const Duration(seconds: 1));
      expect(policy.userPlayInFlight, isTrue);

      clock.advance(const Duration(seconds: 1));
      expect(policy.userPlayInFlight, isFalse, reason: 'expired');
    });

    test('a later playing episode does not refresh the fulfilment clock', () {
      // A page-UI resume the app never commanded must not revive a stale
      // budget: the clock is keyed to the episode that RESOLVED the attempt.
      final clock = FakeMonotonicClock();
      final policy =
          YouTubePlayRetryPolicy(
              clock: clock,
              playAttemptExpiry: const Duration(seconds: 2),
            )
            ..beginUserPlay()
            ..notePlayingTransition(true);

      clock.advance(const Duration(seconds: 1));
      policy.notePlayingTransition(false); // pause confirmed
      policy.notePlayingTransition(true); // page-UI resume

      clock.advance(const Duration(seconds: 1));
      expect(
        policy.userPlayInFlight,
        isFalse,
        reason: 'the second episode started long after the first',
      );
    });

    test('an attempt that never reached playing does not expire', () {
      // No resolving episode → nothing to measure the window against. The
      // next consuming transition (or the next open) retires it.
      final clock = FakeMonotonicClock();
      final policy = YouTubePlayRetryPolicy(clock: clock)..beginUserPlay();

      clock.advance(const Duration(hours: 1));
      expect(policy.userPlayInFlight, isTrue);
    });

    test('the immediate-pause window measures from the playing transition', () {
      final clock = FakeMonotonicClock();
      final policy = YouTubePlayRetryPolicy(
        clock: clock,
        immediatePauseWindow: const Duration(seconds: 2),
      );

      expect(
        policy.isImmediatePause(),
        isFalse,
        reason: 'no playing episode yet — nothing can be immediate',
      );

      policy.notePlayingTransition(true);
      clock.advance(const Duration(seconds: 2));
      expect(policy.isImmediatePause(), isTrue, reason: 'on the boundary');

      clock.advance(const Duration(milliseconds: 1));
      expect(policy.isImmediatePause(), isFalse, reason: 'past the window');
    });

    test('retry recency is measured on the same monotonic clock', () {
      final clock = FakeMonotonicClock();
      final policy = YouTubePlayRetryPolicy(clock: clock);

      expect(policy.recentAutoRetryWithin(const Duration(seconds: 1)), isFalse);

      policy.noteAutoPlayRetry();
      expect(policy.recentAutoRetryWithin(const Duration(seconds: 1)), isTrue);

      clock.advance(const Duration(milliseconds: 999));
      expect(policy.recentAutoRetryWithin(const Duration(seconds: 1)), isTrue);

      clock.advance(const Duration(milliseconds: 2));
      expect(policy.recentAutoRetryWithin(const Duration(seconds: 1)), isFalse);
    });

    test('one injected clock drives every budget in lockstep', () {
      // The reason the protocol stopped reading DateTime.now(): an NTP step
      // or a manual clock change used to jump the budgets independently (a
      // two-second window could expire instantly or never). One monotonic
      // source means one advance retires them together.
      final clock = FakeMonotonicClock();
      final policy =
          YouTubePlayRetryPolicy(
              clock: clock,
              immediatePauseWindow: const Duration(seconds: 2),
              playAttemptExpiry: const Duration(seconds: 2),
            )
            ..beginUserPlay()
            ..notePlayingTransition(true);

      clock.advance(const Duration(seconds: 1));
      expect(policy.userPlayInFlight, isTrue);
      expect(policy.isImmediatePause(), isTrue);

      clock.advance(const Duration(seconds: 1, milliseconds: 1));
      expect(policy.userPlayInFlight, isFalse);
      expect(policy.isImmediatePause(), isFalse);
    });
  });

  group('auto-retry attribution', () {
    test('marks only its own playing episode', () {
      final policy = YouTubePlayRetryPolicy()
        ..beginUserPlay()
        ..notePlayingTransition(true);
      expect(policy.lastPlayingFromAutoRetry, isFalse);

      policy.noteAutoPlayRetry(); // retry #1 issued → count + attribution
      expect(policy.autoRetriesIssued, 1);
      policy.notePlayingTransition(
        false,
      ); // episode ends before the retry plays
      policy.notePlayingTransition(true); // the retry's episode
      expect(policy.lastPlayingFromAutoRetry, isTrue);

      // A deliberate pause drops the attribution — no further escalation.
      policy.noteUserPauseCommand();
      expect(policy.lastPlayingFromAutoRetry, isFalse);

      // A fresh play command resets the chain entirely.
      policy.beginUserPlay();
      expect(policy.autoRetriesIssued, 0);
      expect(policy.lastPlayingFromAutoRetry, isFalse);
    });

    test('poll-tick re-confirmations do not erase the attribution', () {
      // The poll loop re-emits playing on EVERY tick while playing; per-call
      // attribution consumption let the first tick after the retry's playing
      // event erase it, so the escalation arm never fired for the second
      // wedge pause (field round 5). Attribution must latch per episode
      // (false→true transition) instead.
      final policy = YouTubePlayRetryPolicy()
        ..beginUserPlay()
        ..notePlayingTransition(true) // user episode
        ..noteAutoPlayRetry(); // retry #1 issued

      policy.notePlayingTransition(false); // episode ends
      policy.notePlayingTransition(true); // retry episode begins (transition)
      policy.notePlayingTransition(true); // re-confirmation — no-op
      policy.notePlayingTransition(true); // …and again
      expect(
        policy.lastPlayingFromAutoRetry,
        isTrue,
        reason: 're-confirmation ticks must not erase the latch',
      );
    });

    test('a playing→false transition cannot launder the chain', () {
      final policy = YouTubePlayRetryPolicy()
        ..beginUserPlay()
        ..notePlayingTransition(true)
        ..noteAutoPlayRetry();

      policy.notePlayingTransition(false);
      expect(
        policy.lastPlayingFromAutoRetry,
        isFalse,
        reason: 'no episode began, so nothing may be attributed',
      );
      expect(policy.autoRetriesIssued, 1, reason: 'the count is untouched');
    });
  });

  group('reset', () {
    test('clears the budget, the escalation chain, and every clock', () {
      final clock = FakeMonotonicClock();
      final policy = YouTubePlayRetryPolicy(clock: clock)
        ..beginUserPlay()
        ..notePlayingTransition(true)
        ..noteAutoPlayRetry();

      policy.reset();

      expect(policy.userPlayInFlight, isFalse);
      expect(policy.autoRetriesIssued, 0);
      expect(policy.lastPlayingFromAutoRetry, isFalse);
      expect(
        policy.recentAutoRetryWithin(const Duration(hours: 1)),
        isFalse,
        reason: 'a new document must not inherit the previous retry stamp',
      );
      expect(
        policy.isImmediatePause(),
        isFalse,
        reason: 'a new document has no playing episode yet',
      );
    });
  });
}
