/// Editable snapshot of an existing `provider = 'craft'` media item.
///
/// Loaded by `CraftLibraryRepository.getCraftEditSource` and consumed by
/// `CraftController.loadForEdit` to prefill the Craft screen for editing.
library;

import 'package:flutter/foundation.dart';

@immutable
class CraftEditSource {
  const CraftEditSource({
    required this.mediaId,
    required this.practiceText,
    this.sourceText,
    required this.language,
    this.voice,
    this.sourceFlag,
  });

  /// Media id of the existing Crafted audio row.
  final String mediaId;

  /// The learning-language text that was synthesized: timeline join when a
  /// solid AI transcript exists, otherwise [Audios.description] (full practice
  /// text), else [Audios.sourceText] for legacy/Advanced rows.
  final String practiceText;

  /// Native-language source text (`Audios.sourceText`) — the raw ASR
  /// transcript for Express items, or empty for Advanced "speak directly".
  final String? sourceText;

  /// Canonical learning-language tag the audio was synthesized in.
  final String language;

  /// Azure Neural voice id used for synthesis, if any.
  final String? voice;

  /// `craft-express` | `craft-translate` | `craft-direct`.
  final String? sourceFlag;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CraftEditSource &&
        other.mediaId == mediaId &&
        other.practiceText == practiceText &&
        other.sourceText == sourceText &&
        other.language == language &&
        other.voice == voice &&
        other.sourceFlag == sourceFlag;
  }

  @override
  int get hashCode => Object.hash(
    mediaId,
    practiceText,
    sourceText,
    language,
    voice,
    sourceFlag,
  );
}
