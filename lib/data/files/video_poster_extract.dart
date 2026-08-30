/// Extract a single JPEG poster frame from a local video for library thumbnails.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ffmpeg_media_probe.dart';

final _log = logNamed('VideoPosterExtract');

/// Stable key for `media_thumbs/<hex>.jpg` (content hash, else SHA-256 of row id).
String posterStorageKeyHexForVideo(VideoRow row) {
  final m = row.md5;
  if (m != null && m.isNotEmpty) return m;
  return sha256.convert(utf8.encode(row.id)).toString();
}

bool _isNetworkMediaInput(String path) {
  final lower = path.toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://');
}

/// Max seconds to decode from the start when using **accurate** seek (`-i` then `-ss`).
const _kAccurateSeekDecodeCap = 45;

/// Ensures `media_thumbs/` under app documents exists and returns
/// `…/media_thumbs/<contentHashHex>.jpg`.
Future<String> videoThumbnailPathForContentHash(String contentHashHex) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'media_thumbs'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return p.join(dir.path, '$contentHashHex.jpg');
}

/// Chooses a timestamp (seconds) to sample for a poster — avoids t≈0 and t≈1
/// where many encodes are black, logos, or keyframe-snapped to black.
///
/// When [durationSeconds] is null/unknown, uses a fixed ~6s past typical fades.
double posterSeekSeconds(int? durationSeconds) {
  if (durationSeconds != null && durationSeconds > 0) {
    final d = durationSeconds.toDouble();
    if (d <= 2) {
      return (d * 0.45).clamp(0.1, d - 0.05);
    }
    // ~12% into the clip, at least 2.5s from start, before end.
    final fromPercent = d * 0.12;
    final bounded = fromPercent.clamp(2.5, d - 0.25);
    // Fast input-seek beyond ~90s can miss badly on some files; cap there.
    return bounded > 90 ? 90.0 : bounded;
  }
  return 6.0;
}

/// Writes one JPEG frame from [mediaSourceUri] (`file:` or path) to [outputJpegPath].
///
/// [durationSeconds] when known selects **~12%** into the clip (not second 1).
/// Unknown duration uses **~6s** (see [posterSeekSeconds]).
///
/// Uses **accurate** seek (`-i` then `-ss`) when the target time is small enough
/// that decode cost is bounded; otherwise **fast** seek (`-ss` before `-i`).
///
/// Windows: subprocess via [FfmpegMediaProbe.resolveFfmpegExecutable].
/// Other platforms: [FFmpegKit.execute] (bundled libs on mobile).
///
/// Returns `true` when [outputJpegPath] exists and is non-empty after the run.
Future<bool> writeVideoPosterJpeg({
  required String mediaSourceUri,
  required String outputJpegPath,
  int? durationSeconds,
}) async {
  final input = FfmpegMediaProbe.mediaInputForFfmpeg(mediaSourceUri);
  if (input.isEmpty) {
    _log.fine('video poster: empty media input');
    return false;
  }

  final parent = Directory(p.dirname(outputJpegPath));
  if (!await parent.exists()) {
    await parent.create(recursive: true);
  }

  final seek = posterSeekSeconds(durationSeconds);
  final seekStr = seek.toStringAsFixed(3);
  final accurate = seek <= _kAccurateSeekDecodeCap;
  final net = _isNetworkMediaInput(input);

  try {
    if (Platform.isWindows) {
      final exe = await FfmpegMediaProbe.resolveFfmpegExecutable();
      if (exe == null) {
        _log.fine('video poster: no ffmpeg on Windows');
        return false;
      }
      final List<String> args;
      if (accurate) {
        args = [
          '-y',
          '-hide_banner',
          if (net) ...['-protocol_whitelist', 'file,http,https,tcp,tls,crypto'],
          '-i',
          input,
          '-ss',
          seekStr,
          '-frames:v',
          '1',
          '-q:v',
          '3',
          outputJpegPath,
        ];
      } else {
        args = [
          '-y',
          '-hide_banner',
          if (net) ...['-protocol_whitelist', 'file,http,https,tcp,tls,crypto'],
          '-ss',
          seekStr,
          '-i',
          input,
          '-frames:v',
          '1',
          '-q:v',
          '3',
          outputJpegPath,
        ];
      }
      final r = await Process.run(exe, args);
      if (r.exitCode != 0) {
        _log.fine('video poster ffmpeg failed: ${r.stderr}');
        return false;
      }
    } else {
      final proto = net
          ? '-protocol_whitelist file,http,https,tcp,tls,crypto '
          : '';
      final String cmd;
      if (accurate) {
        cmd =
            '-y -hide_banner $proto'
            '-i ${shellEscape(input)} -ss $seekStr '
            '-frames:v 1 -q:v 3 ${shellEscape(outputJpegPath)}';
      } else {
        cmd =
            '-y -hide_banner $proto'
            '-ss $seekStr -i ${shellEscape(input)} '
            '-frames:v 1 -q:v 3 ${shellEscape(outputJpegPath)}';
      }
      final session = await FFmpegKit.execute(cmd);
      final code = await session.getReturnCode();
      if (!ReturnCode.isSuccess(code)) {
        _log.fine(
          'video poster FFmpegKit failed: ${await session.getOutput()}',
        );
        return false;
      }
    }

    final f = File(outputJpegPath);
    if (!await f.exists() || await f.length() == 0) {
      _log.fine('video poster: missing or empty output file');
      return false;
    }
    return true;
  } on Object catch (e, st) {
    _log.fine('video poster extract error', e, st);
    return false;
  }
}
