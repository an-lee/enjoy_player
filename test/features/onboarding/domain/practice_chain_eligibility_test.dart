import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_eligibility.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_progress.dart';

void main() {
  group('practice chain eligibility', () {
    const playerCtx = TriggerContext(
      routePath: '/player/m1',
      mediaId: 'm1',
      hasTranscript: true,
    );

    test('starts with echo when transcript present and echo pending', () {
      expect(
        TipEligibility.nextPracticeTipToShow(
          playerCtx,
          const TipProgressSnapshot(),
        ),
        OnboardingTipId.playerEcho,
      );
    });

    test('does not start practice without transcript', () {
      const ctx = TriggerContext(
        routePath: '/player/m1',
        mediaId: 'm1',
        hasTranscript: false,
      );
      expect(
        TipEligibility.nextPracticeTipToShow(ctx, const TipProgressSnapshot()),
        isNull,
      );
    });

    test('same-visit next tip is record when echo resolved and UI ready', () {
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

    test('record tip waits until recordUiReady', () {
      final progress = TipProgressSnapshot(
        global: {OnboardingTipId.playerEcho.id: TipStatus.completed},
      );
      expect(TipEligibility.nextPracticeTipToShow(playerCtx, progress), isNull);
    });

    test('assess tip follows record when assess UI ready', () {
      final progress = TipProgressSnapshot(
        global: {
          OnboardingTipId.playerEcho.id: TipStatus.completed,
          OnboardingTipId.playerRecord.id: TipStatus.completed,
        },
      );
      const ctx = TriggerContext(
        routePath: '/player/m1',
        mediaId: 'm1',
        hasTranscript: true,
        assessUiReady: true,
      );
      expect(
        TipEligibility.nextPracticeTipToShow(ctx, progress),
        OnboardingTipId.playerAssess,
      );
    });

    test('soft-complete echo when already active', () {
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

    test('returns null when practice sequence fully resolved', () {
      final progress = TipProgressSnapshot(
        global: {
          OnboardingTipId.playerEcho.id: TipStatus.completed,
          OnboardingTipId.playerRecord.id: TipStatus.skipped,
          OnboardingTipId.playerAssess.id: TipStatus.completed,
        },
      );
      const ctx = TriggerContext(
        routePath: '/player/m1',
        mediaId: 'm1',
        hasTranscript: true,
        recordUiReady: true,
        assessUiReady: true,
      );
      expect(TipEligibility.nextPracticeTipToShow(ctx, progress), isNull);
    });
  });
}
