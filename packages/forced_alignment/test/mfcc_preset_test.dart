import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/src/mfcc/mfcc_extractor.dart';

void main() {
  test('medium window is 25 ms (400 samples at 16 kHz)', () {
    expect(kMfccPresetMedium.windowSeconds, 0.025);
    expect(kMfccPresetMedium.windowLength, 400);
    expect(kMfccPresetMedium.fftSize, 512);
    expect(kMfccPresetMedium.windowStride, 160);
  });
}
