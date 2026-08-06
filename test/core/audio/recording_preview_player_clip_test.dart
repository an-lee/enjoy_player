import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:enjoy_player/core/audio/recording_preview_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('armClipEndWatcher', () {
    test('invokes onEnd when position reaches end', () async {
      final controller = StreamController<Duration>();
      var ended = false;
      final sub = armClipEndWatcher(
        position: controller.stream,
        end: const Duration(milliseconds: 500),
        onEnd: () => ended = true,
      );
      controller.add(const Duration(milliseconds: 499));
      await Future<void>.delayed(Duration.zero);
      expect(ended, isFalse);
      controller.add(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);
      expect(ended, isTrue);
      await sub.cancel();
      await controller.close();
    });

    test('does not re-fire after first end', () async {
      final controller = StreamController<Duration>();
      var count = 0;
      final sub = armClipEndWatcher(
        position: controller.stream,
        end: const Duration(milliseconds: 100),
        onEnd: () => count++,
      );
      controller.add(const Duration(milliseconds: 100));
      controller.add(const Duration(milliseconds: 200));
      await Future<void>.delayed(Duration.zero);
      expect(count, 1);
      await sub.cancel();
      await controller.close();
    });
  });

  group('RecordingPreviewPlayer.playClip validation', () {
    try {
      MediaKit.ensureInitialized();
    } on Object catch (e) {
      test(
        '(skipped) media_kit native library not available',
        () {},
        skip: '$e',
      );
      return;
    }

    test('throws when end <= start', () async {
      final player = RecordingPreviewPlayer();
      addTearDown(player.dispose);
      await expectLater(
        player.playClip(
          'unused.wav',
          const Duration(milliseconds: 100),
          const Duration(milliseconds: 100),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when file missing', () async {
      final player = RecordingPreviewPlayer();
      addTearDown(player.dispose);
      final missing = '${Directory.systemTemp.path}/enjoy_missing_take_xyz.wav';
      await expectLater(
        player.playClip(
          missing,
          Duration.zero,
          const Duration(milliseconds: 200),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('missing'),
          ),
        ),
      );
    });
  });
}
