import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/synth/espeak_reference.dart';

void main() {
  test('two cue windows offset onto the source timeline', () async {
    const text = 'hello world hello world';
    final ref = const DurationModelSynthesizer().synthesize(
      text: text,
      language: 'en-US',
      durationSeconds: 4,
    );
    const a = AlignmentSegment(text: 'hello world', startTime: 0, endTime: 2);
    const b = AlignmentSegment(text: 'hello world', startTime: 2, endTime: 4);
    final originalStart = a.startTime;
    final originalEnd = a.endTime;
    final outcome = await alignSegments(
      sourcePcm16k: ref.pcm,
      language: 'en-US',
      segments: const [a, b],
    );
    expect(outcome, isA<AlignmentSuccess>());
    expect(a.startTime, originalStart);
    expect(a.endTime, originalEnd);
    final result = (outcome as AlignmentSuccess).result;
    expect(result.timeline, hasLength(2));
    for (final seg in result.timeline) {
      for (final word in seg.timeline ?? const []) {
        if (word.type != TimelineEntryType.word) continue;
        expect(word.startTime, greaterThanOrEqualTo(seg.startTime - 0.050));
        expect(word.endTime, lessThanOrEqualTo(seg.endTime + 0.050));
      }
    }
    expect(result.wordTimeline.first.startTime, lessThan(1.5));
    expect(result.wordTimeline.last.startTime, greaterThan(2.0));
  });

  test('cue shorter than 1s is skipped; sibling still succeeds', () async {
    final ref = const DurationModelSynthesizer().synthesize(
      text: 'hello world',
      language: 'en-US',
      durationSeconds: 3,
    );
    final outcome = await alignSegments(
      sourcePcm16k: ref.pcm,
      language: 'en-US',
      segments: const [
        AlignmentSegment(text: 'hi', startTime: 0, endTime: 0.4, id: 0),
        AlignmentSegment(
          text: 'hello world',
          startTime: 0.5,
          endTime: 3.0,
          id: 1,
        ),
      ],
    );
    expect(outcome, isA<AlignmentSuccess>());
    final result = (outcome as AlignmentSuccess).result;
    expect(result.timeline, hasLength(1));
    expect(result.timeline.single.id, 1);
  });

  test('every cue tooShort is a typed failure, not empty success', () async {
    final ref = const DurationModelSynthesizer().synthesize(
      text: 'hello world',
      language: 'en-US',
      durationSeconds: 2,
    );
    final outcome = await alignSegments(
      sourcePcm16k: ref.pcm,
      language: 'en-US',
      segments: const [
        AlignmentSegment(text: 'a', startTime: 0, endTime: 0.2),
        AlignmentSegment(text: 'b', startTime: 0.2, endTime: 0.4),
      ],
    );
    expect(outcome, isA<AlignmentFailed>());
    expect(
      (outcome as AlignmentFailed).failure.reason,
      AlignmentFailureReason.tooShort,
    );
  });

  test('alignSegments accepts PCM longer than 90s', () async {
    final head = const DurationModelSynthesizer().synthesize(
      text: 'hello world',
      language: 'en-US',
      durationSeconds: 2,
    );
    final pcm = Float32List(92 * kAlignmentSampleRate);
    pcm.setRange(0, head.pcm.length, head.pcm);
    final outcome = await alignSegments(
      sourcePcm16k: pcm,
      language: 'en-US',
      segments: const [
        AlignmentSegment(text: 'hello world', startTime: 0, endTime: 2),
      ],
    );
    expect(outcome, isA<AlignmentSuccess>());
  });
}
