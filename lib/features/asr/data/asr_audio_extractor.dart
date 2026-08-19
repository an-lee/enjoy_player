/// Extract audio bytes suitable for [AsrService.transcribe] from a
/// local media source.
///
/// * Audio-only sources ([MediaKind.audio]) are read directly — the
///   bytes are passed to the recognition service unchanged.
/// * Video sources ([MediaKind.video]) go through FFmpeg: the audio
///   track is extracted to a temporary 16 kHz mono 16-bit PCM WAV
///   (the format the Azure Speech SDK accepts). On Windows the
///   invocation runs in a worker isolate so a long re-encode does
///   not block the UI thread (mirrors `azure_assessment_wav_normalizer`).
///
/// Errors are mapped to a single [AsrAudioExtractionException] with a
/// machine-readable [AsrAudioExtractionFailureReason] — the controller
/// maps each reason to a localized ARB key (see `asr_failure_messages.dart`).
library;

import 'dart:io';
import 'dart:isolate';

import 'package:enjoy_player/data/files/ffmpeg_media_probe.dart';
import 'package:enjoy_player/features/asr/domain/asr_audio_extraction_failure.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:enjoy_player/core/logging/log.dart';

final Logger _log = logNamed('asr.audio_extractor');

enum MediaKind { audio, video }

class AsrAudioExtractor {
  const AsrAudioExtractor();

  static const _maxBytesDefault = 500 * 1024 * 1024;

  /// Returns the audio bytes to feed to [AsrService.transcribe].
  ///
  /// Throws [AsrAudioExtractionException] on every failure mode listed
  /// in [AsrAudioExtractionFailureReason].
  Future<Uint8List> extractAudio({
    required String mediaSourceUri,
    required MediaKind kind,
    void Function(double progress)? onProgress,
    int maxBytes = _maxBytesDefault,
  }) async {
    if (mediaSourceUri.trim().isEmpty) {
      throw AsrAudioExtractionException(
        AsrAudioExtractionFailureReason.unsupportedSource,
        'Empty media source URI',
      );
    }
    final input = FfmpegMediaProbe.mediaInputForFfmpeg(mediaSourceUri);

    if (kind == MediaKind.audio) {
      return _readAudioDirect(input, maxBytes);
    }

    return _extractFromVideo(
      input: input,
      onProgress: onProgress,
      maxBytes: maxBytes,
    );
  }

  Future<Uint8List> _readAudioDirect(String input, int maxBytes) async {
    final file = File(input);
    if (!file.existsSync()) {
      throw AsrAudioExtractionException(
        AsrAudioExtractionFailureReason.unsupportedSource,
        'Audio file does not exist: $input',
      );
    }
    final size = await file.length();
    if (size > maxBytes) {
      throw AsrAudioExtractionException(
        AsrAudioExtractionFailureReason.fileTooLarge,
        'Audio file is $size bytes (max $maxBytes)',
      );
    }
    return file.readAsBytes();
  }

  Future<Uint8List> _extractFromVideo({
    required String input,
    required void Function(double progress)? onProgress,
    required int maxBytes,
  }) async {
    final file = File(input);
    if (!file.existsSync()) {
      throw AsrAudioExtractionException(
        AsrAudioExtractionFailureReason.unsupportedSource,
        'Video file does not exist: $input',
      );
    }
    final size = await file.length();
    if (size > maxBytes) {
      throw AsrAudioExtractionException(
        AsrAudioExtractionFailureReason.fileTooLarge,
        'Video file is $size bytes (max $maxBytes)',
      );
    }

    onProgress?.call(0.0);

    final dir = await getTemporaryDirectory();
    final outputPath = p.join(dir.path, 'asr_${const Uuid().v4()}.wav');
    try {
      final ok = await _runExtract(
        input: input,
        outputWav: outputPath,
        onProgress: onProgress,
      );
      if (!ok) {
        throw AsrAudioExtractionException(
          AsrAudioExtractionFailureReason.ffmpegFailed,
          'FFmpeg extract failed for $input',
        );
      }
      final out = File(outputPath);
      if (!out.existsSync() || out.lengthSync() < 100) {
        throw AsrAudioExtractionException(
          AsrAudioExtractionFailureReason.noAudioTrack,
          'Extracted audio is empty or missing',
        );
      }
      final extractedSize = out.lengthSync();
      if (extractedSize > maxBytes) {
        throw AsrAudioExtractionException(
          AsrAudioExtractionFailureReason.fileTooLarge,
          'Extracted audio is $extractedSize bytes (max $maxBytes)',
        );
      }
      onProgress?.call(1.0);
      return await out.readAsBytes();
    } finally {
      try {
        final f = File(outputPath);
        if (f.existsSync()) await f.delete();
      } on Object catch (_) {}
    }
  }

