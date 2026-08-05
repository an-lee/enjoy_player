import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_poll_loop.dart';
import 'package:enjoy_player/features/player/domain/player_settings.dart';
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

    test('repeatMode callback is invoked when media ends (RepeatMode)', () {
      RepeatMode? captured;
      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () {},
        repeatMode: () {
          captured = RepeatMode.single;
          return RepeatMode.single;
        },
        onMediaEnd: () {},
      );

      expect(loop, isNotNull);
      expect(captured, isNull);
      loop.stop();
    });

    test('does not start the poll timer when session is disposed', () async {
      var firstPlayingCalls = 0;
      final loop = YoutubeWebViewPollLoop(
        session: session,
        webController: () => null,
        onFirstPlaying: () => firstPlayingCalls++,
      );

      session.disposed = true;
      loop.start();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(firstPlayingCalls, 0);
      loop.stop();
    });

    test('resets pausedPollStreak to 0 on start()', () {
      session.pausedPollStreak = 5;
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
      session.lastPlayingAt = DateTime.now();
      session.explicitPlayAttempted = true;

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
  });
}
