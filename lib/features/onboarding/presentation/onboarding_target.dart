/// Thin Showcase wrapper for learn-by-doing tip targets.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:enjoy_player/features/onboarding/application/onboarding_controller.dart';
import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/presentation/onboarding_keys.dart';
import 'package:enjoy_player/features/onboarding/presentation/onboarding_tooltip_theme.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

typedef OnboardingTipAction = void Function();

/// Wraps [child] so onboarding can spotlight it.
class OnboardingTarget extends ConsumerWidget {
  const OnboardingTarget({
    required this.tipId,
    required this.child,
    this.onTargetAction,
    super.key,
  });

  final OnboardingTipId tipId;
  final Widget child;

  /// Real control action when the learner taps the highlighted target.
  final OnboardingTipAction? onTargetAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final (title, description) = _copyFor(l10n, tipId);
    final key = OnboardingKeys.keyFor(tipId);

    // ShowcaseView throws when no scope is registered (see ShowcaseService
    // getScope). OnboardingShowcaseHost owns the registration lifecycle in the
    // app shell, but feature tests that pump widgets containing OnboardingTarget
    // without mounting that host must still render. Skip the Showcase wrapper
    // in that case so the child renders unchanged.
    if (!_isShowcaseViewRegistered) {
      return child;
    }

    return Showcase(
      key: key,
      title: title,
      description: description,
      titleTextStyle: OnboardingTooltipTheme.titleStyle(context),
      descTextStyle: OnboardingTooltipTheme.descriptionStyle(context),
      tooltipBackgroundColor: OnboardingTooltipTheme.tooltipBackground(context),
      overlayColor: OnboardingTooltipTheme.overlayColor(context),
      disposeOnTap: true,
      onTargetClick: () {
        // Flags must be set before showcaseview's dismiss finalize microtask.
        final ctrl = ref.read(onboardingControllerProvider.notifier);
        unawaited(ctrl.onTargetActed(tipId));
        onTargetAction?.call();
      },
      child: child,
    );
  }

  bool get _isShowcaseViewRegistered {
    try {
      ShowcaseView.get();
      return true;
    } on Object {
      return false;
    }
  }

  static (String, String) _copyFor(AppLocalizations l10n, OnboardingTipId tip) {
    return switch (tip) {
      OnboardingTipId.homeImport => (
        l10n.onboardingTipHomeImportTitle,
        l10n.onboardingTipHomeImportBody,
      ),
      OnboardingTipId.homeCraft => (
        l10n.onboardingTipHomeCraftTitle,
        l10n.onboardingTipHomeCraftBody,
      ),
      OnboardingTipId.playerEmptyTranscriptLocal => (
        l10n.onboardingTipEmptyTranscriptLocalTitle,
        l10n.onboardingTipEmptyTranscriptLocalBody,
      ),
      OnboardingTipId.playerEmptyTranscriptYoutube => (
        l10n.onboardingTipEmptyTranscriptYoutubeTitle,
        l10n.onboardingTipEmptyTranscriptYoutubeBody,
      ),
      OnboardingTipId.playerEcho => (
        l10n.onboardingTipEchoTitle,
        l10n.onboardingTipEchoBody,
      ),
      OnboardingTipId.playerRecord => (
        l10n.onboardingTipRecordTitle,
        l10n.onboardingTipRecordBody,
      ),
      OnboardingTipId.playerAssess => (
        l10n.onboardingTipAssessTitle,
        l10n.onboardingTipAssessBody,
      ),
    };
  }
}
