import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/alignment_pipeline.dart';

import 'helpers/fake_spoken_synthesizer.dart';

void main() {
  test('runAlignPipeline without isolate', () {
    const text = 'hello world';
    const synth = FakeSpokenSynthesizer();
    final ref = synth.synthesize(text: text, language: 'en-US');
    final result = runAlignPipeline(
      sourcePcm: ref.pcm,
      transcript: text,
      language: 'en-US',
      reference: ref,
    );
    expect(result, isA<AlignmentResult>());
    expect((result as AlignmentResult).wordTimeline, isNotEmpty);
  });

  test('unequal reference length still returns source-timeline times', () {
    const text = 'hello world';
    const synth = FakeSpokenSynthesizer(durationSeconds: 1.2);
    final ref = synth.synthesize(text: text, language: 'en-US');
    final source = Float32List(3 * kAlignmentSampleRate);
    source.setRange(0, ref.pcm.length.clamp(0, source.length), ref.pcm);
    final raw = runAlignPipeline(
      sourcePcm: source,
      transcript: text,
      language: 'en-US',
      reference: ref,
    );
    final result = raw as AlignmentResult;
    expect(result.transcript, text);
    expect(result.durationSeconds, closeTo(3.0, 0.01));
    expect(result.wordTimeline, hasLength(2));
    for (final word in result.wordTimeline) {
      expect(word.startTime, greaterThanOrEqualTo(0));
      expect(word.endTime, lessThanOrEqualTo(3.05));
    }
  });

  test('pipeline without a prebuilt reference fails closed', () {
    final source = Float32List(2 * kAlignmentSampleRate);
    final raw = runAlignPipeline(
      sourcePcm: source,
      transcript: 'hello world',
      language: 'en-US',
    );
    expect(raw, isA<AlignmentFailure>());
    expect(
      (raw as AlignmentFailure).reason,
      AlignmentFailureReason.spokenReferenceUnavailable,
    );
  });
}
