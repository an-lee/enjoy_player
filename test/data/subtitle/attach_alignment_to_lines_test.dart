import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

import 'package:enjoy_player/data/subtitle/attach_alignment_to_lines.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';

TimelineEntry _word({
  required String text,
  required double start,
  required double end,
  List<TimelineEntry>? phones,
}) {
  return TimelineEntry(
    type: TimelineEntryType.word,
    text: text,
    startTime: start,
    endTime: end,
    timeline: phones,
  );
}

TimelineEntry _phone({
  required String phone,
  required double start,
  required double end,
}) {
  return TimelineEntry(
    type: TimelineEntryType.phone,
    text: phone,
    startTime: start,
    endTime: end,
  );
}

void main() {
  const line0 = TranscriptLine(
    text: 'Hello world',
    startMs: 0,
    durationMs: 1000,
  );
  const line1 = TranscriptLine(text: 'Goodbye', startMs: 1200, durationMs: 800);

  AlignmentResult resultWith(List<TimelineEntry> timeline) {
    return AlignmentResult(
      timeline: timeline,
      wordTimeline: const [],
      transcript: 'Hello world Goodbye',
      language: 'en-US',
      durationSeconds: 2.0,
    );
  }

  test('keeps line fields and maps word ms relative to each line', () {
    final result = resultWith([
      TimelineEntry(
        type: TimelineEntryType.segment,
        text: 'Hello world',
        startTime: 0,
        endTime: 1.0,
        id: 0,
        timeline: [
          _word(
            text: 'Hello',
            start: 0.05,
            end: 0.40,
            phones: [
              _phone(phone: 'h', start: 0.05, end: 0.12),
              _phone(phone: 'ə', start: 0.12, end: 0.40),
            ],
          ),
          _word(text: 'world', start: 0.45, end: 0.90),
        ],
      ),
      TimelineEntry(
        type: TimelineEntryType.segment,
        text: 'Goodbye',
        startTime: 1.2,
        endTime: 2.0,
        id: 1,
        timeline: [
          _word(
            text: 'Goodbye',
            start: 1.25,
            end: 1.90,
            phones: [_phone(phone: 'g', start: 1.25, end: 1.40)],
          ),
        ],
      ),
    ]);

    final out = attachAlignmentToLines([line0, line1], result);
    expect(out, hasLength(2));
    expect(out[0].text, line0.text);
    expect(out[0].startMs, line0.startMs);
    expect(out[0].durationMs, line0.durationMs);
    expect(out[1].text, line1.text);
    expect(out[1].startMs, line1.startMs);
    expect(out[1].durationMs, line1.durationMs);

    final hello = out[0].timeline!;
    expect(hello.map((w) => w.text), ['Hello', 'world']);
    expect(hello[0].startMs, 50);
    expect(hello[0].durationMs, 350);
    expect(hello[1].startMs, 450);

    final helloPhones = hello[0].phones!;
    expect(helloPhones, hasLength(2));
    expect(helloPhones[0].phone, 'h');
    expect(helloPhones[0].startTime, 0.05);
    expect(helloPhones[0].endTime, 0.12);
    expect(helloPhones[0].wordIndex, 0);
    expect(helloPhones[1].wordIndex, 0);

    final byePhones = out[1].timeline!.single.phones!;
    expect(byePhones.single.wordIndex, 0);
    expect(byePhones.single.startTime, 1.25);
  });

  test('missing segment leaves that line line-only; siblings may nest', () {
    final result = resultWith([
      TimelineEntry(
        type: TimelineEntryType.segment,
        text: 'Hello world',
        startTime: 0,
        endTime: 1.0,
        id: 0,
        timeline: [_word(text: 'Hello', start: 0.0, end: 0.5)],
      ),
    ]);

    final out = attachAlignmentToLines([line0, line1], result);
    expect(out[0].timeline, isNotNull);
    expect(out[1].timeline, isNull);
    expect(out[1].text, line1.text);
    expect(out[1].startMs, line1.startMs);
  });

  test('wordIndex is rebased per line, not flatten-global', () {
    final result = resultWith([
      TimelineEntry(
        type: TimelineEntryType.segment,
        text: 'Hello world',
        startTime: 0,
        endTime: 1.0,
        id: 0,
        timeline: [
          _word(
            text: 'Hello',
            start: 0.0,
            end: 0.4,
            phones: [_phone(phone: 'h', start: 0.0, end: 0.1)],
          ),
          _word(
            text: 'world',
            start: 0.4,
            end: 0.9,
            phones: [_phone(phone: 'w', start: 0.4, end: 0.5)],
          ),
        ],
      ),
      TimelineEntry(
        type: TimelineEntryType.segment,
        text: 'Goodbye',
        startTime: 1.2,
        endTime: 2.0,
        id: 1,
        timeline: [
          _word(
            text: 'Goodbye',
            start: 1.3,
            end: 1.8,
            phones: [_phone(phone: 'g', start: 1.3, end: 1.4)],
          ),
        ],
      ),
    ]);

    final out = attachAlignmentToLines([line0, line1], result);
    expect(out[0].timeline![0].phones!.single.wordIndex, 0);
    expect(out[0].timeline![1].phones!.single.wordIndex, 1);
    expect(out[1].timeline!.single.phones!.single.wordIndex, 0);
  });

  test('round-trip JSON preserves nested fields', () {
    final result = resultWith([
      TimelineEntry(
        type: TimelineEntryType.segment,
        text: 'Hello world',
        startTime: 0,
        endTime: 1.0,
        id: 0,
        timeline: [
          _word(
            text: 'Hello',
            start: 0.1,
            end: 0.4,
            phones: [_phone(phone: 'h', start: 0.1, end: 0.2)],
          ),
        ],
      ),
    ]);
    final attached = attachAlignmentToLines([line0], result).single;
    final roundTripped = TranscriptLine.fromJson(attached.toJson());
    expect(roundTripped, attached);
  });
}
