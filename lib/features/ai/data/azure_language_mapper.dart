/// Maps transcript / ISO-ish language codes to Azure Speech locale strings.
library;

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:logging/logging.dart';

final Logger _log = logNamed('ai.azure_language');

/// Resolves [languageCode] to a supported Azure pronunciation assessment locale.
///
/// Returns `null` when the language is unknown, invalid, or not supported by Azure.
/// Callers must not fall back to English when this returns `null`.
String? mapTranscriptLanguageToAzure(String? languageCode) {
  final resolved = resolveAzureAssessmentLocale(languageCode);
  if (resolved == null &&
      languageCode != null &&
      languageCode.trim().isNotEmpty) {
    _log.fine("Azure assessment locale unsupported for '$languageCode'");
  }
  return resolved;
}
