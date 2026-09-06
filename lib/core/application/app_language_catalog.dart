/// Supported display / learning / native / media language tags.
library;

import 'package:flutter/material.dart';

// Shared separator for BCP-47 / language-tag splits. The hyphen-or-underscore
// pattern was repeated in five call sites; routing it through [_splitLanguageTag]
// keeps the character class in one place. File-private so the post-commit lint
// pass cannot revert a public symbol.
final RegExp _kLanguageTagSeparator = RegExp(r'[-_]');

List<String> _splitLanguageTag(String tag) => tag.split(_kLanguageTagSeparator);

/// Default UI locale when none is stored and not overridden by profile.
const Locale kAppDefaultDisplayLocale = Locale('zh', 'CN');

/// Selectable app UI locales (Material [Locale] → BCP-47 via [localeToBcp47]).
const List<Locale> kAppDisplayLocales = <Locale>[
  Locale('en', 'US'),
  Locale('zh', 'CN'),
];

const String kDefaultLearningLanguageTag = 'en-US';

const String kDefaultNativeLanguageTag = 'zh-CN';

const String kUnknownMediaLanguageTag = 'und';

const List<String> kSupportedNativeLanguageTags = <String>['en-US', 'zh-CN'];

/// Focus learning languages selectable in settings/profile (first wave).
const List<String> kSupportedFocusLanguageTags = <String>[
  'en-US',
  'en-GB',
  'ja-JP',
  'ko-KR',
  'es-ES',
  'es-MX',
  'fr-FR',
  'fr-CA',
];

/// Media content language choices (includes Unknown).
const List<String> kSupportedMediaLanguageTags = <String>[
  kUnknownMediaLanguageTag,
  ...kSupportedFocusLanguageTags,
];

/// Azure Speech pronunciation assessment locales (Microsoft language-support table).
const Set<String> kAzurePronunciationAssessmentLocales = <String>{
  'ar-EG',
  'ar-SA',
  'ca-ES',
  'zh-HK',
  'zh-CN',
  'zh-TW',
  'da-DK',
  'nl-NL',
  'en-AU',
  'en-CA',
  'en-IN',
  'en-GB',
  'en-US',
  'fi-FI',
  'fr-CA',
  'fr-FR',
  'de-DE',
  'hi-IN',
  'it-IT',
  'ja-JP',
  'ko-KR',
  'ms-MY',
  'nb-NO',
  'pl-PL',
  'pt-BR',
  'pt-PT',
  'ru-RU',
  'es-MX',
  'es-ES',
  'sv-SE',
  'ta-IN',
  'th-TH',
  'vi-VN',
};

/// Preferred Azure locale when a broad tag has multiple regional options.
const Map<String, String> kAzureDefaultLocaleByPrimary = <String, String>{
  'en': 'en-US',
  'ja': 'ja-JP',
  'ko': 'ko-KR',
  'es': 'es-ES',
  'fr': 'fr-FR',
  'zh': 'zh-CN',
};

/// ISO 639-2 / legacy aliases → ISO 639-1 primary subtag.
const Map<String, String> kLanguageTagAliases = <String, String>{
  'eng': 'en',
  'jpn': 'ja',
  'kor': 'ko',
  'spa': 'es',
  'fre': 'fr',
  'fra': 'fr',
  'zho': 'zh',
  'chi': 'zh',
};

/// ISO 639 / BCP-47 language subtags that must not be used for lookup or worker calls.
const Set<String> kInvalidLanguageTags = <String>{
  '',
  'und',
  'mul',
  'mis',
  'zxx',
};

/// Short UI labels for [kSupportedLookupLanguageTags] (lookup sheet pills / picker).
const Map<String, String> kLookupLanguageLabels = <String, String>{
  'en-US': 'English',
  'en-GB': 'English (UK)',
  'zh-CN': '中文',
  'ja-JP': '日本語',
  'ko-KR': '한국어',
  'es-ES': 'Español (España)',
  'es-MX': 'Español (México)',
  'fr-FR': 'Français (France)',
  'fr-CA': 'Français (Canada)',
  'de-DE': 'Deutsch',
  'it-IT': 'Italiano',
  'pt-BR': 'Português (Brasil)',
  'pt-PT': 'Português (Portugal)',
  'ru-RU': 'Русский',
};

