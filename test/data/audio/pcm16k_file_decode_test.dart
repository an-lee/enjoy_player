import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/audio/pcm16k_mono.dart';

void main() {
  test('decodeFileToPcm16kMono fails when the path is missing', () async {
    expect(
      () => decodeFileToPcm16kMono(r'C:\enjoy-missing-pcm16k-file.wav'),
      throwsA(isA<Pcm16kDecodeException>()),
    );
  });

  test('decodeFileWindowToPcm16kMono fails when the path is missing', () async {
    expect(
      () => decodeFileWindowToPcm16kMono(
        pathOrUri: r'C:\enjoy-missing-pcm16k-window.wav',
        startSeconds: 0,
        durationSeconds: 1,
      ),
      throwsA(isA<Pcm16kDecodeException>()),
    );
  });

  test(
    'decodeFileWindowToPcm16kMono fails closed when FFmpeg cannot decode',
    () async {
      final junk = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'enjoy_pcm16k_not_media_${DateTime.now().microsecondsSinceEpoch}.bin',
      );
      await junk.writeAsBytes(const [0, 1, 2, 3, 4, 5, 6, 7], flush: true);
      addTearDown(() {
        if (junk.existsSync()) junk.deleteSync();
      });
      await expectLater(
        decodeFileWindowToPcm16kMono(
          pathOrUri: junk.path,
          startSeconds: 0,
          durationSeconds: 0.2,
        ),
        throwsA(isA<Pcm16kDecodeException>()),
      );
    },
  );
}
