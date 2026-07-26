import 'package:enjoy_player/features/ai/data/azure_assessment_wav_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizeWavForAzureAssessment', () {
    test('returns false when inputPath is empty', () async {
      final ok = await normalizeWavForAzureAssessment(
        inputPath: '',
        outputWavPath: '/tmp/out.wav',
      );
      expect(ok, isFalse);
    });

    test('returns false when inputPath is whitespace only', () async {
      final ok = await normalizeWavForAzureAssessment(
        inputPath: '   ',
        outputWavPath: '/tmp/out.wav',
      );
      expect(ok, isFalse);
    });

    test('returns false when input file does not exist', () async {
      // No input file → scan returns null, FFmpeg will fail (no plugin in tests).
      final ok = await normalizeWavForAzureAssessment(
        inputPath:
            '/tmp/__definitely_missing_${DateTime.now().microsecondsSinceEpoch}.wav',
        outputWavPath: '/tmp/__definitely_missing_out.wav',
      );
      expect(ok, isFalse);
    });
  });

  group('tryCreateNormalizedAzureAssessmentWav', () {
    test('returns null when normalize fails', () async {
      final out = await tryCreateNormalizedAzureAssessmentWav(
        '/tmp/__missing_input_${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      expect(out, isNull);
    });

    test('returns null when input path is empty', () async {
      final out = await tryCreateNormalizedAzureAssessmentWav('');
      expect(out, isNull);
    });
  });
}
