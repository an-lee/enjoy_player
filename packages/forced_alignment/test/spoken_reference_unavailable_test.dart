import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

import 'helpers/fake_spoken_synthesizer.dart';

void main() {
  tearDown(() {
    debugSetEspeakFfiAvailable(null);
  });

  test(
    'omitted synthesizer with FFI forced off is spokenReferenceUnavailable',
    () async {
      debugSetEspeakFfiAvailable(false);
      const synth = FakeSpokenSynthesizer();
      final pcm = synth.synthesize(text: 'hello world', language: 'en-US').pcm;
      final outcome = await align(
        sourcePcm16k: pcm,
        transcript: 'hello world',
        language: 'en-US',
      );
      expect(outcome, isA<AlignmentFailed>());
      final failure = (outcome as AlignmentFailed).failure;
      expect(failure.reason, AlignmentFailureReason.spokenReferenceUnavailable);
      expect(failure.reason, isNot(AlignmentFailureReason.internal));
    },
  );

  test(
    'injected unavailable synthesizer is spokenReferenceUnavailable',
    () async {
      const synth = FakeSpokenSynthesizer();
      final pcm = synth.synthesize(text: 'hello world', language: 'en-US').pcm;
      final outcome = await align(
        sourcePcm16k: pcm,
        transcript: 'hello world',
        language: 'en-US',
        synthesizer: const UnavailableSpokenSynthesizer(),
      );
      expect(outcome, isA<AlignmentFailed>());
      expect(
        (outcome as AlignmentFailed).failure.reason,
        AlignmentFailureReason.spokenReferenceUnavailable,
      );
    },
  );

  test('unavailable is not an empty successful word list', () async {
    debugSetEspeakFfiAvailable(false);
    const synth = FakeSpokenSynthesizer();
    final pcm = synth.synthesize(text: 'hello world', language: 'en-US').pcm;
    final outcome = await align(
      sourcePcm16k: pcm,
      transcript: 'hello world',
      language: 'en-US',
    );
    expect(outcome, isNot(isA<AlignmentSuccess>()));
  });
}
