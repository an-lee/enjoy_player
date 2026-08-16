import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

import 'helpers/fake_spoken_synthesizer.dart';

void main() {
  const synth = FakeSpokenSynthesizer(durationSeconds: 8);

  test('pre-cancelled token returns cancelled without hanging', () async {
    final pcm = synth.synthesize(text: 'hello world', language: 'en-US').pcm;
    final token = AlignmentCancelToken()..cancel();
    final outcome = await align(
      sourcePcm16k: pcm,
      transcript: 'hello world',
      language: 'en-US',
      cancel: token,
      synthesizer: synth,
    );
    expect(
      (outcome as AlignmentFailed).failure.reason,
      AlignmentFailureReason.cancelled,
    );
  });

  test('in-flight cancel returns cancelled', () async {
    final pcm = synth.synthesize(text: 'hello world', language: 'en-US').pcm;
    final token = AlignmentCancelToken();
    final future = align(
      sourcePcm16k: pcm,
      transcript: 'hello world',
      language: 'en-US',
      granularity: AlignmentGranularity.high,
      cancel: token,
      synthesizer: synth,
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
    final pcm = synth.synthesize(text: 'hello world', language: 'en-US').pcm;
    final outcome = await align(
      sourcePcm16k: pcm,
      transcript: 'hello world',
      language: 'en-US',
      granularity: AlignmentGranularity.high,
      timeout: const Duration(milliseconds: 1),
      synthesizer: synth,
    );
    expect(
      (outcome as AlignmentFailed).failure.reason,
      AlignmentFailureReason.timedOut,
    );
  });
}
