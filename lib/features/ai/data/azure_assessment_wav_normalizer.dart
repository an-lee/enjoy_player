/// Re-encode recordings to WAV that Azure Speech SDK accepts from disk.
///
/// `record` (and some encoders) emit float or non-standard RIFF layouts that
/// can trigger **SPXERR_UNEXPECTED_EOF** with [AudioConfig::FromWavFileInput].
/// Web uses 16 kHz mono 16-bit PCM WAV; we mirror that via FFmpeg.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:enjoy_player/core/audio/wav_signal_peak.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/files/ffmpeg_media_probe.dart';
import 'package:enjoy_player/features/ai/data/azure_assessment_staging_path.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';

final _log = logNamed('ai.azure_assessment_wav');

/// Top-level so the ffmpeg invocation can run inside a worker isolate
/// (see [normalizeWavForAzureAssessment]). Returns the same
/// `({int exitCode, String stderr})` shape we used to capture from
/// `Process.run` so the caller can log the same way.
Future<({int exitCode, String stderr})> _runFfmpegWindowsInIsolate(
  _WindowsFfmpegArgs args,
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
    args.audioFilter,
    '-c:a',
    'pcm_s16le',
    args.outputWavPath,
  ]);
  return (
    exitCode: r.exitCode,
    stderr: r.stderr is String ? r.stderr as String : '',
  );
}

Future<bool> _runFfmpegKit({
  required String inputPath,
  required String outputWavPath,
  required String audioFilter,
}) async {
  final cmd =
      '-nostdin -hide_banner -loglevel error -y -i ${shellEscape(inputPath)} '
      '-vn -af $audioFilter -c:a pcm_s16le ${shellEscape(outputWavPath)}';
  try {
    final session = await FFmpegKit.execute(cmd);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      _log.fine(
        'normalizeWav: FFmpegKit failed filter="$audioFilter": '
        '${await session.getOutput()}',
      );
      return false;
    }
    return true;
  } on MissingPluginException catch (e, st) {
    // `flutter test` and some desktop/embedder builds have no FFmpegKit
    // platform implementation; treat like an unavailable encoder.
    _log.fine(
      'normalizeWav: FFmpegKit not registered in this environment',
      e,
      st,
    );
    return false;
  }
}

Future<void> _deleteIfExists(String path) async {
  try {
    final f = File(path);
    if (f.existsSync()) await f.delete();
  } on Object catch (_) {}
}

bool _looksSilent(WavPeakScan scan) {
  return scan.rmsNormalized < 0.001 ||
      scan.nonZeroRatio < 0.01 ||
      scan.peakNormalized < kWavSilencePeakNorm;
}

/// Runs FFmpeg to write **16 kHz, mono, signed 16-bit PCM** Microsoft WAV.
///
/// Returns `true` when [outputWavPath] exists, has at least 100 bytes, and
/// passes a non-silent peak/RMS check (guards against empty FFmpeg decode).
///
/// On Windows the ffmpeg invocation runs in a worker isolate (via
/// [Isolate.run]) so a long re-encode does not block the UI thread.
Future<bool> normalizeWavForAzureAssessment({
  required String inputPath,
  required String outputWavPath,
}) async {
  if (inputPath.trim().isEmpty) return false;

  final inScan = await scanWavDataPeakFromFile(inputPath);
  if (inScan != null) {
    _log.fine(
      'normalizeWav: input fmt=${inScan.fmt.audioFormat} ch=${inScan.fmt.numChannels} '
      '${inScan.fmt.sampleRate}Hz ${inScan.fmt.bitsPerSample}bit '
      'peak≈${inScan.peakNormalized.toStringAsFixed(5)} '
      'rms≈${inScan.rmsNormalized.toStringAsFixed(6)} '
      'nonZero=${(inScan.nonZeroRatio * 100).toStringAsFixed(2)}%',
    );
  }

  // Filter graph: resample to 16 kHz with libswr (more reliable on Windows
  // than `-ac/-ar` flags), then force the output PCM layout Azure accepts.
  const filter =
      'aresample=16000:resampler=swr,aformat=sample_fmts=s16:channel_layouts=mono';

  await _deleteIfExists(outputWavPath);
  final bool encoded;
  if (Platform.isWindows) {
    final exe = await FfmpegMediaProbe.resolveFfmpegExecutable();
    if (exe == null) {
      _log.fine('normalizeWav: no ffmpeg on Windows, skipping');
      return false;
    }
    try {
      final result = await Isolate.run(
        () => _runFfmpegWindowsInIsolate(
          _WindowsFfmpegArgs(
            exe: exe,
            inputPath: inputPath,
            outputWavPath: outputWavPath,
            audioFilter: filter,
          ),
        ),
        debugName: 'azure-wav-ffmpeg',
      );
      if (result.exitCode != 0) {
        _log.fine(
          'normalizeWav: ffmpeg failed (exit ${result.exitCode}) '
          'filter="$filter": ${result.stderr}',
        );
        return false;
      }
      encoded = true;
    } catch (e, st) {
      _log.fine('normalizeWav: isolate run failed', e, st);
      return false;
    }
  } else {
    encoded = await _runFfmpegKit(
      inputPath: inputPath,
      outputWavPath: outputWavPath,
      audioFilter: filter,
    );
  }
  if (!encoded) return false;

  final out = File(outputWavPath);
  if (!out.existsSync() || out.lengthSync() < 100) {
    _log.fine(
      'normalizeWav: output too small '
      '(${out.existsSync() ? out.lengthSync() : 0} bytes)',
    );
    await _deleteIfExists(outputWavPath);
    return false;
  }

  final outScan = await scanWavDataPeakFromFile(outputWavPath);
  if (outScan == null) {
    _log.fine('normalizeWav: could not parse output WAV for peak check');
    return true;
  }
  if (_looksSilent(outScan)) {
    _log.warning(
      'normalizeWav: FFmpeg output looks silent '
      '(peak≈${outScan.peakNormalized.toStringAsFixed(6)} '
      'rms≈${outScan.rmsNormalized.toStringAsFixed(6)} '
      'nonZero=${(outScan.nonZeroRatio * 100).toStringAsFixed(2)}%)',
    );
    await _deleteIfExists(outputWavPath);
    return false;
  }
  _log.fine(
    'normalizeWav: output ok '
    'peak≈${outScan.peakNormalized.toStringAsFixed(5)} '
    'rms≈${outScan.rmsNormalized.toStringAsFixed(6)} '
    'nonZero=${(outScan.nonZeroRatio * 100).toStringAsFixed(2)}% '
    'bytes=${out.lengthSync()}',
  );
  return true;
}

/// If FFmpeg succeeds, returns a temp `.wav` path the caller must delete.
/// On failure returns `null` (caller should pass the original file to Azure).
Future<String?> tryCreateNormalizedAzureAssessmentWav(String inputPath) async {
  final out = await newAzureAssessmentStagingWavPath();
  final ok = await normalizeWavForAzureAssessment(
    inputPath: inputPath,
    outputWavPath: out,
  );
  if (!ok) {
    await _deleteIfExists(out);
    return null;
  }
  return File(out).absolute.path;
}

class _WindowsFfmpegArgs {
  const _WindowsFfmpegArgs({
    required this.exe,
    required this.inputPath,
    required this.outputWavPath,
    required this.audioFilter,
  });
  final String exe;
  final String inputPath;
  final String outputWavPath;
  final String audioFilter;
}
