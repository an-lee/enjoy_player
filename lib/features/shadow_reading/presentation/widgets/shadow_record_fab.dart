import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/presentation/onboarding_target.dart';

/// Record FAB with a circular countdown ring + over-target pulse animation.
///
/// Extracted from `shadow_reading_panel.dart` — see issue #180.
class ShadowRecordFab extends StatelessWidget {
  const ShadowRecordFab({
    required this.recording,
    required this.echoActive,
    required this.ringProgress,
    required this.overTarget,
    required this.overPulseHigh,
    required this.showProgressArc,
    required this.onTap,
    required this.scheme,
    required this.tok,
    super.key,
  });

  /// Outer hit target / ring diameter; keep in sync with the toolbar slot in
  /// [ShadowReadingToolbarRow].
  static const double ringOuterHitSize = 56;
  static const double _fabInner = 44;

  final bool recording;
  final bool echoActive;
  final double ringProgress;
  final bool overTarget;
  final bool overPulseHigh;
  final bool showProgressArc;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final EnjoyThemeTokens tok;

  @override
  Widget build(BuildContext context) {
    final scale = overTarget ? (overPulseHigh ? 1.04 : 1.0) : 1.0;
    final trackAlpha = showProgressArc ? 0.38 : 0.18;
    final iconSize = _fabInner <= 44 ? 22.0 : (_fabInner <= 56 ? 24.0 : 28.0);

    return OnboardingTarget(
      tipId: OnboardingTipId.playerRecord,
      onTargetAction: echoActive ? onTap : null,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: ringOuterHitSize,
          height: ringOuterHitSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: const Size(ringOuterHitSize, ringOuterHitSize),
                painter: ShadowRecordRingPainter(
                  progress: ringProgress,
                  overTarget: overTarget,
                  trackColor: scheme.outlineVariant.withValues(
                    alpha: trackAlpha,
                  ),
                  fillColor: overTarget ? scheme.error : scheme.primary,
                  showProgressArc: showProgressArc,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: echoActive ? onTap : null,
                  child: AnimatedContainer(
                    duration: tok.motionFast,
                    width: _fabInner,
                    height: _fabInner,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: recording ? tok.echoActive : scheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: (recording ? tok.echoActive : scheme.primary)
                              .withValues(alpha: 0.35),
                          blurRadius: recording ? 22 : 12,
                          spreadRadius: recording ? 2 : 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      recording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: recording ? Colors.white : scheme.onPrimary,
                      size: iconSize,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular countdown progress ring + over-target full-arc indicator.
class ShadowRecordRingPainter extends CustomPainter {
  ShadowRecordRingPainter({
    required this.progress,
    required this.overTarget,
    required this.trackColor,
    required this.fillColor,
    required this.showProgressArc,
  });

  final double progress;
  final bool overTarget;
  final Color trackColor;
  final Color fillColor;
  final bool showProgressArc;

  static const double _strokeWidth = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - _strokeWidth / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (!showProgressArc) return;

    final arcPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    if (overTarget) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, arcPaint);
    } else {
      final remaining = (1.0 - progress.clamp(0.0, 1.0));
      final sweep = 2 * math.pi * remaining;
      canvas.drawArc(rect, -math.pi / 2, sweep, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ShadowRecordRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.overTarget != overTarget ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.showProgressArc != showProgressArc;
  }
}
