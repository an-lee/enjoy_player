/// Enjoy-web `@enjoy/alignment` word timing (seconds on source audio).
final class WordTiming {
  const WordTiming({
    required this.text,
    required this.startTime,
    required this.endTime,
  });

  final String text;
  final double startTime;
  final double endTime;
}

/// Enjoy-web `@enjoy/alignment` / slice-1 phone timing (seconds).
final class PhoneTiming {
  const PhoneTiming({
    required this.phone,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.wordIndex,
  });

  final String phone;
  final String text;
  final double startTime;
  final double endTime;
  final int? wordIndex;
}

final class WordPhoneTimings {
  const WordPhoneTimings({required this.words, required this.phones});

  final List<WordTiming> words;
  final List<PhoneTiming> phones;
}
