import 'types.dart';
import 'web_timings.dart';

/// Flatten a recursive engine result to enjoy-web word/phone timings.
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
