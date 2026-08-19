import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

import 'package:enjoy_player/data/audio/pcm16k_mono.dart';

Uint8List _pcm16Wav({
  required int sampleRate,
  required int channels,
  required Int16List samples,
}) {
  final dataBytes = samples.length * 2;
  final bytes = Uint8List(44 + dataBytes);
  final bd = ByteData.sublistView(bytes);
  void ascii(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes[o + i] = s.codeUnitAt(i);
    }
  }

  ascii(0, 'RIFF');
  bd.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little);
  bd.setUint16(22, channels, Endian.little);
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, sampleRate * channels * 2, Endian.little);
  bd.setUint16(32, channels * 2, Endian.little);
  bd.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bd.setUint32(40, dataBytes, Endian.little);
  var o = 44;
  for (final s in samples) {
    bd.setInt16(o, s, Endian.little);
    o += 2;
  }
  return bytes;
}

void main() {
  test('16 kHz mono PCM WAV decodes to non-empty Float32List', () {
    final samples = Int16List(kAlignmentSampleRate);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = (i % 64) * 200;
    }
    final wav = _pcm16Wav(sampleRate: 16000, channels: 1, samples: samples);
    final pcm = decodePcmWavTo16kMono(wav);
    expect(pcm, isNotNull);
    expect(pcm!.length, kAlignmentSampleRate);
    expect(pcm.any((s) => s != 0), isTrue);
  });

  test('8 kHz stereo PCM WAV resamples to 16 kHz mono', () {
    final frames = 800;
    final samples = Int16List(frames * 2);
    for (var i = 0; i < frames; i++) {
      samples[i * 2] = 1000;
      samples[i * 2 + 1] = 3000;
    }
    final wav = _pcm16Wav(sampleRate: 8000, channels: 2, samples: samples);
    final pcm = decodePcmWavTo16kMono(wav);
    expect(pcm, isNotNull);
    expect(pcm!.length, closeTo(1600, 2));
    expect(pcm.first, closeTo((1000 + 3000) / 2 / 32768.0, 0.001));
  });

  test('non-WAV bytes return null in-process', () {
    expect(decodePcmWavTo16kMono(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  test('decodeToPcm16kMono succeeds for a PCM WAV fixture', () async {
    final samples = Int16List(800);
    final wav = _pcm16Wav(sampleRate: 8000, channels: 1, samples: samples);
    final pcm = await decodeToPcm16kMono(wav);
    expect(pcm, isNotEmpty);
    expect(pcm.length, closeTo(1600, 2));
  });

  test('FFmpegKit is used on Android, iOS, and macOS only', () {
    expect(
      pcm16kUsesFfmpegKit(isAndroid: true, isIOS: false, isMacOS: false),
      isTrue,
    );
    expect(
      pcm16kUsesFfmpegKit(isAndroid: false, isIOS: true, isMacOS: false),
      isTrue,
    );
    expect(
      pcm16kUsesFfmpegKit(isAndroid: false, isIOS: false, isMacOS: true),
      isTrue,
    );
    expect(
      pcm16kUsesFfmpegKit(isAndroid: false, isIOS: false, isMacOS: false),
      isFalse,
    );
  });
}
