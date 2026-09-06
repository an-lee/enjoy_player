/// Extracts embedded subtitle tracks from a media file using ffmpeg.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:media_kit/media_kit.dart' show SubtitleTrack;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/ids/enjoy_ids.dart';
import '../../core/logging/log.dart';
import '../db/app_database.dart';
import '../files/ffmpeg_media_probe.dart';
import 'subtitle_parser.dart';
import 'transcript_line.dart';

class EmbeddedSubtitleService {
  const EmbeddedSubtitleService();

  static final _log = logNamed('EmbeddedSubtitleService');

  /// Extracts text lines from [mediaSourceUri] for each [SubtitleTrack] that
  /// is embedded (not loaded from an external URI / data string).
  ///
  /// When [tracks] is empty, discovers subtitle streams from `ffmpeg -i`
  /// stderr (same order as `-map 0:s:N`). Use this when `media_kit` has not
  /// enumerated subtitles yet (e.g. duration still unknown).
  ///
  /// Already-imported embedded tracks can be excluded by passing their
  /// [existingTrackIndices] so we don't re-extract unchanged tracks.
  ///
  /// At most one row per distinct [language] in this batch (first stream wins),
  /// except probe-only paths may use `lang-2` disambiguation when ffmpeg tags
  /// duplicate or missing languages.
  ///
  /// Rows use `source: user` for parity with file imports.
  Future<List<TranscriptRow>> extractTracks({
    required String targetId,
    required String targetTypeDexie,
    required String mediaSourceUri,
    required List<SubtitleTrack> tracks,
    Set<int> existingTrackIndices = const {},
  }) async {
    final mediaInput = FfmpegMediaProbe.mediaInputForFfmpeg(mediaSourceUri);

    // `media_kit` can list subtitle pickers (or timing-only entries) even when the
    // container has no muxed `0:s:N` streams. FFmpeg then fails with
    // "Stream map '0:s:0' matches no streams". Treat FFprobe as source of truth.
    List<({String? language})>? nonWindowsSubtitleProbe;
    if (!Platform.isWindows) {
      nonWindowsSubtitleProbe = await _probeSubtitleStreams(mediaInput);
      if (nonWindowsSubtitleProbe.isEmpty) {
        if (tracks.isNotEmpty) {
          _log.fine(
            'Embedded extract skipped: container has no subtitle streams '
            '(${tracks.length} media_kit subtitle entries ignored)',
          );
        }
        return const [];
      }
    }

    if (tracks.isEmpty) {
      return _extractTracksViaFfmpegProbe(
        targetId: targetId,
        targetTypeDexie: targetTypeDexie,
        mediaInput: mediaInput,
        existingTrackIndices: existingTrackIndices,
        subtitleStreams: nonWindowsSubtitleProbe,
      );
    }

    final ffmpegExe = await FfmpegMediaProbe.resolveFfmpegExecutable();
    if (Platform.isWindows && ffmpegExe == null) {
      _log.fine(
        'Embedded subtitle extraction skipped on Windows: '
        'no ffmpeg.exe next to the app and no ffmpeg on PATH',
      );
      return const [];
    }

    final results = <TranscriptRow>[];
    final seenLanguages = <String>{};

    /// `media_kit` prepends [auto] and [no] entries; `-map 0:s:N` is N-th
    /// **subtitle** stream in the file (0-based), not the list index.
    var ffmpegSubtitleOrdinal = 0;
    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      if (track.id == 'auto' || track.id == 'no') continue;
      if (track.uri || track.data) continue;
      if (existingTrackIndices.contains(ffmpegSubtitleOrdinal)) {
        ffmpegSubtitleOrdinal++;
        continue;
      }

      final srtText = Platform.isWindows
          ? await _extractTrackAsSrtProcess(
              ffmpegExe!,
              mediaInput,
              ffmpegSubtitleOrdinal,
            )
          : await _extractTrackAsSrtFfmpegKit(
              mediaInput,
              ffmpegSubtitleOrdinal,
            );
      if (srtText == null || srtText.trim().isEmpty) {
        ffmpegSubtitleOrdinal++;
        continue;
      }

      final lines = _parseExtractedSrt(srtText);
      if (lines.isEmpty) {
        ffmpegSubtitleOrdinal++;
        continue;
      }

      final language = track.language ?? 'und';
      if (!seenLanguages.add(language)) {
        ffmpegSubtitleOrdinal++;
        continue;
      }

      final label = trackLabelFromParts(track.title, track.language, i);
      results.add(
        rowForExtracted(
          targetId: targetId,
          targetTypeDexie: targetTypeDexie,
          language: language,
          label: label,
          trackIndex: ffmpegSubtitleOrdinal,
          lines: lines,
        ),
      );
      ffmpegSubtitleOrdinal++;
    }

