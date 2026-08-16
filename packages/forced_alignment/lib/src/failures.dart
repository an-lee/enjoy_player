/// Why [align] / [alignSegments] did not produce an [AlignmentResult].
enum AlignmentFailureReason {
  audioUnavailable,
  tooShort,
  blankText,
  unsupportedLanguage,
  wholeClipTooLong,
  cancelled,
  timedOut,
  spokenReferenceUnavailable,
  internal,
}

/// Typed failure. Never encoded as an empty successful word list.
final class AlignmentFailure {
  const AlignmentFailure({required this.reason, this.message});

  final AlignmentFailureReason reason;
  final String? message;

  @override
  String toString() =>
      'AlignmentFailure($reason${message == null ? '' : ': $message'})';
}
