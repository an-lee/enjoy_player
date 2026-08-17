/// Decode Craft audio bytes to 16 kHz mono Float32 for forced alignment.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:forced_alignment/forced_alignment.dart';

import 'package:enjoy_player/data/files/ffmpeg_media_probe.dart';

/// Thrown when Craft bytes cannot be decoded to 16 kHz mono PCM.
final class Pcm16kDecodeException implements Exception {
  const Pcm16kDecodeException(this.message);
  final String message;

  @override
  String toString() => 'Pcm16kDecodeException($message)';
}

/// Turns WAV (or other FFmpeg-decodable) bytes into 16 kHz mono [Float32List].
///
/// PCM WAV is decoded in-process. Other encodings fall back to a temp-file
/// FFmpeg convert (`pcm_s16le -ar 16000 -ac 1`). Does not import ASR.
Future<Float32List> decodeToPcm16kMono(Uint8List bytes) async {
  final inProcess = decodePcmWavTo16kMono(bytes);
  if (inProcess != null && inProcess.isNotEmpty) {
    return inProcess;
  }
  return _ffmpegFallback(bytes);
}

/// Decode a local media [pathOrUri] to 16 kHz mono Float32.
Future<Float32List> decodeFileToPcm16kMono(String pathOrUri) async {
  final input = FfmpegMediaProbe.mediaInputForFfmpeg(pathOrUri);
  final file = File(input);
  if (!file.existsSync()) {
    throw Pcm16kDecodeException('file does not exist: $input');
  }
  return decodeToPcm16kMono(await file.readAsBytes());
}

/// Decode a time window of a local media file to 16 kHz mono Float32.
Future<Float32List> decodeFileWindowToPcm16kMono({
  required String pathOrUri,
  required double startSeconds,
  required double durationSeconds,
}) async {
  final input = FfmpegMediaProbe.mediaInputForFfmpeg(pathOrUri);
  if (!File(input).existsSync()) {
    throw Pcm16kDecodeException('file does not exist: $input');
  }
  final ffmpeg = await FfmpegMediaProbe.resolveFfmpegExecutable();
  if (ffmpeg == null) {
    throw const Pcm16kDecodeException('ffmpeg unavailable');
  }
  final start = startSeconds < 0 ? 0.0 : startSeconds;
  final duration = durationSeconds <= 0 ? 0.05 : durationSeconds;
  final dir = await Directory.systemTemp.createTemp('enjoy_pcm16k_win_');
  try {
    final output = File('${dir.path}${Platform.pathSeparator}out.wav');
    final result = await Process.run(ffmpeg, [
      '-hide_banner',
      '-nostdin',
      '-y',
      '-ss',
      start.toStringAsFixed(3),
      '-t',
      duration.toStringAsFixed(3),
      '-i',
      input,
      '-ar',
      '$kAlignmentSampleRate',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      output.path,
    ]);
    if (result.exitCode != 0 || !output.existsSync()) {
      throw Pcm16kDecodeException(
        'ffmpeg window extract failed (exit ${result.exitCode})',
      );
    }
    final decoded = decodePcmWavTo16kMono(
      Uint8List.fromList(await output.readAsBytes()),
    );
    if (decoded == null || decoded.isEmpty) {
      throw const Pcm16kDecodeException('ffmpeg window output was not PCM WAV');
    }
    return decoded;
  } finally {
    try {
      await dir.delete(recursive: true);
    } on Object catch (_) {}
  }
}

/// In-process RIFF WAVE decode + mix-to-mono + resample. Returns null when
/// the payload is not a supported PCM/float WAV.
Float32List? decodePcmWavTo16kMono(Uint8List bytes) {
  final parsed = _parseWav(bytes);
  if (parsed == null || parsed.samples.isEmpty) return null;
  return _resampleMono(parsed.samples, parsed.sampleRate, kAlignmentSampleRate);
}

Future<Float32List> _ffmpegFallback(Uint8List bytes) async {
  final ffmpeg = await FfmpegMediaProbe.resolveFfmpegExecutable();
  if (ffmpeg == null) {
    throw const Pcm16kDecodeException('ffmpeg unavailable');
  }
  final dir = await Directory.systemTemp.createTemp('enjoy_pcm16k_');
  try {
    final input = File('${dir.path}${Platform.pathSeparator}in.bin');
    final output = File('${dir.path}${Platform.pathSeparator}out.wav');
    await input.writeAsBytes(bytes, flush: true);
    final result = await Process.run(ffmpeg, [
      '-hide_banner',
      '-nostdin',
      '-y',
      '-i',
      input.path,
      '-ar',
      '$kAlignmentSampleRate',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      output.path,
    ]);
    if (result.exitCode != 0 || !output.existsSync()) {
      throw Pcm16kDecodeException('ffmpeg failed (exit ${result.exitCode})');
    }
    final outBytes = await output.readAsBytes();
    final decoded = decodePcmWavTo16kMono(Uint8List.fromList(outBytes));
    if (decoded == null || decoded.isEmpty) {
      throw const Pcm16kDecodeException('ffmpeg output was not PCM WAV');
    }
    return decoded;
  } finally {
    try {
      await dir.delete(recursive: true);
    } on Object catch (_) {}
  }
}

