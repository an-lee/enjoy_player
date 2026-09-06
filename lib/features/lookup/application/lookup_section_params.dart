/// Parameter objects for lookup sheet Riverpod families (value equality).
library;

import 'package:flutter/foundation.dart';

/// Shared shape for every lookup request: the query text plus the source →
/// target language pair. Equality lives here so the three concrete params
/// classes below stay in sync as lookup-sheet cache map keys.
@immutable
base class LookupTextParams {
  const LookupTextParams({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  final String text;
  final String sourceLanguage;
  final String targetLanguage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LookupTextParams &&
          text == other.text &&
          sourceLanguage == other.sourceLanguage &&
          targetLanguage == other.targetLanguage;

  @override
  int get hashCode => Object.hash(text, sourceLanguage, targetLanguage);
}

@immutable
final class LookupTranslationParams extends LookupTextParams {
  const LookupTranslationParams({
    required super.text,
    required super.sourceLanguage,
    required super.targetLanguage,
  });
}

/// Contextual translation params add an optional surrounding-text [context].
@immutable
final class LookupContextualParams extends LookupTextParams {
  const LookupContextualParams({
    required super.text,
    required super.sourceLanguage,
    required super.targetLanguage,
    this.context,
  });

  final String? context;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LookupContextualParams &&
          super == other &&
          context == other.context;

  @override
  int get hashCode => Object.hash(super.hashCode, context);
}

@immutable
final class LookupDictionaryParams extends LookupTextParams {
  const LookupDictionaryParams({
    required super.text,
    required super.sourceLanguage,
    required super.targetLanguage,
  });
}
