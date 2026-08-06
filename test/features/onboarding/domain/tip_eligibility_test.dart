import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_eligibility.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_progress.dart';

void main() {
  group('TipEligibility', () {
    test('home entries pending order is import then craft', () {
      const progress = TipProgressSnapshot();
      expect(TipEligibility.pendingHomeTips(progress), [
        OnboardingTipId.homeImport,
        OnboardingTipId.homeCraft,
      ]);
    });

    test('home entries not eligible when blocking overlay', () {
      const ctx = TriggerContext(routePath: '/', blockingOverlay: true);
      expect(
        TipEligibility.homeEntriesEligible(ctx, const TipProgressSnapshot()),
        isFalse,
      );
    });

    test('empty transcript is per media and blocked when has transcript', () {
      const ctx = TriggerContext(
        routePath: '/player/abc',
        mediaId: 'abc',
        hasTranscript: true,
      );
      expect(
        TipEligibility.emptyTranscriptEligible(
          ctx,
          const TipProgressSnapshot(),
        ),
        isFalse,
      );
    });

    test('empty transcript youtube tip id', () {
      expect(
        TipEligibility.emptyTranscriptTip(isYoutube: true),
        OnboardingTipId.playerEmptyTranscriptYoutube,
      );
      expect(
        TipEligibility.emptyTranscriptTip(isYoutube: false),
        OnboardingTipId.playerEmptyTranscriptLocal,
      );
    });

    test('practice soft-complete echo when already active', () {
      const ctx = TriggerContext(
        routePath: '/player/m1',
        mediaId: 'm1',
        hasTranscript: true,
        echoActive: true,
      );
      expect(
        TipEligibility.shouldSoftCompleteEcho(ctx, const TipProgressSnapshot()),
        isTrue,
      );
    });

    test('practice next tip after echo resolved is record when ready', () {
      final progress = TipProgressSnapshot(
        global: {OnboardingTipId.playerEcho.id: TipStatus.completed},
      );
      const ctx = TriggerContext(
        routePath: '/player/m1',
        mediaId: 'm1',
        hasTranscript: true,
        recordUiReady: true,
      );
      expect(
        TipEligibility.nextPracticeTipToShow(ctx, progress),
        OnboardingTipId.playerRecord,
      );
    });
  });

  group('TipProgressSnapshot', () {
    test('encode/decode ignores unknown tip ids', () {
      final map = TipProgressSnapshot.decodeGlobalJson(
        '{"home.import":"completed","unknown.tip":"skipped"}',
      );
      expect(map['home.import'], TipStatus.completed);
      expect(map.containsKey('unknown.tip'), isFalse);
    });
  });
}
