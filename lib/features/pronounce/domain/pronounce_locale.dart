/// Map app language tags → Worker `/pronounce` locales.
library;

import 'package:enjoy_player/core/application/app_language_catalog.dart';

/// Worker allowlist (learning + lookup catalogs).
const Set<String> kPronounceSupportedLocales = <String>{
  'en-US',
  'en-GB',
  'zh-CN',
  'ja-JP',
  'ko-KR',
  'es-ES',
  'es-MX',
  'fr-FR',
  'fr-CA',
  'de-DE',
  'it-IT',
  'pt-BR',
  'pt-PT',
  'ru-RU',
};

const int kPronounceMaxChars = 200;

/// Resolves [tag] to a Worker pronounce locale, or `null` if unsupported.
///
/// - `en-UK` → `en-GB`
/// - bare / other `en*` (not GB/UK) → `en-US`
/// - exact match for remaining allowlisted tags
String? resolvePronounceLocale(String? tag) {
  if (tag == null || tag.trim().isEmpty) return null;
  final normalized = normalizeBcp47Tag(tag);
  if (normalized.isEmpty) return null;

  if (normalized == 'en-UK' || tagsEqual(normalized, 'en-GB')) {
    return 'en-GB';
  }

  final primary = normalized.split('-').first.toLowerCase();
  if (primary == 'en') {
    return 'en-US';
  }

  for (final supported in kPronounceSupportedLocales) {
    if (tagsEqual(normalized, supported)) return supported;
  }
  return null;
}

/// Whether [text] is eligible for a pronounce request (after trim).
bool isPronounceTextEligible(String text) {
  final t = text.trim();
  return t.isNotEmpty && t.length <= kPronounceMaxChars;
}
