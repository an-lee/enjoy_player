/// Frosted glass panel (sidebar, transport bar).
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';

import '../enjoy_tokens.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.sigma,
    this.padding,
    this.borderRadius = 0,
    super.key,
  });

  final Widget child;
  final double? sigma;
  final EdgeInsetsGeometry? padding;

  /// Corner radius. `0` keeps the historical square clip used by full-bleed
  /// callers; the floating transport passes [EnjoyThemeTokens.radiusXl].
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final blurRaw = sigma ?? t.miniBarBlurSigma;
    final blur = _effectiveTransportBlur(blurRaw);
    final radius = BorderRadius.circular(borderRadius);

    Widget inner = Material(color: Colors.transparent, child: child);

    if (padding != null) {
      inner = Padding(padding: padding!, child: inner);
    }

    if (blur <= 0) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.92),
          border: Border.all(color: t.glassBorder),
          borderRadius: radius,
        ),
        child: inner,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.glassTint,
            border: Border.all(color: t.glassBorder),
            borderRadius: radius,
          ),
          child: inner,
        ),
      ),
    );
  }
}

/// Softer blur on Android to reduce GPU overdraw from [BackdropFilter] on transport.
double _effectiveTransportBlur(double sigma) {
  if (sigma <= 0) return sigma;
  if (defaultTargetPlatform == TargetPlatform.android) {
    return sigma > 10 ? 10 : sigma;
  }
  return sigma;
}
