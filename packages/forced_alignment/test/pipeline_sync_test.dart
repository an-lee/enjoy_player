import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/src/alignment_pipeline.dart';
import 'package:forced_alignment/src/synth/espeak_reference.dart';
import 'package:forced_alignment/src/types.dart';

void main() {
  test('runAlignPipeline without isolate', () {
    const text = 'hello world';
    final ref = const DurationModelSynthesizer().synthesize(
      text: text,
      language: 'en-US',
      durationSeconds: 2,
    );
    final result = runAlignPipeline(
      sourcePcm: ref.pcm,
      transcript: text,
      language: 'en-US',
      granularity: AlignmentGranularity.medium,
    );
    expect(result.wordTimeline, isNotEmpty);
  });
}
