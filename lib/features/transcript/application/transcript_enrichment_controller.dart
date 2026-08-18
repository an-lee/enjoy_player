/// Explicit CC-sheet enrich: owned align or YouTube IPA-only phonemize.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/audio/pcm16k_mono.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/media_target_resolver.dart';
import 'package:enjoy_player/data/subtitle/alignment_language.dart';
import 'package:enjoy_player/data/subtitle/attach_alignment_to_lines.dart';
import 'package:enjoy_player/data/subtitle/attach_phonemes_to_lines.dart';
import 'package:enjoy_player/data/subtitle/subtitle_markup_parser.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:enjoy_player/features/transcript/application/transcript_repository_provider.dart';

part 'transcript_enrichment_controller.g.dart';

enum TranscriptEnrichmentPhase { idle, running, failed, succeeded }

@immutable
class TranscriptEnrichmentState {
  const TranscriptEnrichmentState({required this.phase, this.failureReason});

  const TranscriptEnrichmentState.idle()
    : phase = TranscriptEnrichmentPhase.idle,
      failureReason = null;

  const TranscriptEnrichmentState.running()
    : phase = TranscriptEnrichmentPhase.running,
      failureReason = null;

  const TranscriptEnrichmentState.succeeded()
    : phase = TranscriptEnrichmentPhase.succeeded,
      failureReason = null;

  const TranscriptEnrichmentState.failed(this.failureReason)
    : phase = TranscriptEnrichmentPhase.failed;

  final TranscriptEnrichmentPhase phase;
  final String? failureReason;

  bool get isRunning => phase == TranscriptEnrichmentPhase.running;
  bool get isFailed => phase == TranscriptEnrichmentPhase.failed;
}

typedef DecodeFilePcm16k = Future<Float32List> Function(String pathOrUri);

typedef DecodeFileWindowPcm16k =
    Future<Float32List> Function({
      required String pathOrUri,
      required double startSeconds,
      required double durationSeconds,
    });

typedef AlignSegmentsFn =
    Future<AlignmentOutcome> Function({
      required Float32List sourcePcm16k,
      required String language,
      required List<AlignmentSegment> segments,
      required AlignmentGranularity granularity,
      AlignmentCancelToken? cancel,
    });

typedef AlignFn =
    Future<AlignmentOutcome> Function({
      required Float32List sourcePcm16k,
      required String transcript,
      required String language,
      AlignmentCancelToken? cancel,
      required double timeOffset,
    });

typedef PhonemizeLinesFn =
    Future<PhonemizeOutcome> Function({
      required List<String> texts,
      required String language,
      AlignmentCancelToken? cancel,
    });

typedef ReplaceTimelineFn =
    Future<bool> Function({
      required String transcriptId,
      required List<TranscriptLine> lines,
    });

sealed class TranscriptEnrichmentOutcome {
  const TranscriptEnrichmentOutcome();
}

final class TranscriptEnrichmentOk extends TranscriptEnrichmentOutcome {
  const TranscriptEnrichmentOk(this.lines);

  final List<TranscriptLine> lines;
}

final class TranscriptEnrichmentErr extends TranscriptEnrichmentOutcome {
  const TranscriptEnrichmentErr(this.reason);

  final String reason;
}

/// Injectable owned-align / YouTube-phonemize worker. No work until [enrich].
final class TranscriptEnricher {
  TranscriptEnricher({
    required this.replaceTimeline,
    DecodeFilePcm16k? decodeFile,
    DecodeFileWindowPcm16k? decodeWindow,
    AlignSegmentsFn? alignSegmentsFn,
    AlignFn? alignFn,
    PhonemizeLinesFn? phonemizeFn,
  }) : _decodeFile = decodeFile ?? decodeFileToPcm16kMono,
       _decodeWindow = decodeWindow ?? decodeFileWindowToPcm16kMono,
       _alignSegments = alignSegmentsFn ?? _productionAlignSegments,
       _align = alignFn ?? _productionAlign,
       _phonemize = phonemizeFn ?? _productionPhonemize;

  final ReplaceTimelineFn replaceTimeline;
  final DecodeFilePcm16k _decodeFile;
  final DecodeFileWindowPcm16k _decodeWindow;
  final AlignSegmentsFn _alignSegments;
  final AlignFn _align;
  final PhonemizeLinesFn _phonemize;