    if (results.isEmpty) {
      return _extractTracksViaFfmpegProbe(
        targetId: targetId,
        targetTypeDexie: targetTypeDexie,
        mediaInput: mediaInput,
        existingTrackIndices: existingTrackIndices,
        subtitleStreams: nonWindowsSubtitleProbe,
      );
    }
    return results;
  }

  Future<List<TranscriptRow>> _extractTracksViaFfmpegProbe({
    required String targetId,
    required String targetTypeDexie,
    required String mediaInput,
    required Set<int> existingTrackIndices,
    List<({String? language})>? subtitleStreams,
  }) async {
    final probe = subtitleStreams ?? await _probeSubtitleStreams(mediaInput);
    if (probe.isEmpty) return const [];

    final ffmpegExe = await FfmpegMediaProbe.resolveFfmpegExecutable();
    if (Platform.isWindows && ffmpegExe == null) {
      _log.fine(
        'Embedded subtitle probe skipped on Windows: '
        'no ffmpeg.exe next to the app and no ffmpeg on PATH',
      );
      return const [];
    }

    final results = <TranscriptRow>[];
    final seenLanguages = <String>{};

    for (var i = 0; i < probe.length; i++) {
      if (existingTrackIndices.contains(i)) continue;

      final srtText = Platform.isWindows
          ? await _extractTrackAsSrtProcess(ffmpegExe!, mediaInput, i)
          : await _extractTrackAsSrtFfmpegKit(mediaInput, i);
      if (srtText == null || srtText.trim().isEmpty) {
        _log.warning('Embedded subtitle stream $i produced no SRT text');
        continue;
      }

      final cleaned = SubtitleParserFacade.stripAssTags(srtText);
      final lines = _parseExtractedSrt(srtText);
      if (lines.isEmpty) {
        final preview = cleaned.length > 500
            ? cleaned.substring(0, 500)
            : cleaned;
        _log.warning(
          'Embedded subtitle stream $i parsed to 0 cues. Preview: $preview',
        );
        continue;
      }

      var language = probe[i].language ?? 'und';
      language = allocateLanguageCode(language, seenLanguages);

      final label = trackLabelFromParts(
        null,
        language == 'und' ? null : language,
        i,
      );
      results.add(
        rowForExtracted(
          targetId: targetId,
          targetTypeDexie: targetTypeDexie,
          language: language,
          label: label,
          trackIndex: i,
          lines: lines,
        ),
      );
    }
    return results;
  }

  /// Shared extract tail: strip ASS/SSA override tags and parse the SRT text.
  List<TranscriptLine> _parseExtractedSrt(String srtText) {
    final cleaned = SubtitleParserFacade.stripAssTags(srtText);
    return const SubtitleParserFacade().parseWithHint(
      cleaned,
      fileName: 'track.srt',
    );
  }

  Future<List<({String? language})>> _probeSubtitleStreams(
    String mediaInput,
  ) async {
    if (Platform.isWindows) {
      final stderr = await _loadFfmpegIdentifyStderr(mediaInput);
      if (stderr == null || stderr.isEmpty) return const [];
      final hints = FfmpegMediaProbe.subtitleLanguageHints(stderr);
      return List.generate(
        FfmpegMediaProbe.countSubtitleStreams(stderr),
        (i) => (language: i < hints.length ? hints[i] : null),
      );
    }

    try {
      final session = await FFprobeKit.getMediaInformation(mediaInput);
      final mediaInformation = session.getMediaInformation();
      if (mediaInformation == null) {
        _log.warning(
          'Embedded subtitle probe failed: ${await session.getOutput()}',
        );
        return const [];
      }
      final streams = mediaInformation.getStreams();
      final subtitleStreams = streams
          .where((s) => s.getType() == 'subtitle')
          .toList();
      if (subtitleStreams.isEmpty) {
        final types = streams.map((s) => s.getType() ?? 'unknown').join(', ');
        _log.fine(
          'Embedded subtitle probe: 0 subtitle streams (container has [$types])',
        );
      }
      return subtitleStreams.map((s) {
        final tags = s.getTags();
        final raw = tags?['language']?.toString().trim().toLowerCase();
        final language =
            raw == null || raw.isEmpty || raw == 'und' || raw == 'unknown'
            ? null
            : raw;
        return (language: language);
      }).toList();
    } on Object catch (e, st) {
      _log.warning('FFprobe subtitle probe failed', e, st);
      return const [];
    }
  }

  /// Reserves a unique language key for [enjoyTranscriptId] (mutates [used]).
  @visibleForTesting
  static String allocateLanguageCode(String language, Set<String> used) {
    var base = language.isEmpty ? 'und' : language;
    if (!used.contains(base)) {
      used.add(base);
      return base;
    }
    var k = 2;
    while (used.contains('$base-$k')) {
      k++;
    }
    final out = '$base-$k';
    used.add(out);
    return out;
  }

  static Future<String?> _loadFfmpegIdentifyStderr(String mediaInput) async {
    final ffmpegExe = await FfmpegMediaProbe.resolveFfmpegExecutable();
    if (ffmpegExe != null) {
      return FfmpegMediaProbe.loadIdentifyStderr(ffmpegExe, mediaInput);
    }
    if (!Platform.isWindows) {
      try {
        final session = await FFmpegKit.execute(
          '-hide_banner -i "$mediaInput"',
        );
        final logs = await session.getLogs();
        return logs.map((l) => l.getMessage()).join('\n');
      } on Object catch (e, st) {
        _log.fine('FFmpegKit identify failed', e, st);
      }
    }
    return null;
  }

  @visibleForTesting
  static TranscriptRow rowForExtracted({
    required String targetId,
    required String targetTypeDexie,
    required String language,
    required String label,
    required int trackIndex,
    required List<TranscriptLine> lines,
  }) {
    final json = jsonEncode(lines.map((e) => e.toJson()).toList());
    final now = DateTime.now();
    const source = 'user';
    final id = enjoyTranscriptId(
      targetType: targetTypeDexie,
      targetId: targetId,
      language: language,
      source: source,
    );
    return TranscriptRow(
      id: id,
      targetType: targetTypeDexie,
      targetId: targetId,
      language: language,
      source: source,
      timelineJson: json,
      referenceId: 'embedded:$trackIndex',
      label: label,
      trackIndex: trackIndex,
      syncStatus: 'local',
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<String?> _extractTrackAsSrtProcess(
    String ffmpegExecutable,
    String filePath,
    int streamIndex,
  ) async {
    try {
      final result = await Process.run(
        ffmpegExecutable,
        ['-i', filePath, '-map', '0:s:$streamIndex', '-f', 'srt', '-'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) {
        _log.fine(
          'ffmpeg subtitle extract failed (stream $streamIndex, exit ${result.exitCode}): '
          '${result.stderr}',
        );
        return null;
      }
      return result.stdout as String;
    } on Object catch (error, stackTrace) {
      _log.warning(
        'Embedded subtitle extraction failed for stream $streamIndex',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// FFmpegKit [Session.getOutput] is log text, not process stdout; `-f srt -`
  /// would be lost on Android/iOS. Write to a temp file and read it back.
  Future<String?> _extractTrackAsSrtFfmpegKit(
    String filePath,
    int streamIndex,
  ) async {
    final tmpDir = await getTemporaryDirectory();
    // macOS sandbox: path_provider may return a bundle-specific subfolder that
    // does not exist until created (ffmpeg then fails to open the output path).
    if (!await tmpDir.exists()) {
      await tmpDir.create(recursive: true);
    }
    final outPath = p.join(
      tmpDir.path,
      'enjoy_subs_${DateTime.now().microsecondsSinceEpoch}_$streamIndex.srt',
    );
    try {
      final session = await FFmpegKit.executeWithArguments([
        '-hide_banner',
        '-y',
        '-i',
        filePath,
        '-map',
        '0:s:$streamIndex',
        '-f',
        'srt',
        outPath,
      ]);
      final code = await session.getReturnCode();
      if (!ReturnCode.isSuccess(code)) {
        _log.warning(
          'ffmpeg subtitle extract failed (stream $streamIndex): '
          '${await session.getOutput()}',
        );
        return null;
      }
      final f = File(outPath);
      if (!await f.exists() || await f.length() == 0) return null;
      return await f.readAsString(encoding: utf8);
    } on Object catch (error, stackTrace) {
      _log.warning(
        'Embedded subtitle extraction failed for stream $streamIndex',
        error,
        stackTrace,
      );
      return null;
    } finally {
      try {
        final f = File(outPath);
        if (await f.exists()) await f.delete();
      } on Object catch (_) {}
    }
  }

  @visibleForTesting
  static String trackLabelFromParts(
    String? title,
    String? language,
    int index,
  ) {
    final parts = <String>[];
    if (title != null && title.isNotEmpty) {
      parts.add(title);
    }
    if (language != null && language.isNotEmpty && language != 'und') {
      parts.add(language.toUpperCase());
    }
    if (parts.isEmpty) parts.add('Track ${index + 1}');
    return parts.join(' · ');
  }
}
