import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/synth/espeak_reference.dart';

void main() {
  test('blank text is blankText, not empty success', () async {
    final pcm = const DurationModelSynthesizer()
        .synthesize(text: 'hello', language: 'en-US', durationSeconds: 2)
        .pcm;
    final outcome = await align(
      sourcePcm16k: pcm,
      transcript: '   ',
      language: 'en-US',
    );
    expect(outcome, isA<AlignmentFailed>());
    expect(
      (outcome as AlignmentFailed).failure.reason,
      AlignmentFailureReason.blankText,
    );
  });

  test('unsupported language does not fall back to en-US', () async {
    final pcm = const DurationModelSynthesizer()
        .synthesize(text: 'hello', language: 'en-US', durationSeconds: 2)
        .pcm;
    final outcome = await align(
      sourcePcm16k: pcm,
      transcript: 'hello',
      language: 'xx-XX',
    );
    expect(
      (outcome as AlignmentFailed).failure.reason,
      AlignmentFailureReason.unsupportedLanguage,
    );
  });

  test('empty PCM is audioUnavailable', () async {
    final outcome = await align(
      sourcePcm16k: Float32List(0),
      transcript: 'hello',
      language: 'en-US',
    );
    expect(
      (outcome as AlignmentFailed).failure.reason,
      AlignmentFailureReason.audioUnavailable,
    );
  });

  test('punctuation-only success may have an empty word list', () async {
    final pcm = const DurationModelSynthesizer()
        .synthesize(text: '...', language: 'en-US', durationSeconds: 2)
        .pcm;
    final outcome = await align(
      sourcePcm16k: pcm,
      transcript: '...',
      language: 'en-US',
    );
    expect(outcome, isA<AlignmentSuccess>());
    expect((outcome as AlignmentSuccess).result.wordTimeline, isEmpty);
  });
}
