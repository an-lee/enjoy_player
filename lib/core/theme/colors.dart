/// Semantic color tokens — neutral zinc dark base, logo-aligned blue/purple accent.
/// Dynamic color from artwork is handled separately in dynamic_color/.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Echo & feature accents ──────────────────────────────────────────────
  static const echoActive = Color(0xFFE65100);

  /// Listening-focus / blur practice accent (cool teal, distinct from echo's
  /// warm orange and the brand purple).
  static const blurActive = Color(0xFF00897B);

  // ── Brand — Premium Purple ──────────────────────────────────────────────
  static const brand = Color(0xFF7B61FF);
  static const brandSecondary = Color(0xFF4797F5);

  /// High-legibility primary tint on dark surfaces (text, icons, outlines).
  static const brandOnDark = Color(0xFFB2A1FF);

  /// Subtle soft tint for brand accent (15% opacity).
  static const accentSoft = Color(0x267B61FF);

  // ── Assessment / Scoring semantic tokens ────────────────────────────────
  /// Evaluation & accuracy good (emerald green).
  static const scoreGood = Color(0xFF22C55E);

  /// Evaluation & accuracy warning / mid-tier (amber gold).
  static const scoreWarn = Color(0xFFF59E0B);

  /// Evaluation & accuracy bad / miss (coral red).
  static const scoreBad = Color(0xFFEF4444);

  /// Soft container background for good score items (14% alpha).
  static const scoreGoodContainer = Color(0x2422C55E);

  /// Soft container background for warn score items (14% alpha).
  static const scoreWarnContainer = Color(0x24F59E0B);

  /// Soft container background for bad score items (16% alpha).
  static const scoreBadContainer = Color(0x29EF4444);

  // ── Dark surface ramp — zinc-style neutral ──────────────────────────────
  static const surfaceDark = Color(0xFF09090B);
  static const surfaceContainerLowestDark = Color(0xFF000000);
  static const surfaceContainerLowDark = Color(0xFF09090B);
  static const surfaceContainerDark = Color(0xFF18181B);
  static const surfaceContainerHighDark = Color(0xFF27272A);
  static const surfaceContainerHighestDark = Color(0xFF3F3F46);

  // ── Backdrop gradient for non-player routes ────────────────────────────
  static const gradientStartDark = Color(0xFF18181B);
  static const gradientEndDark = Color(0xFF09090B);

  // ── Seed for Material 3 ColorScheme.fromSeed ──────────────────────────
  static const seedBrand = brand;
}
