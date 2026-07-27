/// Decorative blur wrapper used by `TranscriptLineTile` to render
/// every cue body text with a CSS-style `ImageFilter.blur` filter
/// when blur practice mode is on.
///
/// This widget does NOT alter the parent's intrinsic dimensions,
/// does NOT touch semantics, and does NOT affect lookup / selection
/// on revealed lines — the blur is a pure paint effect.
///
/// Honors `MediaQuery.disableAnimationsOf`:
/// * When `true`: instant on/off (no animation).
/// * When `false`: 120 ms opacity fade between blurred and revealed.
///
/// Exported via `@visibleForTesting` so widget tests can pump it
/// directly without the rest of the tile plumbing.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

@visibleForTesting
class TranscriptBlurText extends StatelessWidget {
  const TranscriptBlurText({
    super.key,
    required this.revealed,
    required this.child,
    this.sigma = 6.0,
  });

  /// When `true` the child is rendered unchanged.
  final bool revealed;

  /// The text widget(s) to wrap. Layout-affecting wrappers MUST NOT be
  /// inserted above this point — see [data-model.md] § 2.
  final Widget child;

  /// Blur radius (constant in v1 — see spec assumption).
  final double sigma;

  static final _defaultBlurFilter = ui.ImageFilter.blur(
    sigmaX: 6.0,
    sigmaY: 6.0,
  );

  @override
  Widget build(BuildContext context) {
    if (revealed) return child;
    final filter = sigma == 6.0
        ? _defaultBlurFilter
        : ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    return ImageFiltered(imageFilter: filter, child: child);
  }
}
