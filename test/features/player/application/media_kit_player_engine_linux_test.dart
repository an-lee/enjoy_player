import 'dart:io' show Platform;

import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/presentation/widgets/media_kit_video_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' show Video;

void main() {
  group('MediaKitPlayerEngine on Linux', () {
    test('can be instantiated on Linux without throwing', () {
      final engine = MediaKitPlayerEngine();
      expect(engine, isNotNull);
    });

    test('warmVideoSurface does not throw on Linux', () {
      final engine = MediaKitPlayerEngine();
      expect(() => engine.warmVideoSurface(), returnsNormally);
    }, skip: !Platform.isLinux);

    test(
      'supportsVideoPosterCapture is true on Linux (same as other desks)',
      () {
        final engine = MediaKitPlayerEngine();
        expect(
          engine.supportsVideoPosterCapture,
          true,
          reason: 'media_kit screenshot works on Linux (libmpv frame capture).',
        );
      },
    );

    testWidgets(
      'native backend gate lives in the video stage only (issue #658)',
      (tester) async {
        final engine = MediaKitPlayerEngine();

        Future<void> pumpStage() => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaKitVideoStage(
                engine: engine,
                maxWidth: 320,
                maxHeight: 180,
              ),
            ),
          ),
        );

        // Not allowed yet: a bare placeholder — no [Video], hence no
        // [videoController] and no mpv allocation.
        expect(engine.nativeBackendAllowed, isFalse);
        await pumpStage();
        expect(find.byType(Video), findsNothing);

        // Engine entry points other than [prepareNativeBackend] must not
        // approve the gate. The old `_player` getter did exactly that (it set
        // `_nativeBackendAllowed = true` while claiming to check it), so the
        // gate is stage-only and nothing else can flip it.
        engine.warmVideoSurface();
        expect(engine.nativeBackendAllowed, isFalse);
        await pumpStage();
        expect(find.byType(Video), findsNothing);
      },
    );
  });
}