  /// Owned media: timed words + phones. YouTube / remote: untimed IPA labels.
  Future<TranscriptEnrichmentOutcome> enrich({
    required String transcriptId,
    required List<TranscriptLine> lines,
    required String language,
    required bool extractable,
    String? localPath,
    AlignmentCancelToken? cancel,
  }) async {
    if (lines.isEmpty) {
      return const TranscriptEnrichmentErr('empty');
    }
    final alignmentLanguage = alignmentLanguageForTranscript(language);
    logNamed('transcript.enrichment').info(
      'enrich start id=$transcriptId lang=$language '
      'mapped=$alignmentLanguage extractable=$extractable lines=${lines.length}',
    );
    if (alignmentLanguage == null) {
      logNamed(
        'transcript.enrichment',
      ).warning('enrich failed: unsupportedLanguage lang=$language');
      return const TranscriptEnrichmentErr('unsupportedLanguage');
    }
    if (cancel?.isCancelled ?? false) {
      return const TranscriptEnrichmentErr('cancelled');
    }

    if (!extractable) {
      return _enrichPhonemes(
        transcriptId: transcriptId,
        lines: lines,
        language: alignmentLanguage,
        cancel: cancel,
      );
    }
    if (localPath == null || localPath.isEmpty || _looksRemote(localPath)) {
      return const TranscriptEnrichmentErr('audioUnavailable');
    }
    return _enrichOwned(
      transcriptId: transcriptId,
      lines: lines,
      language: alignmentLanguage,
      localPath: localPath,
      cancel: cancel,
    );
  }

  Future<TranscriptEnrichmentOutcome> _enrichPhonemes({
    required String transcriptId,
    required List<TranscriptLine> lines,
    required String language,
    AlignmentCancelToken? cancel,
  }) async {
    late final PhonemizeOutcome outcome;
    try {
      outcome = await _phonemize(
        texts: [
          for (final line in lines) plainTextFromSubtitleMarkup(line.text),
        ],
        language: language,
        cancel: cancel,
      );
    } on Object catch (e, st) {
      logNamed('transcript.enrichment').warning('phonemize threw: $e', e, st);
      return const TranscriptEnrichmentErr('internal');
    }
    if (cancel?.isCancelled ?? false) {
      return const TranscriptEnrichmentErr('cancelled');
    }
    switch (outcome) {
      case PhonemizeFailed(:final failure):
        logNamed(
          'transcript.enrichment',
        ).warning('phonemize failed: ${failure.reason.name}');
        return TranscriptEnrichmentErr(failure.reason.name);
      case PhonemizeSuccess(lines: final phonemeLines):
        try {
          final attached = attachPhonemesToLines(lines, phonemeLines);
          return await _persistIfChanged(
            transcriptId: transcriptId,
            original: lines,
            attached: attached,
            cancel: cancel,
          );
        } on Object catch (e, st) {
          logNamed(
            'transcript.enrichment',
          ).warning('phoneme mapping failed: $e', e, st);
          return const TranscriptEnrichmentErr('internal');
        }
    }
  }

  Future<TranscriptEnrichmentOutcome> _enrichOwned({
    required String transcriptId,
    required List<TranscriptLine> lines,
    required String language,
    required String localPath,
    AlignmentCancelToken? cancel,
  }) async {
    final lastEnd = lines
        .map((l) => l.endSeconds)
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (lastEnd <= kMaxWholeClipSeconds) {
      return _enrichWholeFile(
        transcriptId: transcriptId,
        lines: lines,
        language: language,
        localPath: localPath,
        cancel: cancel,
      );
    }
    return _enrichWindows(
      transcriptId: transcriptId,
      lines: lines,
      language: language,
      localPath: localPath,
      cancel: cancel,
    );
  }

