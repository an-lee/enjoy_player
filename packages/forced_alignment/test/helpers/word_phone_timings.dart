/// Test-side port of the deleted `lib/src/flatten.dart`: flattens a
/// recursive engine result to enjoy-web-shaped word/phone timings for
/// golden / regression assertions.
library;

import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/types.dart';

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

WordPhoneTimings flattenToWordPhoneTimings(AlignmentResult result) {
  final words = <WordTiming>[];
  final phones = <PhoneTiming>[];

  void walk(TimelineEntry entry, int? wordIndex) {
    switch (entry.type) {
      case TimelineEntryType.word:
        final text = entry.text.trim();
        if (text.isEmpty) return;
        final index = words.length;
        words.add(
          WordTiming(
            text: text,
            startTime: entry.startTime,
            endTime: entry.endTime,
          ),
        );
        final children = entry.timeline;
        if (children != null) {
          for (final child in children) {
            walk(child, index);
          }
        }
      case TimelineEntryType.phone:
        if (wordIndex == null) return;
        final label = entry.text.trim();
        if (label.isEmpty) return;
        phones.add(
          PhoneTiming(
            phone: label,
            text: label,
            startTime: entry.startTime,
            endTime: entry.endTime,
            wordIndex: wordIndex,
          ),
        );
      case TimelineEntryType.segment:
      case TimelineEntryType.sentence:
      case TimelineEntryType.token:
        final children = entry.timeline;
        if (children != null) {
          for (final child in children) {
            walk(child, wordIndex);
          }
        }
    }
  }

  for (final entry in result.timeline) {
    walk(entry, null);
  }
  if (words.isEmpty) {
    for (final entry in result.wordTimeline) {
      walk(entry, null);
    }
  }
  return WordPhoneTimings(words: words, phones: phones);
}
