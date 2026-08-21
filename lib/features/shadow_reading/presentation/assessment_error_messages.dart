/// Maps raw Azure pronunciation error-type strings to localized labels and
/// explanations used by the assessment result UI.
///
/// Promoted from the legacy `_errorTypeLabel` / `_errorExplanation` helpers in
/// `assessment_result_dialog.dart` so they can be unit-tested in isolation
/// without depending on the surrounding playback-stack widgets.
library;

import 'package:enjoy_player/l10n/app_localizations.dart';

/// Localized human-readable label for an Azure pronunciation error type.
///
/// Falls back to the raw token for unrecognized values so the UI surfaces the
/// raw Azure error rather than silently dropping it.
String assessmentErrorTypeLabel(AppLocalizations l10n, String errorType) {
  return switch (errorType) {
    'Omission' => l10n.assessmentErrorTypeOmission,
    'Insertion' => l10n.assessmentErrorTypeInsertion,
    'Mispronunciation' => l10n.assessmentErrorTypeMispronunciation,
    'UnexpectedBreak' => l10n.assessmentErrorTypeUnexpectedBreak,
    'MissingBreak' => l10n.assessmentErrorTypeMissingBreak,
    'Monotone' => l10n.assessmentErrorTypeMonotone,
    'None' => l10n.assessmentErrorTypeCorrect,
    _ => errorType,
  };
}

/// Localized explanation for an Azure pronunciation error type.
///
/// Returns the generic "correct" explanation for both `'None'` and any
/// unrecognized values so the UI never falls through to an empty sentence.
String assessmentErrorExplanation(AppLocalizations l10n, String errorType) {
  return switch (errorType) {
    'Omission' => l10n.assessmentErrorExplOmission,
    'Insertion' => l10n.assessmentErrorExplInsertion,
    'Mispronunciation' => l10n.assessmentErrorExplMispronunciation,
    'UnexpectedBreak' => l10n.assessmentErrorExplUnexpectedBreak,
    'MissingBreak' => l10n.assessmentErrorExplMissingBreak,
    'Monotone' => l10n.assessmentErrorExplMonotone,
    'None' => l10n.assessmentErrorExplCorrect,
    _ => l10n.assessmentErrorExplCorrect,
  };
}
