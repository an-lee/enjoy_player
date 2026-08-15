import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

AlignmentResult _result({required List<TimelineEntry> timeline}) {
  final words = <TimelineEntry>[];
  void collect(TimelineEntry e) {
    if (e.type == TimelineEntryType.word) words.add(e);
    for (final c in e.timeline ?? const []) {
      collect(c);
    }
  }

  for (final e in timeline) {
    collect(e);
  }
  return AlignmentResult(
    timeline: timeline,
    wordTimeline: words,
    transcript: 'hello world',
    language: 'en-US',
    durationSeconds: 2,
  );
}

void main() {
  test('flattens words in order and phones with wordIndex', () {
    final result = _result(
      timeline: [
        TimelineEntry(
          type: TimelineEntryType.segment,
          text: 'hello world',
          startTime: 0,
          endTime: 2,
          timeline: [
            TimelineEntry(
              type: TimelineEntryType.word,
              text: 'hello',
              startTime: 0.1,
              endTime: 0.8,
              timeline: const [
                TimelineEntry(
                  type: TimelineEntryType.phone,
                  text: 'h',
                  startTime: 0.1,
                  endTime: 0.3,
                ),
                TimelineEntry(
                  type: TimelineEntryType.phone,
                  text: 'ə',
                  startTime: 0.3,
                  endTime: 0.8,
                ),
              ],
            ),
            const TimelineEntry(
              type: TimelineEntryType.word,
              text: 'world',
              startTime: 0.9,
              endTime: 1.8,
            ),
          ],
        ),
      ],
    );
    final flat = flattenToWordPhoneTimings(result);
    expect(flat.words.map((w) => w.text), ['hello', 'world']);
    expect(flat.phones.map((p) => p.phone), ['h', 'ə']);
    expect(flat.phones.every((p) => p.wordIndex == 0), isTrue);
    expect(flat.words.first.startTime, 0.1);
  });

  test('low granularity result has no phones when none in tree', () {
    final result = _result(
      timeline: const [
        TimelineEntry(
          type: TimelineEntryType.word,
          text: 'hello',
          startTime: 0,
          endTime: 1,
        ),
      ],
    );
    final flat = flattenToWordPhoneTimings(result);
    expect(flat.phones, isEmpty);
  });

  test('phones without a parent word are dropped', () {
    final result = _result(
      timeline: const [
        TimelineEntry(
          type: TimelineEntryType.phone,
          text: 'orphan',
          startTime: 0,
          endTime: 0.1,
        ),
      ],
    );
    final flat = flattenToWordPhoneTimings(result);
    expect(flat.words, isEmpty);
    expect(flat.phones, isEmpty);
  });

  test('empty word text is dropped', () {
    final result = _result(
      timeline: const [
        TimelineEntry(
          type: TimelineEntryType.word,
          text: '  ',
          startTime: 0,
          endTime: 1,
        ),
      ],
    );
    expect(flattenToWordPhoneTimings(result).words, isEmpty);
  });
}
