/// Pure eligibility helpers for onboarding tip sequences.
library;

import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_progress.dart';

/// Ephemeral UI/media state used to decide whether a tip may auto-show.
class TriggerContext {
  const TriggerContext({
    required this.routePath,
    this.mediaId,
    this.isYoutube = false,
    this.hasTranscript = false,
    this.echoActive = false,
    this.recordUiReady = false,
    this.assessUiReady = false,
    this.blockingOverlay = false,
    this.targetPainted = true,
  });

  final String routePath;
  final String? mediaId;
  final bool isYoutube;
  final bool hasTranscript;
  final bool echoActive;
  final bool recordUiReady;
  final bool assessUiReady;

  /// True when permissions / fatal / forced-sign-in UI owns the barrier.
  final bool blockingOverlay;

  /// False when the tip target has zero size / is not painted.
  final bool targetPainted;

  bool get isHome => routePath == '/' || routePath.isEmpty;
  bool get isPlayer => routePath.startsWith('/player/');
}

abstract final class TipEligibility {
  static bool canStartAny(TriggerContext ctx) =>
      !ctx.blockingOverlay && ctx.targetPainted;

  /// Pending home tips in catalog order.
  static List<OnboardingTipId> pendingHomeTips(TipProgressSnapshot progress) {
    return [
      for (final tip in kHomeEntriesOrder)
        if (!progress.statusOfGlobal(tip).isResolved) tip,
    ];
  }

  static bool homeEntriesEligible(
    TriggerContext ctx,
    TipProgressSnapshot progress,
  ) {
    if (!canStartAny(ctx) || !ctx.isHome) return false;
    return pendingHomeTips(progress).isNotEmpty;
  }

  static OnboardingTipId emptyTranscriptTip({required bool isYoutube}) =>
      isYoutube
      ? OnboardingTipId.playerEmptyTranscriptYoutube
      : OnboardingTipId.playerEmptyTranscriptLocal;

  static bool emptyTranscriptEligible(
    TriggerContext ctx,
    TipProgressSnapshot progress,
  ) {
    if (!canStartAny(ctx) || !ctx.isPlayer) return false;
    final mediaId = ctx.mediaId;
    if (mediaId == null || mediaId.isEmpty) return false;
    if (ctx.hasTranscript) return false;
    return !progress.statusOfEmptyTranscript(mediaId).isResolved;
  }

  /// Soft-completes echo when already active (FR-004b); returns next tip to show.
  static OnboardingTipId? nextPracticeTipToShow(
    TriggerContext ctx,
    TipProgressSnapshot progress,
  ) {
    if (!canStartAny(ctx) || !ctx.isPlayer || !ctx.hasTranscript) {
      return null;
    }

    final echoStatus = progress.statusOfGlobal(OnboardingTipId.playerEcho);
    if (!echoStatus.isResolved) {
      if (ctx.echoActive) {
        // Caller should mark echo completed; then re-evaluate.
        return OnboardingTipId.playerEcho;
      }
      return OnboardingTipId.playerEcho;
    }

    final recordStatus = progress.statusOfGlobal(OnboardingTipId.playerRecord);
    if (!recordStatus.isResolved) {
      if (!ctx.recordUiReady) return null;
      return OnboardingTipId.playerRecord;
    }

    final assessStatus = progress.statusOfGlobal(OnboardingTipId.playerAssess);
    if (!assessStatus.isResolved) {
      if (!ctx.assessUiReady) return null;
      return OnboardingTipId.playerAssess;
    }
    return null;
  }

  /// Whether echo tip should be silently marked completed without showing.
  static bool shouldSoftCompleteEcho(
    TriggerContext ctx,
    TipProgressSnapshot progress,
  ) {
    if (progress.statusOfGlobal(OnboardingTipId.playerEcho).isResolved) {
      return false;
    }
    return ctx.hasTranscript && ctx.echoActive && ctx.isPlayer;
  }
}
