import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/synth/espeak_reference.dart';

void main() {
  test('hello world at medium has words in order and phones', () async {
    const text = 'hello world';
    final ref = const DurationModelSynthesizer().synthesize(
      text: text,
      language: 'en-US',
      durationSeconds: 2,
    );
    final outcome = await align(
      sourcePcm16k: ref.pcm,
      transcript: text,
      language: 'en-US',
    );
    final failureReason = switch (outcome) {
      AlignmentFailed(:final failure) => failure.toString(),
      _ => '$outcome',
    };
    expect(outcome, isA<AlignmentSuccess>(), reason: failureReason);
    final result = (outcome as AlignmentSuccess).result;
    expect(result.transcript, text);
    expect(result.wordTimeline.map((w) => w.text), ['hello', 'world']);
    expect(result.wordTimeline.first.startTime, closeTo(0.0, 0.05));
    expect(result.wordTimeline.last.startTime, closeTo(1.0, 0.05));
    final flat = flattenToWordPhoneTimings(result);
    expect(flat.phones, isNotEmpty);
    expect(
      flat.phones.every(
        (p) => p.wordIndex != null && p.wordIndex! < flat.words.length,
      ),
      isTrue,
    );
  });

  test('low granularity omits phones', () async {
    const text = 'hello world';
    final ref = const DurationModelSynthesizer().synthesize(
      text: text,
      language: 'en-US',
      durationSeconds: 2,
    );
    final outcome = await align(
      sourcePcm16k: ref.pcm,
      transcript: text,
      language: 'en-US',
      granularity: AlignmentGranularity.low,
    );
    final result = (outcome as AlignmentSuccess).result;
    expect(flattenToWordPhoneTimings(result).phones, isEmpty);
  });

  test('duration under 1s is tooShort', () async {
    final pcm = Float32List(kAlignmentSampleRate ~/ 2);
    final outcome = await align(
      sourcePcm16k: pcm,
      transcript: 'hello world',
      language: 'en-US',
    );
    expect(outcome, isA<AlignmentFailed>());
    expect(
      (outcome as AlignmentFailed).failure.reason,
      AlignmentFailureReason.tooShort,
    );
  });

  test('whole-clip over 90s is wholeClipTooLong', () async {
    final pcm = Float32List(91 * kAlignmentSampleRate);
    final outcome = await align(
      sourcePcm16k: pcm,
      transcript: 'hello',
      language: 'en-US',
    );
    expect(
      (outcome as AlignmentFailed).failure.reason,
      AlignmentFailureReason.wholeClipTooLong,
    );
  });
}
