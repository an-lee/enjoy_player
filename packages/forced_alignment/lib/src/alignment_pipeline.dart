import 'dart:typed_data';

import 'constants.dart';
import 'dtw/windowed_dtw.dart';
import 'mfcc/mfcc_extractor.dart';
import 'synth/espeak_reference.dart';
import 'types.dart';

/// Pure DSP body: synthesize reference, MFCC both sides, DTW, remap events.
AlignmentResult runAlignPipeline({
  required Float32List sourcePcm,
  required String transcript,
  required String language,
  required AlignmentGranularity granularity,
  double timeOffset = 0,
}) {
  final duration = sourcePcm.length / kAlignmentSampleRate;
  final includePhones = granularity != AlignmentGranularity.low;
  const synth = DurationModelSynthesizer();
  final reference = synth.synthesize(
    text: transcript,
    language: language,
    durationSeconds: duration,
  );
  final preset = mfccPresetFor(granularity);
  final hop = preset.windowStride / kAlignmentSampleRate;
  final refFrames = extractMfccFrames(reference.pcm, preset);
  final srcFrames = extractMfccFrames(sourcePcm, preset);
  final frameMap = mapReferenceFramesToSource(
    refFrames,
    srcFrames,
    windowPct: kSakoeChibaWindowPct,
  );

  double mapTime(double refTime) {
    if (frameMap.isEmpty) return timeOffset + refTime;
    final refFrame = (refTime / hop).round().clamp(0, frameMap.length - 1);
    final srcFrame = frameMap[refFrame].clamp(0, srcFrames.length - 1);
    return timeOffset + srcFrame * hop;
  }

  final wordEntries = <TimelineEntry>[];
  for (final word in reference.words) {
    final start = mapTime(word.startTime);
    var end = mapTime(word.endTime);
    if (end < start) end = start;
    List<TimelineEntry>? phones;
    if (includePhones && word.phones.isNotEmpty) {
      phones = [
        for (final phone in word.phones)
          TimelineEntry(
            type: TimelineEntryType.phone,
            text: phone.phone,
            startTime: mapTime(phone.startTime),
            endTime: _atLeast(mapTime(phone.endTime), mapTime(phone.startTime)),
          ),
      ];
    }
    wordEntries.add(
      TimelineEntry(
        type: TimelineEntryType.word,
        text: word.text,
        startTime: start,
        endTime: end,
        timeline: phones,
      ),
    );
  }

  final segment = TimelineEntry(
    type: TimelineEntryType.segment,
    text: transcript,
    startTime: timeOffset,
    endTime: timeOffset + duration,
    timeline: wordEntries,
  );

  return AlignmentResult(
    timeline: [segment],
    wordTimeline: wordEntries,
    transcript: transcript,
    language: language,
    durationSeconds: duration,
  );
}

double _atLeast(double value, double min) => value < min ? min : value;
