/// Registers ShowcaseView once for the app shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/onboarding/application/onboarding_controller.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

final _log = logNamed('OnboardingShowcaseHost');

/// Wraps shell content and owns ShowcaseView registration lifecycle.
class OnboardingShowcaseHost extends ConsumerStatefulWidget {
  const OnboardingShowcaseHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OnboardingShowcaseHost> createState() =>
      _OnboardingShowcaseHostState();
}

class _OnboardingShowcaseHostState
    extends ConsumerState<OnboardingShowcaseHost> {
  @override
  void initState() {
    super.initState();
    ShowcaseView.register(
      enableAutoScroll: true,
      // Prefer waiting for targets in OnboardingController; skipping missing
      // targets still finishes the tour and used to poison tip progress.
      skipIfTargetNotPresent: false,
      disableBarrierInteraction: false,
      onStart: (_, _) {
        ref.read(onboardingControllerProvider.notifier).onShowcaseStarted();
      },
      onFinish: () {
        ref.read(onboardingControllerProvider.notifier).onShowcaseFinished();
      },
      onDismiss: (key) {
        ref
            .read(onboardingControllerProvider.notifier)
            .onShowcaseDismissed(key);
      },
      globalFloatingActionWidget: (context) {
        final l10n = AppLocalizations.of(context);
        return FloatingActionWidget(
          right: 16,
          bottom: 24,
          child: TextButton(
            onPressed: () {
              try {
                ShowcaseView.get().dismiss();
              } on Object catch (e, st) {
                _log.warning('dismiss failed', e, st);
              }
            },
            child: Text(l10n?.onboardingTipSkip ?? 'Skip'),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    try {
      ShowcaseView.get().unregister();
    } on Object catch (e, st) {
      _log.fine('unregister: $e', e, st);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
