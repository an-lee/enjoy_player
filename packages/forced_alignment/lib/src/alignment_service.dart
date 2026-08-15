import 'dart:typed_data';

import 'package:logging/logging.dart';

import 'alignment_isolate.dart';
import 'constants.dart';
import 'cue_window.dart';
import 'failures.dart';
import 'language_map.dart';
import 'outcome.dart';
import 'request.dart';
import 'types.dart';

final _log = Logger('forced_alignment');

double _durationSeconds(Float32List pcm) => pcm.length / kAlignmentSampleRate;

AlignmentFailed? _validateWholeClip(Float32List pcm, String transcript) {
  if (pcm.isEmpty) {
    return const AlignmentFailed(
      AlignmentFailure(reason: AlignmentFailureReason.audioUnavailable),
    );
  }
  final seconds = _durationSeconds(pcm);
  if (seconds < kMinAudioSeconds) {
    return const AlignmentFailed(
      AlignmentFailure(reason: AlignmentFailureReason.tooShort),
    );
  }
  if (seconds > kMaxWholeClipSeconds) {
    return const AlignmentFailed(
      AlignmentFailure(reason: AlignmentFailureReason.wholeClipTooLong),
    );
  }
  if (transcript.trim().isEmpty) {
    return const AlignmentFailed(
      AlignmentFailure(reason: AlignmentFailureReason.blankText),
    );
  }
  return null;
}

AlignmentFailed? _validateLanguage(String language) {
  if (!isSupportedAlignmentLanguage(language)) {
    return const AlignmentFailed(
      AlignmentFailure(reason: AlignmentFailureReason.unsupportedLanguage),
    );
  }
  return null;
}

Future<AlignmentOutcome> _runJob({
  required AlignIsolateJob job,
  required Duration timeout,
  AlignmentCancelToken? cancel,
}) async {
  if (cancel?.isCancelled ?? false) {
    return const AlignmentFailed(
      AlignmentFailure(reason: AlignmentFailureReason.cancelled),
    );
  }
  try {
    final raw = await runAlignJobInIsolate(
      job: job,
      cancel: cancel,
      timeout: timeout,
    );
    if (cancel?.isCancelled ?? false) {
      return const AlignmentFailed(
        AlignmentFailure(reason: AlignmentFailureReason.cancelled),
      );
    }
    if (raw is AlignmentFailure) {
      return AlignmentFailed(raw);
    }
    if (raw is AlignmentResult) {
      return AlignmentSuccess(raw);
    }
    return AlignmentFailed(
      AlignmentFailure(
        reason: AlignmentFailureReason.internal,
        message: 'unexpected isolate payload ${raw.runtimeType}',
      ),
    );
  } on IsolateTimeout {
    return const AlignmentFailed(
      AlignmentFailure(reason: AlignmentFailureReason.timedOut),
    );
  } on IsolateCancelled {
    return const AlignmentFailed(
      AlignmentFailure(reason: AlignmentFailureReason.cancelled),
    );
  } catch (e, st) {
    _log.warning('alignment job failed', e, st);
    return AlignmentFailed(
      AlignmentFailure(
        reason: AlignmentFailureReason.internal,
        message: e.toString(),
      ),
    );
  }
}

/// Whole-clip alignment. Source PCM must be 16 kHz mono Float32.
Future<AlignmentOutcome> align({
  required Float32List sourcePcm16k,
  required String transcript,
  required String language,
  AlignmentGranularity granularity = AlignmentGranularity.medium,
  Duration? timeout,
  AlignmentCancelToken? cancel,
}) async {
  final langFail = _validateLanguage(language);
  if (langFail != null) return langFail;
  final fail = _validateWholeClip(sourcePcm16k, transcript);
  if (fail != null) return fail;
  return _runJob(
    job: AlignIsolateJob(
      sourcePcm: sourcePcm16k,
      transcript: transcript,
      language: language,
      granularity: granularity,
    ),
    timeout: timeout ?? kDefaultWholeClipTimeout,
    cancel: cancel,
  );
}

/// Per-cue alignment. Multi-minute PCM is valid; each cue is sliced locally.
Future<AlignmentOutcome> alignSegments({
  required Float32List sourcePcm16k,
  required String language,
  required List<AlignmentSegment> segments,
  AlignmentGranularity granularity = AlignmentGranularity.medium,
  Duration? timeout,
  AlignmentCancelToken? cancel,
}) async {
  final langFail = _validateLanguage(language);
  if (langFail != null) return langFail;
  if (sourcePcm16k.isEmpty) {
    return const AlignmentFailed(
      AlignmentFailure(reason: AlignmentFailureReason.audioUnavailable),
    );
  }
  if (segments.isEmpty) {
    return const AlignmentFailed(
      AlignmentFailure(reason: AlignmentFailureReason.blankText),
    );
  }

  final cueTimeout = timeout ?? kDefaultPerCueTimeout;
  final successes = <TimelineEntry>[];
  AlignmentFailureReason? lastCueFailure;

  for (final segment in segments) {
    if (cancel?.isCancelled ?? false) {
      return const AlignmentFailed(
        AlignmentFailure(reason: AlignmentFailureReason.cancelled),
      );
    }
    final text = segment.text;
    if (text.trim().isEmpty) {
      lastCueFailure = AlignmentFailureReason.blankText;
      continue;
    }
    final window = segment.endTime - segment.startTime;
    if (window < kMinAudioSeconds) {
      lastCueFailure = AlignmentFailureReason.tooShort;
      continue;
    }
    final startSample = (segment.startTime * kAlignmentSampleRate)
        .floor()
        .clamp(0, sourcePcm16k.length);
    final endSample = (segment.endTime * kAlignmentSampleRate).ceil().clamp(
      startSample,
      sourcePcm16k.length,
    );
    if (endSample - startSample < kAlignmentSampleRate) {
      lastCueFailure = AlignmentFailureReason.tooShort;
      continue;
    }
    final slice = Float32List.sublistView(sourcePcm16k, startSample, endSample);
    final outcome = await _runJob(
      job: AlignIsolateJob(
        sourcePcm: Float32List.fromList(slice),
        transcript: text,
        language: language,
        granularity: granularity,
        timeOffset: segment.startTime,
      ),
      timeout: cueTimeout,
      cancel: cancel,
    );
    switch (outcome) {
      case AlignmentSuccess(:final result):
        for (final entry in result.timeline) {
          successes.add(
            withSegmentId(
              clampTimelineToCueWindow(
                entry,
                startTime: segment.startTime,
                endTime: segment.endTime,
              ),
              segment.id,
            ),
          );
        }
      case AlignmentFailed(:final failure):
        if (failure.reason == AlignmentFailureReason.cancelled ||
            failure.reason == AlignmentFailureReason.timedOut ||
            failure.reason == AlignmentFailureReason.unsupportedLanguage ||
            failure.reason == AlignmentFailureReason.audioUnavailable) {
          return outcome;
        }
        lastCueFailure = failure.reason;
    }
  }

  if (successes.isEmpty) {
    return AlignmentFailed(
      AlignmentFailure(
        reason: lastCueFailure ?? AlignmentFailureReason.internal,
      ),
    );
  }

  final words = [
    for (final seg in successes)
      ...?seg.timeline?.where((e) => e.type == TimelineEntryType.word),
  ];
  final joined = successes.map((e) => e.text).join(' ');
  return AlignmentSuccess(
    AlignmentResult(
      timeline: successes,
      wordTimeline: words,
      transcript: joined,
      language: language,
      durationSeconds: _durationSeconds(sourcePcm16k),
    ),
  );
}
