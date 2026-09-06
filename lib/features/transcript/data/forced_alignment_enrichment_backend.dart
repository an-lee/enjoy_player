/// Production `EnrichmentBackend`: ffmpeg PCM decode + the forced_alignment
/// engine + Dart HTTP download.
library;

import 'package:flutter/foundation.dart';
import 'package:forced_alignment/forced_alignment.dart'
    hide align, alignSegments;
import 'package:forced_alignment/forced_alignment.dart'
    as fa
    show align, alignSegments;

import 'package:enjoy_player/data/audio/http_media_download.dart';
import 'package:enjoy_player/data/audio/pcm16k_mono.dart';
import 'package:enjoy_player/features/transcript/domain/enrichment_backend.dart';

/// Verbatim delegation to the app's decode / alignment / download helpers.
///
/// Stateless — a single `const` instance serves every enrich run
/// (ADR-0071/0072 engine policy lives inside `forced_alignment`).
final class ForcedAlignmentEnrichmentBackend implements EnrichmentBackend {
  const ForcedAlignmentEnrichmentBackend();

  @override
  Future<Float32List> decodeFile(String pathOrUri) {
    return decodeFileToPcm16kMono(pathOrUri);
  }

  @override
  Future<Float32List> decodeWindow({
    required String pathOrUri,
    required double startSeconds,
    required double durationSeconds,
  }) {
    return decodeFileWindowToPcm16kMono(
      pathOrUri: pathOrUri,
      startSeconds: startSeconds,
      durationSeconds: durationSeconds,
    );
  }

  @override
  Future<AlignmentOutcome> alignSegments({
    required Float32List sourcePcm16k,
    required String language,
    required List<AlignmentSegment> segments,
    AlignmentCancelToken? cancel,
  }) {
    return fa.alignSegments(
      sourcePcm16k: sourcePcm16k,
      language: language,
      segments: segments,
      cancel: cancel,
    );
  }

  @override
  Future<AlignmentOutcome> align({
    required Float32List sourcePcm16k,
    required String transcript,
    required String language,
    AlignmentCancelToken? cancel,
    required double timeOffset,
  }) {
    return fa.align(
      sourcePcm16k: sourcePcm16k,
      transcript: transcript,
      language: language,
      cancel: cancel,
      timeOffset: timeOffset,
    );
  }

  @override
  Future<PhonemizeOutcome> phonemize({
    required List<String> texts,
    required String language,
    AlignmentCancelToken? cancel,
  }) {
    return phonemizeLines(texts: texts, language: language, cancel: cancel);
  }

  @override
  Future<String> downloadHttp(String url, {AlignmentCancelToken? cancel}) {
    return downloadHttpMediaToTemp(url, cancel: cancel);
  }
}
