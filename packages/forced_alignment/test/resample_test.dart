import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/src/constants.dart';
import 'package:forced_alignment/src/synth/resample.dart';

void main() {
  test('identity resample at 16 kHz', () {
    final input = Float32List.fromList([0, 0.5, -0.5, 1]);
    final out = resampleToAlignmentRate(input, kAlignmentSampleRate);
    expect(out, input);
  });

  test('22050 to 16000 changes length', () {
    final input = Float32List(22050);
    for (var i = 0; i < input.length; i++) {
      input[i] = i / input.length;
    }
    final out = resampleToAlignmentRate(input, 22050);
    expect(out.length, kAlignmentSampleRate);
    expect(out.first, closeTo(0, 0.01));
    expect(out.last, closeTo(1, 0.02));
  });
}
