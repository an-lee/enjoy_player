/// In-memory [EnrichmentBackend] test adapter: configurable hooks, call
/// counters, and a hard `fail()` for any unconfigured call.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

import 'package:enjoy_player/features/transcript/domain/enrichment_backend.dart';

typedef DecodeFileHook = Future<Float32List> Function(String pathOrUri);

typedef DecodeWindowHook =
    Future<Float32List> Function({
      required String pathOrUri,
      required double startSeconds,
      required double durationSeconds,
    });

typedef AlignSegmentsHook =
    Future<AlignmentOutcome> Function({
      required Float32List sourcePcm16k,
      required String language,
      required List<AlignmentSegment> segments,
      AlignmentCancelToken? cancel,
    });

typedef AlignHook =
    Future<AlignmentOutcome> Function({
      required Float32List sourcePcm16k,
      required String transcript,
      required String language,
      AlignmentCancelToken? cancel,
      required double timeOffset,
    });

typedef PhonemizeHook =
    Future<PhonemizeOutcome> Function({
      required List<String> texts,
      required String language,
      AlignmentCancelToken? cancel,
    });

typedef DownloadHttpHook =
    Future<String> Function(String url, {AlignmentCancelToken? cancel});

class FakeEnrichmentBackend implements EnrichmentBackend {
  DecodeFileHook? decodeFileFn;
  DecodeWindowHook? decodeWindowFn;
  AlignSegmentsHook? alignSegmentsFn;
  AlignHook? alignFn;
  PhonemizeHook? phonemizeFn;
  DownloadHttpHook? downloadHttpFn;

  int decodeFileCalls = 0;
  int decodeWindowCalls = 0;
  int alignSegmentsCalls = 0;
  int alignCalls = 0;
  int phonemizeCalls = 0;
  int downloadHttpCalls = 0;

  @override
  Future<Float32List> decodeFile(String pathOrUri) {
    decodeFileCalls++;
    final fn = decodeFileFn;
    if (fn == null) fail('FakeEnrichmentBackend.decodeFile not configured');
    return fn(pathOrUri);
  }

  @override
  Future<Float32List> decodeWindow({
    required String pathOrUri,
    required double startSeconds,
    required double durationSeconds,
  }) {
    decodeWindowCalls++;
    final fn = decodeWindowFn;
    if (fn == null) fail('FakeEnrichmentBackend.decodeWindow not configured');
    return fn(
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
    alignSegmentsCalls++;
    final fn = alignSegmentsFn;
    if (fn == null) {
      fail('FakeEnrichmentBackend.alignSegments not configured');
    }
    return fn(
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
    alignCalls++;
    final fn = alignFn;
    if (fn == null) fail('FakeEnrichmentBackend.align not configured');
    return fn(
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
    phonemizeCalls++;
    final fn = phonemizeFn;
    if (fn == null) fail('FakeEnrichmentBackend.phonemize not configured');
    return fn(texts: texts, language: language, cancel: cancel);
  }

  @override
  Future<String> downloadHttp(String url, {AlignmentCancelToken? cancel}) {
    downloadHttpCalls++;
    final fn = downloadHttpFn;
    if (fn == null) fail('FakeEnrichmentBackend.downloadHttp not configured');
    return fn(url, cancel: cancel);
  }
}