  Future<bool> _runExtract({
    required String input,
    required String outputWav,
    required void Function(double progress)? onProgress,
  }) async {
    if (Platform.isWindows) {
      final exe = await FfmpegMediaProbe.resolveFfmpegExecutable();
      if (exe == null) {
        _log.fine('asr_audio_extractor: no ffmpeg.exe on Windows');
        throw AsrAudioExtractionException(
          AsrAudioExtractionFailureReason.ffmpegUnavailable,
          'ffmpeg not available',
        );
      }
      try {
        final result = await Isolate.run(
          () => _windowsExtract(
            _WindowsExtractArgs(
              exe: exe,
              inputPath: input,
              outputWavPath: outputWav,
            ),
          ),
          debugName: 'asr-extract-ffmpeg',
        );
        if (result.exitCode != 0) {
          _log.fine(
            'asr_audio_extractor: ffmpeg exit=${result.exitCode} ${result.stderr}',
          );
        }
        return result.exitCode == 0;
      } on AsrAudioExtractionException {
        rethrow;
      } on Object catch (e, st) {
        _log.fine('asr_audio_extractor: isolate run failed', e, st);
        return false;
      }
    }

    final cmd =
        '-nostdin -hide_banner -loglevel error -y '
        '-i ${_shellEscape(input)} -vn '
        '-af aformat=sample_fmts=s16:channel_layouts=mono -ar 16000 '
        '-ac 1 -c:a pcm_s16le ${_shellEscape(outputWav)}';
    try {
      onProgress?.call(0.1);
      final session = await FFmpegKit.execute(cmd);
      onProgress?.call(0.9);
      final code = await session.getReturnCode();
      final ok = ReturnCode.isSuccess(code);
      if (!ok) {
        _log.fine(
          'asr_audio_extractor: FFmpegKit failed: ${await session.getOutput()}',
        );
      }
      return ok;
    } on MissingPluginException catch (e, st) {
      _log.fine('asr_audio_extractor: FFmpegKit not registered', e, st);
      throw AsrAudioExtractionException(
        AsrAudioExtractionFailureReason.ffmpegUnavailable,
        'ffmpeg not available',
      );
    }
  }
}

class _WindowsExtractArgs {
  const _WindowsExtractArgs({
    required this.exe,
    required this.inputPath,
    required this.outputWavPath,
  });
  final String exe;
  final String inputPath;
  final String outputWavPath;
}

Future<({int exitCode, String stderr})> _windowsExtract(
  _WindowsExtractArgs args,
) async {
  final r = await Process.run(args.exe, <String>[
    '-nostdin',
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-i',
    args.inputPath,
    '-vn',
    '-af',
    'aformat=sample_fmts=s16:channel_layouts=mono',
    '-ar',
    '16000',
    '-ac',
    '1',
    '-c:a',
    'pcm_s16le',
    args.outputWavPath,
  ]);
  return (
    exitCode: r.exitCode,
    stderr: r.stderr is String ? r.stderr as String : '',
  );
}

String _shellEscape(String path) {
  if (path.contains(' ') || path.contains('"')) {
    return '"${path.replaceAll('"', r'\"')}"';
  }
  return path;
}