  Future<TranscriptEnrichmentOutcome> _enrichWholeFile({
    required String transcriptId,
    required List<TranscriptLine> lines,
    required String language,
    required String localPath,
    AlignmentCancelToken? cancel,
  }) async {
    late final Float32List pcm;
    try {
      pcm = await _decodeFile(localPath);
    } on Object catch (e, st) {
      logNamed(
        'transcript.enrichment',
      ).warning('PCM extract failed: $e', e, st);
      return const TranscriptEnrichmentErr('audioUnavailable');
    }
    if (pcm.isEmpty) {
      return const TranscriptEnrichmentErr('audioUnavailable');
    }
    if (cancel?.isCancelled ?? false) {
      return const TranscriptEnrichmentErr('cancelled');
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
        language: language,
        segments: segments,
        granularity: AlignmentGranularity.medium,
        cancel: cancel,
      );
    } on Object catch (e, st) {
      logNamed(
        'transcript.enrichment',
      ).warning('alignSegments threw: $e', e, st);
      return const TranscriptEnrichmentErr('internal');
    }
    if (cancel?.isCancelled ?? false) {
      return const TranscriptEnrichmentErr('cancelled');
    }
    switch (outcome) {
      case AlignmentFailed(:final failure):
        return TranscriptEnrichmentErr(failure.reason.name);
      case AlignmentSuccess(:final result):
        try {
          final attached = attachAlignmentToLines(lines, result);
          return await _persistIfChanged(
            transcriptId: transcriptId,
            original: lines,
            attached: attached,
            cancel: cancel,
          );
        } on Object catch (e, st) {
          logNamed(
            'transcript.enrichment',
          ).warning('alignment mapping failed: $e', e, st);
          return const TranscriptEnrichmentErr('internal');
        }
    }
  }

  Future<TranscriptEnrichmentOutcome> _enrichWindows({
    required String transcriptId,
    required List<TranscriptLine> lines,
    required String language,
    required String localPath,
    AlignmentCancelToken? cancel,
  }) async {
    final segments = <TimelineEntry>[];
    for (var i = 0; i < lines.length; i++) {
      if (cancel?.isCancelled ?? false) {
        return const TranscriptEnrichmentErr('cancelled');
      }
      final line = lines[i];
      if (line.text.trim().isEmpty) continue;
      final start = math.max(0.0, line.startSeconds - kCuePadSeconds);
      final duration =
          (line.endSeconds - line.startSeconds) + (2 * kCuePadSeconds);
      late final Float32List pcm;
      try {
        pcm = await _decodeWindow(
          pathOrUri: localPath,
          startSeconds: start,
          durationSeconds: duration <= 0 ? kMinAudioSeconds : duration,
        );
      } on Object catch (e, st) {
        logNamed(
          'transcript.enrichment',
        ).warning('window extract failed for cue $i: $e', e, st);
        continue;
      }
      if (pcm.isEmpty) continue;

      late final AlignmentOutcome outcome;
      try {
        outcome = await _align(
          sourcePcm16k: pcm,
          transcript: line.text,
          language: language,
          cancel: cancel,
          timeOffset: start,
        );
      } on Object catch (e, st) {
        logNamed(
          'transcript.enrichment',
        ).warning('align threw for cue $i: $e', e, st);
        continue;
      }
      switch (outcome) {
        case AlignmentFailed():
          continue;
        case AlignmentSuccess(:final result):
          final tagged = result.timeline.where(
            (e) => e.type == TimelineEntryType.segment,
          );
          if (tagged.isEmpty) {
            segments.add(
              TimelineEntry(
                type: TimelineEntryType.segment,
                text: line.text,
                startTime: line.startSeconds,
                endTime: line.endSeconds,
                id: i,
                timeline: result.wordTimeline,
              ),
            );
          } else {
            segments.add(tagged.first.copyWithId(i));
          }
      }
    }

    if (segments.isEmpty) {
      return const TranscriptEnrichmentErr('internal');
    }
    final attached = attachAlignmentToLines(
      lines,
      AlignmentResult(
        timeline: segments,
        wordTimeline: const [],
        transcript: lines.map((l) => l.text).join(' '),
        language: language,
        durationSeconds: lines.last.endSeconds,
      ),
    );
    return _persistIfChanged(
      transcriptId: transcriptId,
      original: lines,
      attached: attached,
      cancel: cancel,
    );
  }

  Future<TranscriptEnrichmentOutcome> _persistIfChanged({
    required String transcriptId,
    required List<TranscriptLine> original,
    required List<TranscriptLine> attached,
    AlignmentCancelToken? cancel,
  }) async {
    if (attached.length != original.length) {
      return const TranscriptEnrichmentErr('line count changed');
    }
    final anyNested = attached.any(
      (line) => line.timeline != null && line.timeline!.isNotEmpty,
    );
    if (!anyNested) {
      logNamed(
        'transcript.enrichment',
      ).warning('enrich failed: noNestedWords id=$transcriptId');
      return const TranscriptEnrichmentErr('noNestedWords');
    }
    if (cancel?.isCancelled ?? false) {
      return const TranscriptEnrichmentErr('cancelled');
    }
    final ok = await replaceTimeline(
      transcriptId: transcriptId,
      lines: attached,
    );
    if (!ok) return const TranscriptEnrichmentErr('missingRow');
    return TranscriptEnrichmentOk(attached);
  }
}

