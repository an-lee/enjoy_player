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
}
