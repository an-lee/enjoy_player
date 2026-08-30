/// Resolve `ffmpeg` and parse its `-i` probe output (stderr).
library;

import 'dart:convert';
import 'dart:io';

import 'package:enjoy_player/core/utils/duration_parsing.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Shared helpers for `ffmpeg -hide_banner -i …` stderr parsing.
class FfmpegMediaProbe {
  FfmpegMediaProbe._();

  /// Cached resolution so repeated callers don't each spawn `ffmpeg -version`.
  /// The bundled binary location / PATH result is stable for the process
  /// lifetime, so this is safe to memoize. Concurrent first callers share the
  /// same in-flight [Future].
  static Future<String?>? _resolvedFuture;

  /// Bundled CLI next to the app (Windows `ffmpeg.exe`, Linux `ffmpeg`), or
  /// `ffmpeg` on PATH. Android / iOS / macOS do not use this — they run
  /// FFmpegKit. The result is memoized for the process lifetime
  /// (see [_resolvedFuture]).
  static Future<String?> resolveFfmpegExecutable() {
    return _resolvedFuture ??= _resolveFfmpegExecutableUncached();
  }

  static Future<String?> _resolveFfmpegExecutableUncached() async {
    final dir = p.dirname(Platform.resolvedExecutable);
    for (final candidate in bundledFfmpegCandidatePaths(
      executableDir: dir,
      isWindows: Platform.isWindows,
      isLinux: Platform.isLinux,
    )) {
      if (File(candidate).existsSync()) return candidate;
    }
    try {
      final r = await Process.run('ffmpeg', ['-version']);
      if (r.exitCode == 0) return 'ffmpeg';
    } on Object catch (_) {}
    return null;
  }

  /// Windows: `ffmpeg.exe` next to the app. Linux: `ffmpeg` next to the app
  /// or under `lib/` (AppImage / desktop bundle). Empty on Apple/Android.
  @visibleForTesting
  static List<String> bundledFfmpegCandidatePaths({
    required String executableDir,
    required bool isWindows,
    required bool isLinux,
  }) {
    if (isWindows) {
      return [
        p.Context(style: p.Style.windows).join(executableDir, 'ffmpeg.exe'),
      ];
    }
    if (isLinux) {
      final join = p.Context(style: p.Style.posix).join;
      return [
        join(executableDir, 'ffmpeg'),
        join(executableDir, 'lib', 'ffmpeg'),
      ];
    }
    return const [];
  }

  /// Test seam: clears the memoized resolution so the next call re-probes.
  @visibleForTesting
  static void debugResetFfmpegExecutableCache() {
    _resolvedFuture = null;
  }

  /// Path for local `file:` URIs; otherwise returns [mediaSourceUri] (e.g. https).
  static String mediaInputForFfmpeg(String mediaSourceUri) {
    final uri = Uri.tryParse(mediaSourceUri);
    if (uri != null && uri.isScheme('file')) {
      return uri.toFilePath(windows: Platform.isWindows);
    }
    return mediaSourceUri;
  }

  /// `Duration: HH:MM:SS.xx` from ffmpeg identify stderr.
  static int? parseDurationSeconds(String stderr) {
    final m = RegExp(
      r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)',
    ).firstMatch(stderr);
    if (m == null) return null;
    return tryParseHmsDuration(
      '${m.group(1)!}:${m.group(2)!}:${m.group(3)!}.${m.group(4)!}',
    )?.inSeconds;
  }

  /// ffmpeg stderr lines, e.g.
  /// `Stream #0:3(eng): Subtitle: subrip` or
  /// `Stream #0:3[0x1200](eng): Subtitle: hdmv_pgs_subtitle`.
  static final _subtitleStreamLine = RegExp(
    r'Stream #0:\d+(?:\[[^\]]*\])?(?:\(([^)]*)\))?\s*:\s*Subtitle\s*:',
    caseSensitive: false,
    multiLine: true,
  );

  /// Number of subtitle streams, in `0:s:N` order.
  static int countSubtitleStreams(String stderr) =>
      _subtitleStreamLine.allMatches(stderr).length;

  /// Optional language tags from parentheses, same order as [countSubtitleStreams].
  static List<String?> subtitleLanguageHints(String stderr) =>
      _subtitleStreamLine.allMatches(stderr).map((m) {
        final raw = m.group(1)?.trim();
        if (raw == null || raw.isEmpty) return null;
        final lower = raw.toLowerCase();
        if (lower == 'und' || lower == 'unknown') return null;
        return lower;
      }).toList();

  static Future<String?> loadIdentifyStderr(
    String ffmpegExecutable,
    String input,
  ) async {
    try {
      final r = await Process.run(ffmpegExecutable, [
        '-hide_banner',
        '-i',
        input,
      ], stderrEncoding: utf8);
      return r.stderr as String?;
    } on Object catch (_) {
      return null;
    }
  }
}

/// Quote [path] for safe inclusion in an FFmpeg filter-graph / CLI argument
/// embedded inside a larger string. Paths with whitespace or `"` are wrapped
/// in double quotes and any embedded `"` is backslash-escaped; everything else
/// is returned unchanged. Used by all FFmpegKit filter-string sites
/// (ASR extraction, Azure WAV normalisation, echo PCM extraction, video poster).
String shellEscape(String path) {
  if (path.contains(' ') || path.contains('"')) {
    return '"${path.replaceAll('"', r'\"')}"';
  }
  return path;
}
