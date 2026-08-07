import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingTipId wire values', () {
    test('every catalog id has a unique wire string', () {
      final ids = OnboardingTipId.values.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('wire ids match the documented catalog', () {
      expect(OnboardingTipId.homeImport.id, 'home.import');
      expect(OnboardingTipId.homeCraft.id, 'home.craft');
      expect(
        OnboardingTipId.playerEmptyTranscriptLocal.id,
        'player.empty_transcript.local',
      );
      expect(
        OnboardingTipId.playerEmptyTranscriptYoutube.id,
        'player.empty_transcript.youtube',
      );
      expect(OnboardingTipId.playerEcho.id, 'player.echo');
      expect(OnboardingTipId.playerRecord.id, 'player.record');
      expect(OnboardingTipId.playerAssess.id, 'player.assess');
    });
  });

  group('OnboardingTipId.tryParse', () {
    test('returns the matching tip for every wire id', () {
      for (final tip in OnboardingTipId.values) {
        expect(OnboardingTipId.tryParse(tip.id), tip);
      }
    });

    test('returns null for unknown wire ids', () {
      expect(OnboardingTipId.tryParse(''), isNull);
      expect(OnboardingTipId.tryParse('home'), isNull);
      expect(OnboardingTipId.tryParse('home.imports'), isNull);
      expect(OnboardingTipId.tryParse('HOME.IMPORT'), isNull);
      expect(OnboardingTipId.tryParse('home.import '), isNull);
    });
  });

  group('OnboardingTipIdX.sequenceId', () {
    test('home entries share the homeEntries sequence', () {
      expect(
        OnboardingTipId.homeImport.sequenceId,
        OnboardingSequenceId.homeEntries,
      );
      expect(
        OnboardingTipId.homeCraft.sequenceId,
        OnboardingSequenceId.homeEntries,
      );
    });

    test('empty-transcript tips share the playerEmptyTranscript sequence', () {
      expect(
        OnboardingTipId.playerEmptyTranscriptLocal.sequenceId,
        OnboardingSequenceId.playerEmptyTranscript,
      );
      expect(
        OnboardingTipId.playerEmptyTranscriptYoutube.sequenceId,
        OnboardingSequenceId.playerEmptyTranscript,
      );
    });

    test('practice tips share the playerPractice sequence', () {
      expect(
        OnboardingTipId.playerEcho.sequenceId,
        OnboardingSequenceId.playerPractice,
      );
      expect(
        OnboardingTipId.playerRecord.sequenceId,
        OnboardingSequenceId.playerPractice,
      );
      expect(
        OnboardingTipId.playerAssess.sequenceId,
        OnboardingSequenceId.playerPractice,
      );
    });

    test('every tip maps to one of exactly three sequences', () {
      for (final tip in OnboardingTipId.values) {
        expect(tip.sequenceId, isIn(OnboardingSequenceId.values));
      }
      // No two tips in different sequences; ensure partition coverage.
      expect(OnboardingSequenceId.values.toSet().length, 3);
    });
  });

  group('OnboardingTipIdX.isPerMedia', () {
    test('only empty-transcript tips are per-media', () {
      expect(OnboardingTipId.playerEmptyTranscriptLocal.isPerMedia, isTrue);
      expect(OnboardingTipId.playerEmptyTranscriptYoutube.isPerMedia, isTrue);
    });

    test('global tips are not per-media', () {
      expect(OnboardingTipId.homeImport.isPerMedia, isFalse);
      expect(OnboardingTipId.homeCraft.isPerMedia, isFalse);
      expect(OnboardingTipId.playerEcho.isPerMedia, isFalse);
      expect(OnboardingTipId.playerRecord.isPerMedia, isFalse);
      expect(OnboardingTipId.playerAssess.isPerMedia, isFalse);
    });
  });

  group('kHomeEntriesOrder', () {
    test('lists import then craft', () {
      expect(kHomeEntriesOrder, [
        OnboardingTipId.homeImport,
        OnboardingTipId.homeCraft,
      ]);
    });

    test('every entry belongs to the homeEntries sequence', () {
      for (final tip in kHomeEntriesOrder) {
        expect(tip.sequenceId, OnboardingSequenceId.homeEntries);
      }
    });
  });

  group('kPracticeOrder', () {
    test('lists echo then record then assess', () {
      expect(kPracticeOrder, [
        OnboardingTipId.playerEcho,
        OnboardingTipId.playerRecord,
        OnboardingTipId.playerAssess,
      ]);
    });

    test('every entry belongs to the playerPractice sequence', () {
      for (final tip in kPracticeOrder) {
        expect(tip.sequenceId, OnboardingSequenceId.playerPractice);
      }
    });

    test('practice order has no per-media tips', () {
      for (final tip in kPracticeOrder) {
        expect(tip.isPerMedia, isFalse);
      }
    });
  });
}
