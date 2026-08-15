import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/synth/espeak_reference.dart';

void main() {
  test('pre-cancelled token returns cancelled without hanging', () async {
    final pcm = const DurationModelSynthesizer()
        .synthesize(text: 'hello world', language: 'en-US', durationSeconds: 4)
        .pcm;
    final token = AlignmentCancelToken()..cancel();
    final outcome = await align(
      sourcePcm16k: pcm,
      transcript: 'hello world',
      language: 'en-US',
      cancel: token,
    );
    expect(
      (outcome as AlignmentFailed).failure.reason,
      AlignmentFailureReason.cancelled,
    );
  });

  test('in-flight cancel returns cancelled', () async {
    final pcm = const DurationModelSynthesizer()
        .synthesize(text: 'hello world', language: 'en-US', durationSeconds: 8)
        .pcm;
    final token = AlignmentCancelToken();
    final future = align(
      sourcePcm16k: pcm,
      transcript: 'hello world',
      language: 'en-US',
      granularity: AlignmentGranularity.high,
      cancel: token,
    );
    token.cancel();
    final outcome = await future;
    expect(outcome, isA<AlignmentFailed>());
    expect(
      (outcome as AlignmentFailed).failure.reason,
      AlignmentFailureReason.cancelled,
    );
  });

  test('timeout returns timedOut', () async {
    final pcm = const DurationModelSynthesizer()
        .synthesize(text: 'hello world', language: 'en-US', durationSeconds: 8)
        .pcm;
    final outcome = await align(
      sourcePcm16k: pcm,
      transcript: 'hello world',
      language: 'en-US',
      granularity: AlignmentGranularity.high,
      timeout: const Duration(milliseconds: 1),
    );
    expect(
      (outcome as AlignmentFailed).failure.reason,
      AlignmentFailureReason.timedOut,
    );
  });
}
