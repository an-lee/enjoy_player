/// Adaptive page families — width + chrome conventions for shell content.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

/// Page layout family. Pick one per screen; see ADR-0055 / docs/features/app-ui.md.
enum EnjoyPageKind {
  /// Full content-pane width (Home, Discover, Library, channel feeds).
  browse,

  /// Centered hub column (Profile, Settings, Subscription, …).
  hub,

  /// Centered form column (Preferences, Edit Profile, …).
  form,

  /// Narrow auth column (sign-in).
  auth,
}

/// Horizontal gutter for [paneWidth] using compact vs default tokens.
double pageGutterOf(BuildContext context, double paneWidth) {
  final t = EnjoyThemeTokens.of(context);
  return paneWidth < t.breakpointCompact ? t.pageGutterCompact : t.pageGutter;
}

/// Max content width for [kind], or `null` when the pane should be full-bleed.
double? maxWidthForPageKind(EnjoyThemeTokens tokens, EnjoyPageKind kind) {
  return switch (kind) {
    EnjoyPageKind.browse => null,
    EnjoyPageKind.hub => tokens.hubMaxWidth,
    EnjoyPageKind.form => tokens.formMaxWidth,
    EnjoyPageKind.auth => tokens.modalMaxWidth,
  };
}

/// Metrics for building adaptive page bodies (gutters + optional width cap).
@immutable
class EnjoyPageMetrics {
  const EnjoyPageMetrics({
    required this.kind,
    required this.paneWidth,
    required this.gutter,
    required this.maxWidth,
    required this.horizontalInset,
  });

  final EnjoyPageKind kind;
  final double paneWidth;
  final double gutter;

  /// Cap for this kind, or `null` for full-bleed browse/player.
  final double? maxWidth;

  /// Left/right inset that centers a capped column (or applies [gutter] when
  /// full-bleed).
  final double horizontalInset;

  /// Content padding with kind horizontal insets + custom vertical.
  EdgeInsets padding({double top = 0, double bottom = 0}) {
    return EdgeInsets.fromLTRB(horizontalInset, top, horizontalInset, bottom);
  }

  static EnjoyPageMetrics of(
    BuildContext context, {
    required EnjoyPageKind kind,
    required double paneWidth,
  }) {
    final t = EnjoyThemeTokens.of(context);
    final gutter = pageGutterOf(context, paneWidth);
    final maxWidth = maxWidthForPageKind(t, kind);
    final horizontalInset = maxWidth == null
        ? gutter
        : math.max(gutter, (paneWidth - maxWidth) / 2);
    return EnjoyPageMetrics(
      kind: kind,
      paneWidth: paneWidth,
      gutter: gutter,
      maxWidth: maxWidth,
      horizontalInset: horizontalInset,
    );
  }
}
