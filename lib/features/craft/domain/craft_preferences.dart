/// Remembered Craft options (mode, per-mode style, custom prompt, voices).
library;

import 'package:flutter/foundation.dart';

import 'azure_voice.dart';
import 'craft_screen_mode.dart';
import 'translation_style.dart';

/// User's last-used Craft choices, persisted across sessions.
///
/// The language pair is deliberately absent — it always re-seeds from the
/// learner's profile settings on entry (`AppPreferencesCtrl`).
@immutable
class CraftPreferences {
  const CraftPreferences({
    this.screenMode = CraftScreenMode.express,
    this.expressStyle = TranslationStyle.auto,
    this.advancedStyle = TranslationStyle.natural,
    this.customPrompt,
    this.voices = const {},
  });

  static const CraftPreferences defaults = CraftPreferences();

  /// Last screen layout the user chose.
  final CraftScreenMode screenMode;

  /// Remembered translation style, kept separately per screen mode.
  final TranslationStyle expressStyle;
  final TranslationStyle advancedStyle;

  /// Last custom prompt typed for the custom style (or Translate tool).
  final String? customPrompt;

  /// Base language code (e.g. `'en'`) → Azure voice id the user picked.
  final Map<String, String> voices;

  TranslationStyle styleFor(CraftScreenMode mode) =>
      mode == CraftScreenMode.express ? expressStyle : advancedStyle;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CraftPreferences &&
        other.screenMode == screenMode &&
        other.expressStyle == expressStyle &&
        other.advancedStyle == advancedStyle &&
        other.customPrompt == customPrompt &&
        mapEquals(other.voices, voices);
  }

  @override
  int get hashCode => Object.hash(
    screenMode,
    expressStyle,
    advancedStyle,
    customPrompt,
    Object.hashAllUnordered(voices.entries),
  );

  CraftPreferences copyWith({
    CraftScreenMode? screenMode,
    TranslationStyle? expressStyle,
    TranslationStyle? advancedStyle,
    String? customPrompt,
    bool clearCustomPrompt = false,
    Map<String, String>? voices,
  }) {
    return CraftPreferences(
      screenMode: screenMode ?? this.screenMode,
      expressStyle: expressStyle ?? this.expressStyle,
      advancedStyle: advancedStyle ?? this.advancedStyle,
      customPrompt: clearCustomPrompt
          ? null
          : (customPrompt ?? this.customPrompt),
      voices: voices ?? this.voices,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'v': 1,
      'screenMode': screenMode.name,
      'expressStyle': expressStyle.name,
      'advancedStyle': advancedStyle.name,
      if (customPrompt != null && customPrompt!.isNotEmpty)
        'customPrompt': customPrompt,
      if (voices.isNotEmpty) 'voices': voices,
    };
  }

  /// Total decode: unknown / ill-typed fields fall back per field instead of
  /// throwing; a foreign schema version ignores the whole blob.
  static CraftPreferences fromJson(Map<String, dynamic> json) {
    if (json['v'] != 1) return defaults;

    final screenMode = CraftScreenMode.values.firstWhere(
      (m) => m.name == json['screenMode'],
      orElse: () => defaults.screenMode,
    );
    final expressStyle = _styleFromJson(
      json['expressStyle'],
      fallback: defaults.expressStyle,
    );
    final advancedStyle = _styleFromJson(
      json['advancedStyle'],
      fallback: defaults.advancedStyle,
    );
    final prompt = json['customPrompt'];
    final customPrompt = prompt is String && prompt.isNotEmpty ? prompt : null;
    final voices = _voicesFromJson(json['voices']);

    return CraftPreferences(
      screenMode: screenMode,
      expressStyle: expressStyle,
      advancedStyle: advancedStyle,
      customPrompt: customPrompt,
      voices: voices,
    );
  }

  static TranslationStyle _styleFromJson(
    Object? raw, {
    required TranslationStyle fallback,
  }) {
    return TranslationStyle.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => fallback,
    );
  }

  /// Keeps only entries whose id exists in the catalog and whose voice's
  /// base language matches the (lowercased) key.
  static Map<String, String> _voicesFromJson(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((key, value) {
      if (key is! String || value is! String) return;
      final base = key.toLowerCase();
      final voice = kAzureVoices.where((v) => v.id == value).firstOrNull;
      if (voice == null || voice.baseLang != base) return;
      out[base] = value;
    });
    return out;
  }
}
