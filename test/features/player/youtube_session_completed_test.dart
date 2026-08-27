import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YoutubeSession.markCompleted (ADR-0044)', () {
    late YoutubeSession session;

    setUp(() {
      session = YoutubeSession();
    });

    tearDown(() async {
      await session.closeStreams();
    });

    test('emits on the completed stream on first transition', () async {
      final events = <void>[];
      final sub = session.completed.listen(events.add);

      session.markCompleted();
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(session.playbackCompleted, isTrue);
      await sub.cancel();
    });

    test('is idempotent — second call does not emit again', () async {
      final events = <void>[];
      final sub = session.completed.listen(events.add);

      session.markCompleted();
      session.markCompleted();
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      await sub.cancel();
    });

    test(
      'resetForOpen re-arms the emission for the next end-of-media',
      () async {
        final events = <void>[];
        final sub = session.completed.listen(events.add);

        session.markCompleted();
        await Future<void>.delayed(Duration.zero);

        session.resetForOpen('newVideoId');
        session.markCompleted();
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(2));
        await sub.cancel();
      },
    );
  });

  group('YoutubeSession recovery hint', () {
    late YoutubeSession session;

    setUp(() {
      session = YoutubeSession()..resetForOpen('vid');
    });

    tearDown(() async {
      await session.closeStreams();
    });

    test(
      'scheduleRecoveryHint shows overlay after failed explicit play',
      () async {
        session
          ..markFirstPlayingLogged()
          ..markExplicitPlayAttempt()
          ..emitBuffering(false)
          ..emitPlaying(false);

        session.scheduleRecoveryHint();
        await Future<void>.delayed(const Duration(milliseconds: 1300));

        expect(session.tapToPlayHintActive, isTrue);
      },
    );

    test('playing clears the recovery overlay', () async {
      session
        ..markFirstPlayingLogged()
        ..markExplicitPlayAttempt()
        ..emitBuffering(false);
      session.scheduleRecoveryHint();
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(session.tapToPlayHintActive, isTrue);

      session.emitPlaying(true);
      expect(session.tapToPlayHintActive, isFalse);
    });

    test('resetForOpen clears explicit play and volume restore state', () {
      session
        ..markExplicitPlayAttempt()
        ..armVolumeRestorePending(baseline: Duration.zero)
        ..emitPlaying(true);
      session.resetForOpen('other');
      expect(session.explicitPlayAttempted, isFalse);
      expect(session.volumeRestorePending, isFalse);
      expect(session.playing, isFalse);
      expect(session.lastPlayingAt, isNull);
    });
  });

  group('YoutubeSession per-document volume restore tracking', () {
    late YoutubeSession session;

    setUp(() {
      session = YoutubeSession()..resetForOpen('vid');
    });

    tearDown(() async {
      await session.closeStreams();
    });

    test('fresh open needs a volume restore', () {
      expect(session.needsVolumeRestore, isTrue);
    });

    test('noteVolumeRestored pins the current document', () {
      session.noteVolumeRestored();
      expect(session.needsVolumeRestore, isFalse);
      expect(session.volumeRestoredDocGen, session.documentGen);
    });

    test('watch load stop bumps the generation (post-ad reload)', () {
      session.noteVolumeRestored();
      final before = session.documentGen;

      session.noteWatchDocumentLoaded();

      expect(session.documentGen, before + 1);
      expect(session.needsVolumeRestore, isTrue);
    });

    test('resetForOpen starts a new document needing restore', () {
      session.noteVolumeRestored();
      session.resetForOpen('other');

      expect(session.needsVolumeRestore, isTrue);
      expect(session.volumeRestoredDocGen, -1);
    });

    test('resetForClear drops the restored pin', () {
      session.noteVolumeRestored();
      session.resetForClear();

      expect(session.needsVolumeRestore, isTrue);
      expect(session.volumeRestoredDocGen, -1);
    });

    test('disposed session never needs restore', () async {
      await session.closeStreams();
      expect(session.needsVolumeRestore, isFalse);
    });
  });
}
