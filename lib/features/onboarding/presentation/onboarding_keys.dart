/// GlobalKeys for onboarding Showcase targets.
library;

import 'package:flutter/widgets.dart';

import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';

/// Shared registry of tip → [GlobalKey] for showcase targeting.
abstract final class OnboardingKeys {
  static final Map<OnboardingTipId, GlobalKey> _keys = {
    for (final tip in OnboardingTipId.values)
      tip: GlobalKey(debugLabel: tip.id),
  };

  static GlobalKey keyFor(OnboardingTipId tip) => _keys[tip]!;
}