/// Lookup-sheet source / target catalog (separate from profile / focus / media
/// lists so widening the lookup picker does not regress profile / settings UI).
///
/// First-wave tags cover the top languages requested by Enjoy Player users as
/// of 2026-07-08 and overlap with the Azure pronunciation-assessment locale
/// table where relevant.
const List<String> kSupportedLookupLanguageTags = <String>[
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
];

/// Sorts [tags] with the user's learning language first (primary-subtag
/// match), then alphabetical by primary subtag, then by region subtag.
/// Stable for ties; returns a new list (input is not mutated).
List<String> sortLookupLanguages(
  List<String> tags, {
  required String learningTag,
}) {
  final learnPrimary = primaryLanguageSubtag(normalizeBcp47Tag(learningTag));
  final indexed = List<MapEntry<String, int>>.generate(tags.length, (i) {
    return MapEntry<String, int>(tags[i], i);
  });
  indexed.sort((a, b) {
    final aTag = normalizeBcp47Tag(a.key);
    final bTag = normalizeBcp47Tag(b.key);
    final aPrimary = primaryLanguageSubtag(aTag);
    final bPrimary = primaryLanguageSubtag(bTag);
    final aIsLearn = aPrimary == learnPrimary;
    final bIsLearn = bPrimary == learnPrimary;
    if (aIsLearn != bIsLearn) return aIsLearn ? -1 : 1;
    final byPrimary = aPrimary.compareTo(bPrimary);
    if (byPrimary != 0) return byPrimary;
    final aParts = aTag.split('-');
    final bParts = bTag.split('-');
    final aRegion = aParts.length >= 2 ? aParts[1] : '';
    final bRegion = bParts.length >= 2 ? bParts[1] : '';
    final byRegion = aRegion.compareTo(bRegion);
    if (byRegion != 0) return byRegion;
    return a.value.compareTo(b.value);
  });
  return indexed.map((e) => e.key).toList(growable: false);
}

/// True when [tag] has a non-empty primary subtag not in [kInvalidLanguageTags].
bool isValidLanguageTag(String? tag) {
  if (tag == null) return false;
  final trimmed = tag.trim();
  if (trimmed.isEmpty) return false;
  final primary = primaryLanguageSubtag(trimmed);
  if (primary.isEmpty) return false;
  return !kInvalidLanguageTags.contains(primary);
}

/// Resolves legacy aliases such as `kor` → `ko`.
String normalizeLanguageAlias(String tag) {
  final trimmed = tag.trim();
  if (trimmed.isEmpty) return trimmed;
  final lower = trimmed.toLowerCase();
  final alias = kLanguageTagAliases[lower];
  if (alias != null) return alias;
  if (lower.contains('-') || lower.contains('_')) {
    final parts = _splitLanguageTag(lower);
    final primary = parts.first;
    final aliased = kLanguageTagAliases[primary];
    if (aliased != null && parts.length >= 2) {
      return '$aliased-${parts[1].toUpperCase()}';
    }
  }
  return trimmed;
}

/// Primary language subtag of [tag], lowercased (`en-US` → `en`, `kor` → `ko`).
///
/// Normalizes legacy aliases first (e.g. `kor` → `ko`) via [normalizeLanguageAlias],
/// then splits on `-` / `_` and returns the first subtag lowercased. Shared by the
/// catalog resolvers and the lookup language resolvers so both use one definition
/// of "same language" (see [matchesLanguageBroad], [resolveLookupSource], etc.).
String primaryLanguageSubtag(String tag) {
  final normalized = normalizeLanguageAlias(tag);
  return _splitLanguageTag(normalized).first.toLowerCase();
}

/// Maps a tag to a supported native tag (`en-US` / `zh-CN`), or `null` if unknown/invalid.
String? canonicalLookupTag(String? tag) {
  if (!isValidLanguageTag(tag)) return null;
  final trimmed = normalizeLanguageAlias(tag!.trim());
  final primary = primaryLanguageSubtag(trimmed);
  if (primary == 'en') return 'en-US';
  if (primary == 'zh') return 'zh-CN';
  final n = normalizeBcp47Tag(trimmed);
  for (final supported in kSupportedNativeLanguageTags) {
    if (tagsEqual(n, supported)) return supported;
  }
  return null;
}

