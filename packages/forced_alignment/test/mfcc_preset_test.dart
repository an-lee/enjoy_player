import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/src/mfcc/mfcc_extractor.dart';

void main() {
  test('medium window is 25 ms (400 samples at 16 kHz)', () {
    expect(kMfccPresetMedium.windowSeconds, 0.025);
    expect(kMfccPresetMedium.windowLength, 400);
    expect(kMfccPresetMedium.fftSize, 512);
    expect(kMfccPresetMedium.windowStride, 160);
  });

  test('low window is 40 ms; high hop is finer than medium', () {
    expect(kMfccPresetLow.windowSeconds, 0.040);
    expect(kMfccPresetLow.windowLength, 640);
    expect(kMfccPresetLow.fftSize, 1024);
    expect(kMfccPresetHigh.windowLength, kMfccPresetMedium.windowLength);
    expect(
      kMfccPresetHigh.windowStride,
      lessThan(kMfccPresetMedium.windowStride),
    );
  });
}
