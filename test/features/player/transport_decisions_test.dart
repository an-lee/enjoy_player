import 'package:enjoy_player/features/player/domain/player_settings.dart';
import 'package:enjoy_player/features/player/domain/transport_decisions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // D1 — decideSeekRouting
  // ---------------------------------------------------------------------------
  group('decideSeekRouting', () {
    test('routes through echo when active', () {
      expect(decideSeekRouting(echoActive: true), isTrue);
    });

    test('routes directly when echo inactive', () {
      expect(decideSeekRouting(echoActive: false), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // D3 — decideReplayTarget
  // ---------------------------------------------------------------------------
  group('decideReplayTarget', () {
    test('returns echo start when echo active', () {
      final d = decideReplayTarget(
        echoActive: true,
        echoStartTimeSeconds: 5.0,
        activeLineStartSeconds: 10.0,
      );
      expect(d, isA<ReplayToEchoStart>());
      expect((d as ReplayToEchoStart).timeSeconds, 5.0);
    });

    test('returns line start when echo inactive', () {
      final d = decideReplayTarget(
        echoActive: false,
        echoStartTimeSeconds: 5.0,
        activeLineStartSeconds: 10.0,
      );
      expect(d, isA<ReplayToLineStart>());
      expect((d as ReplayToLineStart).timeSeconds, 10.0);
    });
  });

  // ---------------------------------------------------------------------------
  // D4 — decideProgressSeekTime
  // ---------------------------------------------------------------------------
  group('decideProgressSeekTime', () {
    test('invalid when duration is zero', () {
      expect(decideProgressSeekTime(fraction: 0.5, durationSeconds: 0), isNull);
    });

    test('invalid when duration is negative', () {
      expect(
        decideProgressSeekTime(fraction: 0.5, durationSeconds: -1),
        isNull,
      );
    });

    test('seeks to middle', () {
      expect(decideProgressSeekTime(fraction: 0.5, durationSeconds: 100), 50);
    });

    test('clamps fraction below zero', () {
      expect(decideProgressSeekTime(fraction: -0.5, durationSeconds: 100), 0);
    });

    test('clamps fraction above one', () {
      expect(decideProgressSeekTime(fraction: 1.5, durationSeconds: 100), 100);
    });

    test('target is clamped to duration', () {
      expect(decideProgressSeekTime(fraction: 1.0, durationSeconds: 100), 100);
    });
  });

  // ---------------------------------------------------------------------------
  // D5 — decideYouTubePlayRestart
  // ---------------------------------------------------------------------------
  group('decideYouTubePlayRestart', () {
    test('restarts when playback completed', () {
      expect(decideYouTubePlayRestart(playbackCompleted: true), isTrue);
    });

    test('resumes when playback not completed', () {
      expect(decideYouTubePlayRestart(playbackCompleted: false), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // D6 — decidePollTransition
  // ---------------------------------------------------------------------------
  group('decidePollTransition', () {
    final playing = true;
    final notPlaying = false;
    final jsEnded = true;
    final jsNotEnded = false;
    final jsPaused = true;
    final jsNotPaused = false;
    const threshold = 3;

    test('media ended', () {
      final d = decidePollTransition(
        jsEnded: jsEnded,
        jsPaused: jsNotPaused,
        playing: playing,
        pausedPollStreak: 0,
        pauseConfirmThreshold: threshold,
        playbackCompleted: false,
      );
      expect(d, isA<MediaJustEnded>());
    });

    test('media ended when already marked completed is idle', () {
      final d = decidePollTransition(
        jsEnded: jsEnded,
        jsPaused: jsNotPaused,
        playing: notPlaying,
        pausedPollStreak: 0,
        pauseConfirmThreshold: threshold,
        playbackCompleted: true,
      );
      expect(d, isA<PollIdleTick>());
    });

    test('pause streaking — not yet confirmed', () {
      final d = decidePollTransition(
        jsEnded: jsNotEnded,
        jsPaused: jsPaused,
        playing: playing,
        pausedPollStreak: 0,
        pauseConfirmThreshold: threshold,
        playbackCompleted: false,
      );
      expect(d, isA<PauseStreaking>());
      final p = d as PauseStreaking;
      expect(p.confirmed, false);
      expect(p.newStreak, 1);
    });

    test('pause streaking — confirmed', () {
      final d = decidePollTransition(
        jsEnded: jsNotEnded,
        jsPaused: jsPaused,
        playing: playing,
        pausedPollStreak: threshold - 1,
        pauseConfirmThreshold: threshold,
        playbackCompleted: false,
      );
      expect(d, isA<PauseStreaking>());
      final p = d as PauseStreaking;
      expect(p.confirmed, true);
      expect(p.newStreak, threshold);
    });

    test('returns PollPlaying when JS says playing and not ended', () {
      final d = decidePollTransition(
        jsEnded: jsNotEnded,
        jsPaused: jsNotPaused,
        playing: playing,
        pausedPollStreak: 0,
        pauseConfirmThreshold: threshold,
        playbackCompleted: false,
      );
      expect(d, isA<PollPlaying>());
    });

    test('pause streaking ignored when not client-playing', () {
      final d = decidePollTransition(
        jsEnded: jsNotEnded,
        jsPaused: jsPaused,
        playing: notPlaying,
        pausedPollStreak: 0,
        pauseConfirmThreshold: threshold,
        playbackCompleted: false,
      );
      expect(d, isA<PollIdleTick>());
    });
  });

  // ---------------------------------------------------------------------------
  // D7 — decideOnMediaEnd
  // ---------------------------------------------------------------------------
  group('decideOnMediaEnd', () {
    test('RepeatMode.none stops', () {
      final d = decideOnMediaEnd(repeatMode: RepeatMode.none);
      expect(d, isA<StopAtEnd>());
    });

    test('RepeatMode.single loops', () {
      final d = decideOnMediaEnd(repeatMode: RepeatMode.single);
      expect(d, isA<LoopMedia>());
    });

    test('RepeatMode.segment does segment loop', () {
      final d = decideOnMediaEnd(repeatMode: RepeatMode.segment);
      expect(d, isA<LoopSegment>());
    });
  });

  // D8 (immediate-pause retry) and D9 (transport-toggle latch) moved to
  // youtube_play_retry_policy_test.dart with the protocol they decide about
  // (issue #665).
}