/// Maps [tag] to a supported focus learning tag, or [kDefaultLearningLanguageTag].
String canonicalFocusLanguageTag(String? tag) {
  if (tag == null || tag.trim().isEmpty) return kDefaultLearningLanguageTag;
  final normalized = normalizeBcp47Tag(normalizeLanguageAlias(tag.trim()));
  for (final supported in kSupportedFocusLanguageTags) {
    if (tagsEqual(normalized, supported)) return supported;
  }
  final primary = primaryLanguageSubtag(normalized);
  for (final supported in kSupportedFocusLanguageTags) {
    if (primaryLanguageSubtag(supported) == primary) return supported;
  }
  return kDefaultLearningLanguageTag;
}

/// Maps [tag] to a supported media content tag, or [kUnknownMediaLanguageTag].
String canonicalMediaLanguageTag(String? tag) {
  if (tag == null || tag.trim().isEmpty) return kUnknownMediaLanguageTag;
  final trimmed = tag.trim();
  if (tagsEqual(trimmed, kUnknownMediaLanguageTag)) {
    return kUnknownMediaLanguageTag;
  }
  final normalized = normalizeBcp47Tag(normalizeLanguageAlias(trimmed));
  for (final supported in kSupportedMediaLanguageTags) {
    if (supported == kUnknownMediaLanguageTag) continue;
    if (tagsEqual(normalized, supported)) return supported;
  }
  final primary = primaryLanguageSubtag(normalized);
  for (final supported in kSupportedMediaLanguageTags) {
    if (supported == kUnknownMediaLanguageTag) continue;
    if (primaryLanguageSubtag(supported) == primary) return supported;
  }
  if (isValidLanguageTag(normalized)) return normalized;
  return kUnknownMediaLanguageTag;
}

/// True when [a] and [b] refer to the same language (broad or exact BCP-47 match).
bool matchesLanguageBroad(String? a, String? b) {
  if (a == null || b == null) return false;
  if (tagsEqual(a, b)) return true;
  return primaryLanguageSubtag(a) == primaryLanguageSubtag(b);
}

/// Resolves [tag] to an Azure pronunciation assessment locale, or `null` if unsupported.
String? resolveAzureAssessmentLocale(String? tag) {
  if (tag == null || tag.trim().isEmpty) return null;
  if (!isValidLanguageTag(tag)) return null;

  final normalized = normalizeBcp47Tag(normalizeLanguageAlias(tag.trim()));
  if (kAzurePronunciationAssessmentLocales.contains(normalized)) {
    return normalized;
  }

  final lower = normalized.toLowerCase();
  for (final locale in kAzurePronunciationAssessmentLocales) {
    if (locale.toLowerCase() == lower) return locale;
  }

  final primary = primaryLanguageSubtag(normalized);
  for (final locale in kAzurePronunciationAssessmentLocales) {
    if (primaryLanguageSubtag(locale) == primary) {
      if (normalizeBcp47Tag(normalized) == normalizeBcp47Tag(locale)) {
        return locale;
      }
    }
  }

  final defaultLocale = kAzureDefaultLocaleByPrimary[primary];
  if (defaultLocale != null &&
      kAzurePronunciationAssessmentLocales.contains(defaultLocale)) {
    return defaultLocale;
  }

  return null;
}

/// True for empty / denylisted media tags (`und`, `mul`, …) — not a real
/// spoken language choice, just "unknown content language".
bool isUnknownMediaLanguageTag(String? tag) {
  if (tag == null) return true;
  final trimmed = tag.trim();
  if (trimmed.isEmpty) return true;
  final primary = primaryLanguageSubtag(normalizeLanguageAlias(trimmed));
  return primary.isEmpty || kInvalidLanguageTags.contains(primary);
}

