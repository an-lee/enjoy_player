import 'package:mcfcc_nsn/mcfcc_nsn.dart';

import '../constants.dart';

int _nextPowerOfTwo(int n) {
  var p = 1;
  while (p < n) {
    p <<= 1;
  }
  return p;
}

/// Echogarden-ish hop/window presets (issue #540 § MFCC).
///
/// [windowLength] comes from [windowSeconds]. [fftSize] is the next power of
/// two so `mcfcc_nsn` / FFT can run; frames are zero-padded to that length.
final class MfccPreset {
  const MfccPreset({required this.windowSeconds, required this.hopSeconds});

  final double windowSeconds;
  final double hopSeconds;

  int get windowLength =>
      (windowSeconds * kAlignmentSampleRate).round().clamp(32, 8192);

  int get fftSize => _nextPowerOfTwo(windowLength);

  int get windowStride =>
      (hopSeconds * kAlignmentSampleRate).round().clamp(16, windowLength);
}

/// The one preset: the app hardcodes medium-granularity alignment, so the
/// low/high presets and the `mfccPresetFor` knob were deleted (audit #695).
const MfccPreset kMfccPresetMedium = MfccPreset(
  windowSeconds: 0.025,
  hopSeconds: 0.010,
);

/// MFCC frames for 16 kHz mono PCM. Pads short signals to one window.
List<List<double>> extractMfccFrames(List<double> signal, MfccPreset preset) {
  final window = preset.windowLength;
  final fftSize = preset.fftSize;
  var samples = signal;
  if (samples.length < window) {
    samples = List<double>.from(signal)
      ..addAll(List<double>.filled(window - signal.length, 0));
  }
  final frames = <List<double>>[];
  final stride = preset.windowStride;
  for (var i = 0; i + window <= samples.length; i += stride) {
    final frame = List<double>.filled(fftSize, 0);
    for (var j = 0; j < window; j++) {
      frame[j] = samples[i + j];
    }
    frames.add(frame);
  }
  if (frames.isEmpty) {
    frames.add(List<double>.filled(fftSize, 0));
  }
  final processor = MFCC(
    sampleRate: kAlignmentSampleRate,
    fftSize: fftSize,
    // mcfcc_nsn defaults (26 filters / 13 coefficients); no caller ever
    // overrode them, so the preset fields were folded away (audit #695).
    numFilters: 26,
    numCoefs: 13,
  );
  return processor.processFrames(frames);
}
