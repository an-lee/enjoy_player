import 'dart:typed_data';

import '../constants.dart';

/// Linear-resample mono PCM to [kAlignmentSampleRate] Float32 in `[-1, 1]`.
Float32List resampleToAlignmentRate(Float32List input, int inputRate) {
  if (inputRate <= 0) {
    throw ArgumentError.value(inputRate, 'inputRate');
  }
  if (inputRate == kAlignmentSampleRate) {
    return Float32List.fromList(input);
  }
  if (input.isEmpty) {
    return Float32List(0);
  }
  final outLength = (input.length * kAlignmentSampleRate / inputRate).round();
  if (outLength <= 0) {
    return Float32List(0);
  }
  final out = Float32List(outLength);
  final last = input.length - 1;
  for (var i = 0; i < outLength; i++) {
    final src = i * inputRate / kAlignmentSampleRate;
    final i0 = src.floor().clamp(0, last);
    final i1 = (i0 + 1).clamp(0, last);
    final t = src - i0;
    out[i] = input[i0] * (1 - t) + input[i1] * t;
  }
  return out;
}

/// Convert little-endian int16 samples to Float32 in `[-1, 1]`.
Float32List int16ToFloat32(List<int> samples) {
  final out = Float32List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    out[i] = samples[i] / 32768.0;
  }
  return out;
}