/// Azure locale for shadow-reading assessment.
///
/// Unknown media tags (`und` / empty — common for YouTube imports) fall back to
/// [learningLanguage] then [kDefaultLearningLanguageTag]. Real unsupported
/// languages still return `null` (no silent `en-US` coercion).
///
/// Restores pre-[33dace5] practice behavior for unknown media language without
/// reopening the unsupported-language loophole.
String? resolveAzureAssessmentLocaleForPractice(
  String? mediaOrRecordingLanguage, {
  String? learningLanguage,
}) {
  final direct = resolveAzureAssessmentLocale(mediaOrRecordingLanguage);
  if (direct != null) return direct;
  if (!isUnknownMediaLanguageTag(mediaOrRecordingLanguage)) return null;
  final fromLearning = resolveAzureAssessmentLocale(learningLanguage);
  if (fromLearning != null) return fromLearning;
  return resolveAzureAssessmentLocale(kDefaultLearningLanguageTag);
}

bool isAzurePronunciationAssessmentSupportedForPractice(
  String? mediaOrRecordingLanguage, {
  String? learningLanguage,
}) =>
    resolveAzureAssessmentLocaleForPractice(
      mediaOrRecordingLanguage,
      learningLanguage: learningLanguage,
    ) !=
    null;

/// Worker / web short language code: first subtag lowercased (`en-US` → `en`).
String workerLanguageBase(String tag) {
  final t = normalizeLanguageAlias(tag.trim());
  if (t.isEmpty) return 'en';
  return _splitLanguageTag(t).first.toLowerCase();
}

String normalizeBcp47Tag(String tag) {
  final t = normalizeLanguageAlias(tag.trim());
  if (t.isEmpty) return t;
  final parts = _splitLanguageTag(t);
  if (parts.length >= 2) {
    return '${parts[0].toLowerCase()}-${parts[1].toUpperCase()}';
  }
  return parts[0].toLowerCase();
}

bool tagsEqual(String a, String b) =>
    normalizeBcp47Tag(a) == normalizeBcp47Tag(b);

/// Native choices for the current learning language (native must ≠ learning).
List<String> allowedNativeTags(String learningTag) {
  final learn = normalizeBcp47Tag(learningTag);
  return kSupportedNativeLanguageTags
      .where((n) => !tagsEqual(n, learn))
      .toList(growable: false);
}

/// If [native] is null, empty, or equals [learning], pick a valid default.
String coerceNativeIfEqualsLearning(String? native, String learning) {
  final learn = normalizeBcp47Tag(learning);
  if (native == null || native.trim().isEmpty) {
    return _firstAllowedOrDefault(learn);
  }
  final n = normalizeBcp47Tag(native);
  if (tagsEqual(n, learn)) {
    return _firstAllowedOrDefault(learn);
  }
  if (!kSupportedNativeLanguageTags.any((t) => tagsEqual(t, n))) {
    return _firstAllowedOrDefault(learn);
  }
  return kSupportedNativeLanguageTags.firstWhere((t) => tagsEqual(t, n));
}

String _firstAllowedOrDefault(String normalizedLearning) {
  final allowed = allowedNativeTags(normalizedLearning);
  if (allowed.isNotEmpty) return allowed.first;
  return kDefaultNativeLanguageTag;
}

String localeToBcp47(Locale locale) => locale.toLanguageTag();

/// Maps [locale] to a supported display locale, or [kAppDefaultDisplayLocale].
Locale displayLocaleFromRawOrDefault(String? raw) {
  if (raw == null || raw.trim().isEmpty) return kAppDefaultDisplayLocale;
  final parts = _splitLanguageTag(raw.trim());
  // Normalize for case-insensitive match against [kAppDisplayLocales] (the
  // catalog stores BCP-47 canonical form: lowercase language, uppercase region).
  final Locale candidate = parts.length >= 2
      ? Locale(parts[0].toLowerCase(), parts[1].toUpperCase())
      : Locale(parts[0].toLowerCase());
  for (final loc in kAppDisplayLocales) {
    if (loc.languageCode == candidate.languageCode &&
        (loc.countryCode ?? '') == (candidate.countryCode ?? '')) {
      return loc;
    }
  }
  for (final loc in kAppDisplayLocales) {
    if (loc.languageCode == candidate.languageCode) return loc;
  }
  return kAppDefaultDisplayLocale;
}
