/// Craft-save hook: attach nested word/phone spans via alignSegments.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forced_alignment/forced_alignment.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/audio/pcm16k_mono.dart';
import 'package:enjoy_player/data/subtitle/alignment_language.dart';
import 'package:enjoy_player/data/subtitle/attach_alignment_to_lines.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';

typedef DecodePcm16k = Future<Float32List> Function(Uint8List bytes);

typedef AlignSegmentsFn =
    Future<AlignmentOutcome> Function({
      required Float32List sourcePcm16k,
      required String language,
      required List<AlignmentSegment> segments,
      required AlignmentGranularity granularity,
    });

/// Maps a Craft synth language onto an alignment catalog tag.
///
/// Delegates to [alignmentLanguageForTranscript].
String? alignmentLanguageForCraft(String language) =>
    alignmentLanguageForTranscript(language);

/// Extract + [alignSegments] + [attachAlignmentToLines] for Craft save.
///
/// Always attempts enrichment on a real Craft write. When [timelineJson] is
/// null or extract/alignment fails, returns the original spec 030 JSON
/// unchanged (fail-closed). Pass [enabled] `false` only in tests.
final class CraftTimelineEnricher {
  CraftTimelineEnricher({
    this.enabled = true,
    DecodePcm16k? decodePcm,
    AlignSegmentsFn? alignSegmentsFn,
  }) : _decodePcm = decodePcm ?? decodeToPcm16kMono,
       _alignSegments = alignSegmentsFn ?? _productionAlignSegments;

  /// Production is always on. Tests may pass `false` to skip alignment.
  final bool enabled;
  final DecodePcm16k _decodePcm;
  final AlignSegmentsFn _alignSegments;

  Future<String?> enrich({
    required String? timelineJson,
    required Uint8List audioBytes,
    required String language,
  }) async {
    if (!enabled) return timelineJson;
    if (timelineJson == null) return null;

    final lines = _decodeLines(timelineJson);
    if (lines == null) {
      return _fallback(timelineJson, 'invalid timeline JSON');
    }
    if (lines.isEmpty) {
      return _fallback(timelineJson, 'empty timeline JSON');
    }

    final alignmentLanguage = alignmentLanguageForCraft(language);
    if (alignmentLanguage == null) {
      return _fallback(timelineJson, 'unsupportedLanguage');
    }

    late final Float32List pcm;
    try {
      pcm = await _decodePcm(audioBytes);
    } on Object catch (e, st) {
      logNamed('craft.enrichment').warning('PCM extract failed: $e', e, st);
      return timelineJson;
    }
    if (pcm.isEmpty) {
      return _fallback(timelineJson, 'empty PCM');
    }

    final segments = [
      for (var i = 0; i < lines.length; i++)
        AlignmentSegment(
          text: lines[i].text,
          startTime: lines[i].startSeconds,
          endTime: lines[i].endSeconds,
          id: i,
        ),
    ];

    late final AlignmentOutcome outcome;
    try {
      outcome = await _alignSegments(
        sourcePcm16k: pcm,
        language: alignmentLanguage,
        segments: segments,
        granularity: AlignmentGranularity.medium,
      );
    } on Object catch (e, st) {
      logNamed('craft.enrichment').warning('alignSegments threw: $e', e, st);
      return timelineJson;
    }

    switch (outcome) {
      case AlignmentFailed(:final failure):
        return _fallback(timelineJson, failure.reason.name);
      case AlignmentSuccess(:final result):
        try {
          final attached = attachAlignmentToLines(lines, result);
          if (attached.length != lines.length) {
            return _fallback(timelineJson, 'line count changed');
          }
          return jsonEncode([for (final line in attached) line.toJson()]);
        } on Object catch (e, st) {
          logNamed('craft.enrichment').warning('mapping failed: $e', e, st);
          return timelineJson;
        }
    }
  }

  String _fallback(String original, String reason) {
    logNamed('craft.enrichment').warning('fallback: $reason');
    return original;
  }
}

List<TranscriptLine>? _decodeLines(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return null;
    return [
      for (final item in decoded)
        if (item is Map)
          TranscriptLine.fromJson(Map<String, dynamic>.from(item)),
    ];
  } on Object catch (_) {
    return null;
  }
}

Future<AlignmentOutcome> _productionAlignSegments({
  required Float32List sourcePcm16k,
  required String language,
  required List<AlignmentSegment> segments,
  required AlignmentGranularity granularity,
}) {
  return alignSegments(
    sourcePcm16k: sourcePcm16k,
    language: language,
    segments: segments,
    granularity: granularity,
  );
}

final craftTimelineEnricherProvider = Provider<CraftTimelineEnricher>((ref) {
  return CraftTimelineEnricher();
});
