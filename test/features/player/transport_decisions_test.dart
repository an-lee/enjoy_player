import 'package:enjoy_player/features/player/domain/player_settings.dart';
import 'package:enjoy_player/features/player/domain/transport_decisions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // D1 — decideSeekRouting
  // ---------------------------------------------------------------------------
  group('decideSeekRouting', () {
    test('routes through echo when active', () {
      final d = decideSeekRouting(echoActive: true);
      expect(d, isA<SeekThroughEcho>());
    });

    test('routes directly when echo inactive', () {
      final d = decideSeekRouting(echoActive: false);
      expect(d, isA<SeekDirect>());
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
      final d = decideProgressSeekTime(fraction: 0.5, durationSeconds: 0);
      expect(d, isA<ProgressSeekInvalid>());
    });

    test('invalid when duration is negative', () {
      final d = decideProgressSeekTime(fraction: 0.5, durationSeconds: -1);
      expect(d, isA<ProgressSeekInvalid>());
    });

    test('seeks to middle', () {
      final d = decideProgressSeekTime(fraction: 0.5, durationSeconds: 100);
      expect(d, isA<ProgressSeekValid>());
      expect((d as ProgressSeekValid).timeSeconds, 50);
    });

    test('clamps fraction below zero', () {
      final d = decideProgressSeekTime(fraction: -0.5, durationSeconds: 100);
      expect((d as ProgressSeekValid).timeSeconds, 0);
    });

    test('clamps fraction above one', () {
      final d = decideProgressSeekTime(fraction: 1.5, durationSeconds: 100);
      expect((d as ProgressSeekValid).timeSeconds, 100);
    });

    test('target is clamped to duration', () {
      final d = decideProgressSeekTime(fraction: 1.0, durationSeconds: 100);
      expect((d as ProgressSeekValid).timeSeconds, 100);
    });
  });

  // ---------------------------------------------------------------------------
  // D5 — decideYouTubePlayRestart
  // ---------------------------------------------------------------------------
  group('decideYouTubePlayRestart', () {
    test('restarts when playback completed', () {
      final d = decideYouTubePlayRestart(playbackCompleted: true);
      expect(d, isA<RestartFromBeginning>());
    });

    test('resumes when playback not completed', () {
      final d = decideYouTubePlayRestart(playbackCompleted: false);
      expect(d, isA<ResumePlayback>());
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

  // ---------------------------------------------------------------------------
  // D8 — decideImmediatePauseRetry
  // ---------------------------------------------------------------------------
  group('decideImmediatePauseRetry', () {
    test('retries once for an immediate pause with an in-flight user play', () {
      final d = decideImmediatePauseRetry(
        immediate: true,
        userPlayInFlight: true,
        disposed: false,
        playbackCompleted: false,
      );
      expect(d, isA<RetryPlayOnce>());
    });

    test('surfaces a pause that is not immediate', () {
      final d = decideImmediatePauseRetry(
        immediate: false,
        userPlayInFlight: true,
        disposed: false,
        playbackCompleted: false,
      );
      expect(d, isA<SurfacePause>());
    });

    test('surfaces when no user play is in flight', () {
      final d = decideImmediatePauseRetry(
        immediate: true,
        userPlayInFlight: false,
        disposed: false,
        playbackCompleted: false,
      );
      expect(d, isA<SurfacePause>());
    });

    test('never retries when disposed', () {
      final d = decideImmediatePauseRetry(
        immediate: true,
        userPlayInFlight: true,
        disposed: true,
        playbackCompleted: false,
      );
      expect(d, isA<SurfacePause>());
    });

    test('never retries after end-of-media', () {
      final d = decideImmediatePauseRetry(
        immediate: true,
        userPlayInFlight: true,
        disposed: false,
        playbackCompleted: true,
      );
      expect(d, isA<SurfacePause>());
    });
  });
}