bool _looksRemote(String pathOrUri) {
  final uri = Uri.tryParse(pathOrUri);
  if (uri == null) return false;
  return uri.isScheme('http') || uri.isScheme('https');
}

extension on TimelineEntry {
  TimelineEntry copyWithId(int id) {
    return TimelineEntry(
      type: type,
      text: text,
      startTime: startTime,
      endTime: endTime,
      timeline: timeline,
      confidence: confidence,
      id: id,
    );
  }
}

Future<AlignmentOutcome> _productionAlignSegments({
  required Float32List sourcePcm16k,
  required String language,
  required List<AlignmentSegment> segments,
  required AlignmentGranularity granularity,
  AlignmentCancelToken? cancel,
}) {
  return alignSegments(
    sourcePcm16k: sourcePcm16k,
    language: language,
    segments: segments,
    granularity: granularity,
    cancel: cancel,
  );
}

Future<AlignmentOutcome> _productionAlign({
  required Float32List sourcePcm16k,
  required String transcript,
  required String language,
  AlignmentCancelToken? cancel,
  required double timeOffset,
}) {
  return align(
    sourcePcm16k: sourcePcm16k,
    transcript: transcript,
    language: language,
    cancel: cancel,
    timeOffset: timeOffset,
  );
}

Future<PhonemizeOutcome> _productionPhonemize({
  required List<String> texts,
  required String language,
  AlignmentCancelToken? cancel,
}) {
  return phonemizeLines(texts: texts, language: language, cancel: cancel);
}

@Riverpod(keepAlive: true)
TranscriptEnricher transcriptEnricher(Ref ref) {
  final repo = ref.watch(transcriptRepositoryProvider);
  return TranscriptEnricher(
    replaceTimeline: ({required transcriptId, required lines}) {
      return repo.replaceTimeline(transcriptId: transcriptId, lines: lines);
    },
  );
}

@Riverpod(keepAlive: true)
class TranscriptEnrichmentController extends _$TranscriptEnrichmentController {
  AlignmentCancelToken? _cancel;
  var _runId = 0;

  @override
  TranscriptEnrichmentState build(String mediaId) {
    return const TranscriptEnrichmentState.idle();
  }

  /// Starts enrich for the current primary track. Opening the sheet / play /
  /// seek must not call this.
  Future<void> run() async {
    if (state.isRunning) return;
    _cancel?.cancel();
    final token = AlignmentCancelToken();
    _cancel = token;
    final id = ++_runId;
    state = const TranscriptEnrichmentState.running();

    try {
      final repo = ref.read(transcriptRepositoryProvider);
      final row = await repo.primaryTranscriptRowForMedia(mediaId);
      if (!ref.mounted || id != _runId) return;
      if (row == null) {
        state = const TranscriptEnrichmentState.failed('noPrimary');
        return;
      }
      final lines = repo.linesForRow(row);
      if (lines.isEmpty) {
        state = const TranscriptEnrichmentState.failed('empty');
        return;
      }

      final db = ref.read(appDatabaseProvider);
      final source = await resolvePlayableSource(db, mediaId);
      if (!ref.mounted || id != _runId) return;
      final extractable = source is LocalFilePlayableSource;
      final localPath = switch (source) {
        LocalFilePlayableSource(:final uri) => uri,
        _ => null,
      };

      final outcome = await ref
          .read(transcriptEnricherProvider)
          .enrich(
            transcriptId: row.id,
            lines: lines,
            language: row.language,
            extractable: extractable,
            localPath: localPath,
            cancel: token,
          );
      if (!ref.mounted || id != _runId) return;
      if (token.isCancelled) {
        state = const TranscriptEnrichmentState.failed('cancelled');
        return;
      }
      switch (outcome) {
        case TranscriptEnrichmentOk():
          state = const TranscriptEnrichmentState.succeeded();
        case TranscriptEnrichmentErr(:final reason):
          logNamed('transcript.enrichment').warning('run failed: $reason');
          state = TranscriptEnrichmentState.failed(reason);
      }
    } on Object catch (e, st) {
      logNamed('transcript.enrichment').warning('run failed: $e', e, st);
      if (!ref.mounted || id != _runId) return;
      state = const TranscriptEnrichmentState.failed('internal');
    }
  }

  void cancel() {
    _cancel?.cancel();
    _runId++;
    if (state.isRunning) {
      state = const TranscriptEnrichmentState.failed('cancelled');
    }
  }
}
