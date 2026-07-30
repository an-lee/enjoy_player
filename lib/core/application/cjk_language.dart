/// Whether [languageTag] denotes a CJK language (Chinese, Japanese, Korean).
///
/// CJK scripts have no inter-word spaces, so transcript segmentation must break
/// by punctuation and spoken duration rather than by a Latin word-count rule.
/// See `specs/032-craft-shadow-cues/research.md` §R4.
library;

import 'app_language_catalog.dart';

/// Returns `true` when the primary language subtag of [languageTag] is
/// `zh`, `ja`, or `ko` (after normalizing legacy aliases like `zho`/`jpn`/`kor`).
bool isCjkLanguage(String languageTag) {
  switch (primaryLanguageSubtag(languageTag)) {
    case 'zh':
    case 'ja':
    case 'ko':
      return true;
    default:
      return false;
  }
}
