import 'package:enjoy_player/features/player/application/engines/youtube/youtube_audible_playback_policy.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behaviour coverage for [YoutubeAudiblePlaybackPolicy] — the mute-start →
/// restore → heal choreography under Chromium's autoplay gesture lock
/// (issue #628). Drives the policy directly: no WebView, no events dispatch.
void main() {
  group('joint timing invariant', () {
    // The three-way constraint that previously spanned three files with no
    // owner. If any constant changes, this fails before the play-then-pause
    // bug ships.
    test('heal beats pause-confirmation and loses to the recovery hint', () {
      final confirmWindow =
          YoutubeAudiblePlaybackPolicy.pollTick *
          YoutubeSession.pauseConfirmPollTicks;
      expect(
        YoutubeAudiblePlaybackPolicy.defaultPostRestoreHealDelay,
        greaterThan(confirmWindow),
        reason:
            'heal must wait until a gesture-lock pause is already reflected '
            'in session.playing (~$confirmWindow)',
      );
      expect(
        YoutubeSession.tapToPlayHintDelay,
        greaterThan(YoutubeAudiblePlaybackPolicy.defaultPostRestoreHealDelay),
        reason: 'heal must recover before the tap-to-play hint shows',
      );
    });
  });

  group('progress-gated restore', () {
    test('restores volume after playback progress settles', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var restoreCalls = 0;
      final policy = YoutubeAudiblePlaybackPolicy(
        session: session,
        reapplyVolume: () async => restoreCalls++,
        healPlay: () async {},
        volumeRestoreDelay: Duration.zero,
      );

      session.notePlayingConfirmed();
      policy.onPlaying();
      expect(session.volumeRestorePending, isTrue);
      expect(restoreCalls, 0);

      // Need [progressConfirmTicks] advancing samples.
      policy.onPlaybackProgress(const Duration(milliseconds: 100));
      expect(restoreCalls, 0);
      policy.onPlaybackProgress(const Duration(milliseconds: 200));

      expect(restoreCalls, 1);
      expect(session.volumeRestorePending, isFalse);
      await session.closeStreams();
    });

    test('restores volume via fallback when progress never arrives', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var restoreCalls = 0;
      final policy = YoutubeAudiblePlaybackPolicy(
        session: session,
        reapplyVolume: () async => restoreCalls++,
        healPlay: () async {},
        volumeRestoreDelay: Duration.zero,
        volumeRestoreFallback: const Duration(milliseconds: 80),
      );

      session.notePlayingConfirmed();
      policy.onPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(restoreCalls, 1);
      await session.closeStreams();
    });

    test(
      'does not touch volume on later playing in the same document',
      () async {
        final session = YoutubeSession()
          ..resetForOpen('abc12345678')
          ..noteVolumeRestored();
        var restoreCalls = 0;
        final policy = YoutubeAudiblePlaybackPolicy(
          session: session,
          reapplyVolume: () async => restoreCalls++,
          healPlay: () async {},
        );

        session.notePlayingConfirmed();
        policy.onPlaying();

        // Redundant programmatic unMutes are pause triggers under Chromium's
        // autoplay gesture lock (play-then-pause root cause): an already
        // restored document must skip the restore entirely.
        expect(restoreCalls, 0);
        expect(session.volumeRestorePending, isFalse);
        await session.closeStreams();
      },
    );

    test(
      're-arms restore for a fresh watch document (post-ad reload)',
      () async {
        final session = YoutubeSession()
          ..resetForOpen('abc12345678')
          ..noteVolumeRestored();
        var restoreCalls = 0;
        final policy = YoutubeAudiblePlaybackPolicy(
          session: session,
          reapplyVolume: () async => restoreCalls++,
          healPlay: () async {},
          volumeRestoreDelay: Duration.zero,
        );

        // Ad reload lands a brand-new document whose <video> starts muted.
        session.noteWatchDocumentLoaded();
        session.notePlayingConfirmed();
        policy.onPlaying();
        expect(session.volumeRestorePending, isTrue);
        expect(restoreCalls, 0);

        // Progress gate still applies within the new document.
        policy.onPlaybackProgress(const Duration(milliseconds: 100));
        policy.onPlaybackProgress(const Duration(milliseconds: 200));
        expect(restoreCalls, 1);
        await Future<void>.delayed(Duration.zero);
        expect(session.volumeRestoredDocGen, session.documentGen);
        await session.closeStreams();
      },
    );

    test('DOM pause abandons the pending restore', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var restoreCalls = 0;
      final policy = YoutubeAudiblePlaybackPolicy(
        session: session,
        reapplyVolume: () async => restoreCalls++,
        healPlay: () async {},
        volumeRestoreFallback: const Duration(milliseconds: 80),
      );

      session.notePlayingConfirmed();
      policy.onPlaying();
      policy.onPause();

      expect(session.volumeRestorePending, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(restoreCalls, 0);
      await session.closeStreams();
    });
  });

  group('post-restore heal', () {
    test(
      'heals a pause that immediately followed the volume restore',
      () async {
        final session = YoutubeSession()..resetForOpen('abc12345678');
        var healCalls = 0;
        final policy = YoutubeAudiblePlaybackPolicy(
          session: session,
          reapplyVolume: () async {},
          healPlay: () async => healCalls++,
          volumeRestoreDelay: Duration.zero,
          postRestoreHealDelay: const Duration(milliseconds: 20),
        );

        session.notePlayingConfirmed();
        policy.onPlaying();
        policy.onPlaybackProgress(const Duration(milliseconds: 100));
        policy.onPlaybackProgress(const Duration(milliseconds: 200));

        // The unmute tripped the WebView's autoplay gesture lock and playback
        // stopped; simulate the poll loop's pause confirmation.
        await Future<void>.delayed(Duration.zero);
        session.notePauseConfirmed();

        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(healCalls, 1);
        await session.closeStreams();
      },
    );

    test('no heal when playback survives the volume restore', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var healCalls = 0;
      final policy = YoutubeAudiblePlaybackPolicy(
        session: session,
        reapplyVolume: () async {},
        healPlay: () async => healCalls++,
        volumeRestoreDelay: Duration.zero,
        postRestoreHealDelay: const Duration(milliseconds: 20),
      );

      session.notePlayingConfirmed();
      policy.onPlaying();
      policy.onPlaybackProgress(const Duration(milliseconds: 100));
      policy.onPlaybackProgress(const Duration(milliseconds: 200));

      // Video kept playing after the unmute (the healthy case).
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(healCalls, 0);
      await session.closeStreams();
    });

    test('stale heal is skipped when a new document re-arms restore', () async {
      final session = YoutubeSession()..resetForOpen('abc12345678');
      var healCalls = 0;
      final policy = YoutubeAudiblePlaybackPolicy(
        session: session,
        reapplyVolume: () async {},
        healPlay: () async => healCalls++,
        volumeRestoreDelay: Duration.zero,
        postRestoreHealDelay: const Duration(milliseconds: 20),
      );

      session.notePlayingConfirmed();
      policy.onPlaying();
      policy.onPlaybackProgress(const Duration(milliseconds: 100));
      policy.onPlaybackProgress(const Duration(milliseconds: 200));
      await Future<void>.delayed(Duration.zero);

      // Ad reload lands a new document before the heal fires.
      session.noteWatchDocumentLoaded();
      session.notePauseConfirmed();

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(healCalls, 0);
      await session.closeStreams();
    });
  });
}
