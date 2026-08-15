import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/synth/espeak_reference.dart';

void main() {
  test(
    'eSpeak hello-world golden ±50 ms',
    () async {
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
      final result = (outcome as AlignmentSuccess).result;
      expect(result.wordTimeline, hasLength(2));
      expect(result.wordTimeline[0].startTime, closeTo(0.0, 0.05));
      expect(result.wordTimeline[1].startTime, closeTo(1.0, 0.05));
    },
    skip: espeakFfiIsAvailable()
        ? false
        : 'eSpeak-NG FFI not loaded on this runner',
  );
}
