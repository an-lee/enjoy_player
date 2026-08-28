import 'dart:typed_data';

import '../failures.dart';

/// Letters, digits, ASCII apostrophe (contractions), typographic apostrophes
/// (`don’t`), and combining marks (NFD `e\u0301`). Token spans are the displayed
/// orthography, so anything eSpeak pronounces as part of one word must stay
/// one token (issue #621).
final _wordPattern = RegExp(r"[\p{L}\p{N}\p{M}'’‘]+", unicode: true);

/// One [tokenizeWords] token with Dart string indexes into the source text.
final class WordSpan {
  const WordSpan({required this.text, required this.start, required this.end});

  final String text;
  final int start;
  final int end;
}

/// Word spans in transcript order. Punctuation-only text yields an empty list.
List<WordSpan> tokenizeWordSpans(String text) {
  return [
    for (final match in _wordPattern.allMatches(text))
      if (match.group(0)!.isNotEmpty)
        WordSpan(text: match.group(0)!, start: match.start, end: match.end),
  ];
}

/// Words in transcript order. Punctuation-only text yields an empty list.
List<String> tokenizeWords(String text) => [
  for (final span in tokenizeWordSpans(text)) span.text,
];

/// Thrown when a spoken reference cannot be produced.
final class SpokenReferenceException implements Exception {
  const SpokenReferenceException({
    this.reason = AlignmentFailureReason.spokenReferenceUnavailable,
    this.message,
  });

  final AlignmentFailureReason reason;
  final String? message;

  AlignmentFailure toFailure() =>
      AlignmentFailure(reason: reason, message: message);

  @override
  String toString() =>
      'SpokenReferenceException($reason${message == null ? '' : ': $message'})';
}

final class ReferencePhone {
  const ReferencePhone({
    required this.phone,
    required this.startTime,
    required this.endTime,
    required this.wordIndex,
  });

  final String phone;
  final double startTime;
  final double endTime;
  final int wordIndex;
}

final class ReferenceWord {
  const ReferenceWord({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.phones,
  });

  final String text;
  final double startTime;
  final double endTime;
  final List<ReferencePhone> phones;
}

/// Spoken rendering of known text. Times are on the **reference** timeline.
/// [pcm] is 16 kHz mono Float32. Duration may differ from the source clip.
final class ReferenceAudio {
  const ReferenceAudio({
    required this.pcm,
    required this.words,
    required this.durationSeconds,
  });

  final Float32List pcm;
  final List<ReferenceWord> words;
  final double durationSeconds;
}

/// Builds a same-language spoken reference. Production is eSpeak-NG.
/// Tests may inject a double. Do not stretch to the source clip duration.
abstract interface class SpokenReferenceSynthesizer {
  ReferenceAudio synthesize({required String text, required String language});
}
