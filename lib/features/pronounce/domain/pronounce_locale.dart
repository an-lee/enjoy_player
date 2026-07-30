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

/// Bare / unknown-region primary → default regional Worker locale.
///
/// Vocabulary items and recordings often store ISO 639-1 primaries (`ja`,
/// `zh`). Never cross into a different primary language.
const Map<String, String> kPronounceDefaultLocaleByPrimary = <String, String>{
  'en': 'en-US',
  'zh': 'zh-CN',
  'ja': 'ja-JP',
  'ko': 'ko-KR',
  'es': 'es-ES',
  'fr': 'fr-FR',
  'de': 'de-DE',
  'it': 'it-IT',
  'pt': 'pt-BR',
  'ru': 'ru-RU',
};

const int kPronounceMaxChars = 200;

/// Resolves [tag] to a Worker pronounce locale, or `null` if unsupported.
///
/// - `en-UK` → `en-GB`
/// - bare / other `en*` (not GB/UK) → `en-US`
/// - exact allowlist match for remaining tags
/// - bare primary (`ja`, `zh`, …) or unknown region → primary default when
///   that default is allowlisted
String? resolvePronounceLocale(String? tag) {
  if (tag == null || tag.trim().isEmpty) return null;
  final normalized = normalizeBcp47Tag(normalizeLanguageAlias(tag.trim()));
  if (normalized.isEmpty) return null;
  if (!isValidLanguageTag(normalized)) return null;

  if (normalized == 'en-UK' || tagsEqual(normalized, 'en-GB')) {
    return 'en-GB';
  }

  for (final supported in kPronounceSupportedLocales) {
    if (tagsEqual(normalized, supported)) return supported;
  }

  final primary = primaryLanguageSubtag(normalized);
  if (primary == 'en') {
    return 'en-US';
  }

  final byPrimary = kPronounceDefaultLocaleByPrimary[primary];
  if (byPrimary != null && kPronounceSupportedLocales.contains(byPrimary)) {
    return byPrimary;
  }
  return null;
}

/// Whether [text] is eligible for a pronounce request (after trim).
bool isPronounceTextEligible(String text) {
  final t = text.trim();
  return t.isNotEmpty && t.length <= kPronounceMaxChars;
}
