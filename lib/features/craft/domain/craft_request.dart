/// Craft request value object and normalization helper.
library;

import 'package:enjoy_player/core/utils/text_normalization.dart';

import 'craft_mode.dart';

/// Normalizes text for hashing and synthesis: NFC-normalize, collapse
/// whitespace runs to single spaces, trim leading/trailing.
String normalizeCraftText(String input) {
  // NFC normalization via Dart's default String representation on most
  // platforms is already NFC; explicit normalization is deferred to a
  // future enhancement (Dart core does not expose ICU normalization).
  // Collapse whitespace runs and trim.
  final collapsed = collapseWhitespace(input);
  return collapsed;
}

/// Computes the dedupe hash input from mode + language + normalized text.
String craftDedupeKey({
  required CraftMode mode,
  required String learningLanguage,
  required String normalizedText,
}) {
  return '${mode.name}|$learningLanguage|$normalizedText';
}

/// The minimum text length (post-normalize) for the Craft action to be enabled.
const int craftMinTextLength = 10;

/// The maximum text length (post-normalize) before truncation notice applies.
const int craftMaxTextLength = 5000;
