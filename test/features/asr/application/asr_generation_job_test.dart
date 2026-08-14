import 'package:enjoy_player/features/asr/application/asr_generation_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsrGenerationJob.copyWith', () {
    const base = AsrGenerationJob(
      mediaId: 'media-1',
      language: 'en-US',
      phase: AsrGenerationPhase.idle,
    );

    test('updates phase only, preserves the rest', () {
      final next = base.copyWith(phase: AsrGenerationPhase.extracting);
      expect(next.phase, AsrGenerationPhase.extracting);
      expect(next.mediaId, 'media-1');
      expect(next.language, 'en-US');
      expect(next.detectedLanguage, isNull);
      expect(next.progress, isNull);
      expect(next.errorMessage, isNull);
      expect(next.startedAt, isNull);
      expect(next.completedAt, isNull);
      expect(next.trackId, isNull);
      expect(next.creditsCharged, isNull);
    });

    test('populates progress, startedAt, completedAt', () {
      final started = DateTime.utc(2026, 8, 14, 10);
      final completed = DateTime.utc(2026, 8, 14, 10, 5);
      final next = base.copyWith(
        phase: AsrGenerationPhase.recognizing,
        progress: 0.42,
        startedAt: started,
        completedAt: completed,
      );
      expect(next.phase, AsrGenerationPhase.recognizing);
      expect(next.progress, 0.42);
      expect(next.startedAt, started);
      expect(next.completedAt, completed);
    });

    test('preserves mediaId and language (immutable identity)', () {
      final next = base.copyWith(phase: AsrGenerationPhase.success);
      expect(next.mediaId, base.mediaId);
      expect(next.language, base.language);
      expect(identical(next, base), isFalse);
    });

    test('null copyWith arguments retain prior values', () {
      final withProgress = base.copyWith(progress: 0.1);
      final later = withProgress.copyWith(phase: AsrGenerationPhase.polling);
      expect(later.phase, AsrGenerationPhase.polling);
      expect(later.progress, 0.1);
    });
  });

  group('AsrGenerationJob.terminal phases', () {
    test('success carries trackId and creditsCharged', () {
      final job = const AsrGenerationJob(
        mediaId: 'media-2',
        language: 'ja-JP',
        phase: AsrGenerationPhase.success,
        trackId: 'track-42',
        creditsCharged: 7,
        startedAt: null,
        completedAt: null,
      );
      expect(job.trackId, 'track-42');
      expect(job.creditsCharged, 7);
    });

    test('error carries localized errorMessage', () {
      final job = const AsrGenerationJob(
        mediaId: 'media-3',
        language: 'zh-CN',
        phase: AsrGenerationPhase.error,
        errorMessage: 'asrErrorCreditsExhausted',
      );
      expect(job.errorMessage, 'asrErrorCreditsExhausted');
      expect(job.phase, AsrGenerationPhase.error);
    });

    test('cancelled is terminal and never persists', () {
      final job = const AsrGenerationJob(
        mediaId: 'media-4',
        language: 'fr-FR',
        phase: AsrGenerationPhase.cancelled,
      );
      expect(job.trackId, isNull);
      expect(job.completedAt, isNull);
    });
  });

  test('AsrGenerationPhase declares all expected values', () {
    const phases = AsrGenerationPhase.values;
    expect(phases, containsAll(<AsrGenerationPhase>[
      AsrGenerationPhase.idle,
      AsrGenerationPhase.extracting,
      AsrGenerationPhase.uploading,
      AsrGenerationPhase.recognizing,
      AsrGenerationPhase.polling,
      AsrGenerationPhase.persisting,
      AsrGenerationPhase.success,
      AsrGenerationPhase.error,
      AsrGenerationPhase.cancelled,
    ]));
    expect(phases.length, 9);
  });
}