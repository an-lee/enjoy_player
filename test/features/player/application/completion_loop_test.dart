import 'package:enjoy_player/features/player/application/completion_loop.dart';
import 'package:enjoy_player/features/player/domain/player_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_player_engine.dart';

void main() {
  group('CompletionLoop', () {
    late FakePlayerEngine fake;
    late RepeatMode repeat;
    late String? mediaId;
    late bool disposed;
    late bool echoActive;
    late double echoStart;
    late CompletionLoop loop;

    setUp(() {
      fake = FakePlayerEngine();
      repeat = RepeatMode.single;
      mediaId = 'm1';
      disposed = false;
      echoActive = false;
      echoStart = 30;
      loop = CompletionLoop(
        engine: () => fake,
        activeMediaId: () => mediaId,
        isDisposed: () => disposed,
        repeatMode: () => repeat,
        echoSnapshot: () => (active: echoActive, startTimeSeconds: echoStart),
      );
    });

    tearDown(() async {
      loop.bump();
      await fake.dispose();
    });

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    test('single loops: seeks to zero and plays on completion', () async {
      loop.arm();
      await settle();

      fake.emitCompleted();
      await settle();

      expect(fake.seekCalls, [Duration.zero]);
      expect(fake.playCallCount, 1);
      expect(fake.resetCompletionFlagCallCount, 1);
    });

    test('loops again on the next completion (re-await)', () async {
      loop.arm();
      await settle();

      fake.emitCompleted();
      await settle();
      fake.emitCompleted();
      await settle();

      expect(fake.seekCalls, [Duration.zero, Duration.zero]);
      expect(fake.playCallCount, 2);
    });

    test(
      'duplicate completed events are a single replay (single-flight)',
      () async {
        loop.arm();
        await settle();

        fake.emitCompleted();
        fake.emitCompleted();
        await settle();

        expect(fake.seekCalls, hasLength(1));
        expect(fake.playCallCount, 1);
      },
    );

    test('none stops: no replay after completion', () async {
      repeat = RepeatMode.none;
      loop.arm();
      await settle();

      fake.emitCompleted();
      await settle();

      expect(fake.seekCalls, isEmpty);
      expect(fake.playCallCount, 0);
    });

    test('segment seeks to the echo window start', () async {
      repeat = RepeatMode.segment;
      echoActive = true;
      loop.arm();
      await settle();

      fake.emitCompleted();
      await settle();

      expect(fake.seekCalls, [const Duration(seconds: 30)]);
      expect(fake.playCallCount, 1);
    });

    test('segment without echo falls back to stop', () async {
      repeat = RepeatMode.segment;
      echoActive = false;
      loop.arm();
      await settle();

      fake.emitCompleted();
      await settle();

      expect(fake.seekCalls, isEmpty);
      expect(fake.playCallCount, 0);
    });

    test('late completion after bump is a no-op', () async {
      loop.arm();
      await settle();

      loop.bump();
      fake.emitCompleted();
      await settle();

      expect(fake.seekCalls, isEmpty);
      expect(fake.playCallCount, 0);
    });

    test(
      'bump cancels the in-flight await; re-arm after media switch',
      () async {
        loop.arm();
        await settle();

        mediaId = 'm2';
        loop.bump();
        fake.emitCompleted(); // stale: belongs to the pre-bump await
        await settle();
        expect(fake.seekCalls, isEmpty);

        loop.arm();
        await settle();
        fake.emitCompleted();
        await settle();
        expect(fake.seekCalls, [Duration.zero]);
      },
    );

    test('arm is single-flight: second call while active is a no-op', () async {
      loop.arm();
      loop.arm();
      await settle();

      fake.emitCompleted();
      await settle();

      expect(fake.seekCalls, hasLength(1));
    });

    test('disposed host stops the loop', () async {
      loop.arm();
      await settle();

      disposed = true;
      loop.bump();
      fake.emitCompleted();
      await settle();

      expect(fake.seekCalls, isEmpty);
    });

    test('arm without an active media is a no-op', () async {
      mediaId = null;
      loop.arm();
      await settle();

      mediaId = 'm1';
      fake.emitCompleted();
      await settle();

      expect(fake.seekCalls, isEmpty);
    });
  });
}
