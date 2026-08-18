/// v1 language bar — must stay equal to app `kSupportedFocusLanguageTags`.
const List<String> kSupportedAlignmentLanguageTags = [
  'en-US',
  'en-GB',
  'ja-JP',
  'ko-KR',
  'es-ES',
  'es-MX',
  'fr-FR',
  'fr-CA',
];

/// eSpeak-NG voice ids for [kSupportedAlignmentLanguageTags].
const Map<String, String> kEspeakVoiceByLanguageTag = {
  'en-US': 'en-us',
  'en-GB': 'en-gb',
  'ja-JP': 'ja',
  'ko-KR': 'ko',
  'es-ES': 'es',
  'es-MX': 'es-419',
  'fr-FR': 'fr-fr',
  'fr-CA': 'fr-ca',
};

bool isSupportedAlignmentLanguage(String languageTag) =>
    kEspeakVoiceByLanguageTag.containsKey(languageTag);

String? espeakVoiceFor(String languageTag) =>
    kEspeakVoiceByLanguageTag[languageTag];

/// Files that must exist inside a packaged `espeak-ng-data` directory.
///
/// Keep `.github/scripts/check_bundled_espeak_data.sh` in sync.
List<String> get kEspeakRequiredDataRelativePaths => [
  'phontab',
  for (final voice in kEspeakVoiceByLanguageTag.values) 'lang/$voice',
];