final class _ParsedWav {
  const _ParsedWav({required this.sampleRate, required this.samples});
  final int sampleRate;
  final Float32List samples;
}

bool _fourCc(Uint8List bytes, int offset, String ascii) {
  if (offset + 4 > bytes.length) return false;
  for (var i = 0; i < 4; i++) {
    if (bytes[offset + i] != ascii.codeUnitAt(i)) return false;
  }
  return true;
}

int _u16(Uint8List b, int o) => b[o] | (b[o + 1] << 8);
int _u32(Uint8List b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

_ParsedWav? _parseWav(Uint8List bytes) {
  if (bytes.length < 44) return null;
  if (!_fourCc(bytes, 0, 'RIFF') || !_fourCc(bytes, 8, 'WAVE')) return null;

  int? audioFormat;
  int? numChannels;
  int? sampleRate;
  int? bitsPerSample;
  int? blockAlign;
  int? dataStart;
  int? dataSize;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final chunkSize = _u32(bytes, offset + 4);
    final chunkData = offset + 8;
    final afterChunk = chunkData + chunkSize;
    if (afterChunk > bytes.length) break;

    if (chunkId == 'fmt ') {
      if (chunkSize < 16) return null;
      audioFormat = _u16(bytes, chunkData);
      numChannels = _u16(bytes, chunkData + 2);
      sampleRate = _u32(bytes, chunkData + 4);
      blockAlign = _u16(bytes, chunkData + 12);
      bitsPerSample = _u16(bytes, chunkData + 14);
    } else if (chunkId == 'data') {
      dataStart = chunkData;
      dataSize = chunkSize;
      break;
    }

    final padded = chunkSize + (chunkSize.isOdd ? 1 : 0);
    offset += 8 + padded;
  }

  final format = audioFormat;
  final channels = numChannels;
  final rate = sampleRate;
  final bits = bitsPerSample;
  final align = blockAlign;
  final start = dataStart;
  final size = dataSize;
  if (format == null ||
      channels == null ||
      channels <= 0 ||
      rate == null ||
      rate <= 0 ||
      bits == null ||
      align == null ||
      align <= 0 ||
      start == null ||
      size == null ||
      size <= 0) {
    return null;
  }

  final end = math.min(start + size, bytes.length);
  final data = bytes.sublist(start, end);
  final frames = data.length ~/ align;
  if (frames <= 0) return null;

  final samples = Float32List(frames);
  switch (format) {
    case 1:
      if (bits == 16 && align == 2 * channels) {
        for (var i = 0; i < frames; i++) {
          var sum = 0.0;
          for (var ch = 0; ch < channels; ch++) {
            final off = i * align + ch * 2;
            final s = data[off] | (data[off + 1] << 8);
            sum += (s > 32767 ? s - 65536 : s) / 32768.0;
          }
          samples[i] = sum / channels;
        }
        return _ParsedWav(sampleRate: rate, samples: samples);
      }
      if (bits == 32 && align == 4 * channels) {
        final bd = ByteData.sublistView(data);
        for (var i = 0; i < frames; i++) {
          var sum = 0.0;
          for (var ch = 0; ch < channels; ch++) {
            final off = i * align + ch * 4;
            sum += bd.getInt32(off, Endian.little) / 2147483648.0;
          }
          samples[i] = sum / channels;
        }
        return _ParsedWav(sampleRate: rate, samples: samples);
      }
      return null;
    case 3:
      if (bits == 32 && align == 4 * channels) {
        final bd = ByteData.sublistView(data);
        for (var i = 0; i < frames; i++) {
          var sum = 0.0;
          for (var ch = 0; ch < channels; ch++) {
            final off = i * align + ch * 4;
            sum += bd.getFloat32(off, Endian.little);
          }
          samples[i] = sum / channels;
        }
        return _ParsedWav(sampleRate: rate, samples: samples);
      }
      return null;
    default:
      return null;
  }
}

Float32List _resampleMono(Float32List input, int fromRate, int toRate) {
  if (fromRate == toRate) return input;
  final outLen = (input.length * toRate / fromRate).round();
  if (outLen <= 0 || input.isEmpty) return Float32List(0);
  final out = Float32List(outLen);
  final last = input.length - 1;
  for (var i = 0; i < outLen; i++) {
    final srcPos = i * fromRate / toRate;
    final i0 = srcPos.floor().clamp(0, last);
    final i1 = math.min(i0 + 1, last);
    final t = srcPos - i0;
    out[i] = input[i0] * (1 - t) + input[i1] * t;
  }
  return out;
}
