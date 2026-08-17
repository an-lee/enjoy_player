/// Map a transcript language tag onto the on-device alignment catalog.
library;

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:forced_alignment/forced_alignment.dart';

/// Maps a transcript / Craft language (`en`, `en-GB`, `ja`) onto an alignment
/// catalog tag. Returns null when the language is not in the focus map —
/// callers must fail closed, not swap to English.
String? alignmentLanguageForTranscript(String language) {
  final trimmed = language.trim();
  if (trimmed.isEmpty) return null;
  if (isSupportedAlignmentLanguage(trimmed)) return trimmed;
  final focus = canonicalFocusLanguageTag(trimmed);
  if (!isSupportedAlignmentLanguage(focus)) return null;
  if (primaryLanguageSubtag(trimmed) != primaryLanguageSubtag(focus)) {
    return null;
  }
  return focus;
}
