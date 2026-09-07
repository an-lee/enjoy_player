/// The machinery seam behind `TranscriptEnricher`: audio decoding, forced
/// alignment, phonemization, and HTTP media download.
library;

import 'package:flutter/foundation.dart';
import 'package:forced_alignment/forced_alignment.dart';

/// External machinery the transcript enricher drives during an enrich run.
///
/// Two adapters satisfy this port: the production
/// `ForcedAlignmentEnrichmentBackend` (ffmpeg PCM decode + the
/// `forced_alignment` engine + HTTP download) and an in-memory test fake.
abstract interface class EnrichmentBackend {
  /// Decodes a whole local file or URI to 16 kHz mono float PCM.
  Future<Float32List> decodeFile(String pathOrUri);

  /// Decodes one `[startSeconds, startSeconds + durationSeconds)` window.
  Future<Float32List> decodeWindow({
    required String pathOrUri,
    required double startSeconds,
    required double durationSeconds,
  });

  /// Aligns pre-timed cue segments against the whole-clip PCM.
  Future<AlignmentOutcome> alignSegments({
    required Float32List sourcePcm16k,
    required String language,
    required List<AlignmentSegment> segments,
    AlignmentCancelToken? cancel,
  });

  /// Aligns one cue transcript against its padded PCM window.
  Future<AlignmentOutcome> align({
    required Float32List sourcePcm16k,
    required String transcript,
    required String language,
    AlignmentCancelToken? cancel,
    required double timeOffset,
  });

  /// Untimed IPA phonemization (the YouTube path).
  Future<PhonemizeOutcome> phonemize({
    required List<String> texts,
    required String language,
    AlignmentCancelToken? cancel,
  });

  /// Downloads remote media to a local temp path; the enricher deletes it.
  Future<String> downloadHttp(String url, {AlignmentCancelToken? cancel});
}
