import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/subtitle/transcript_display_readiness.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';

void main() {
  const lineOnly = [
    TranscriptLine(text: 'Hello', startMs: 0, durationMs: 1000),
  ];

  const timedPhones = [
    TranscriptLine(
      text: 'Hello',
      startMs: 0,
      durationMs: 1000,
      timeline: [
        TranscriptWord(
          text: 'Hello',
          startMs: 0,
          durationMs: 800,
          phones: [
            TranscriptPhone(phone: 'h', text: 'h', startTime: 0, endTime: 0.4),
          ],
        ),
      ],
    ),
  ];

  const untimedPhones = [
    TranscriptLine(
      text: 'Hello',
      startMs: 0,
      durationMs: 1000,
      timeline: [
        TranscriptWord(
          text: 'Hello',
          phones: [TranscriptPhone(phone: 'h', text: 'h')],
        ),
      ],
    ),
  ];

  const timedNoPhones = [
    TranscriptLine(
      text: 'Hello',
      startMs: 0,
      durationMs: 1000,
      timeline: [TranscriptWord(text: 'Hello', startMs: 0, durationMs: 800)],
    ),
  ];

  test('empty lines hide enrich and disable switches', () {
    final r = transcriptDisplayReadiness(
      lines: const [],
      canTrustWordTimes: true,
    );
    expect(r.showEnrich, isFalse);
    expect(r.karaokeSwitchEnabled, isFalse);
    expect(r.ipaSwitchEnabled, isFalse);
    expect(r.hasNestedWords, isFalse);
  });

  test('line-only owned shows enrich and disables karaoke/IPA', () {
    final r = transcriptDisplayReadiness(
      lines: lineOnly,
      canTrustWordTimes: true,
    );
    expect(r.showEnrich, isTrue);
    expect(r.hasNestedWords, isFalse);
    expect(r.karaokeSwitchEnabled, isFalse);
    expect(r.ipaSwitchEnabled, isFalse);
  });

  test('timed+phones+owned enables karaoke and IPA and hides enrich', () {
    final r = transcriptDisplayReadiness(
      lines: timedPhones,
      canTrustWordTimes: true,
    );
    expect(r.showEnrich, isFalse);
    expect(r.hasTimedWords, isTrue);
    expect(r.hasPhones, isTrue);
    expect(r.karaokeSwitchEnabled, isTrue);
    expect(r.ipaSwitchEnabled, isTrue);
  });

  test('nested untimed words → karaoke off, IPA on if phones', () {
    final r = transcriptDisplayReadiness(
      lines: untimedPhones,
      canTrustWordTimes: false,
    );
    expect(r.hasNestedWords, isTrue);
    expect(r.hasTimedWords, isFalse);
    expect(r.hasPhones, isTrue);
    expect(r.karaokeSwitchEnabled, isFalse);
    expect(r.ipaSwitchEnabled, isTrue);
    expect(r.showEnrich, isFalse);
  });

  test('owned incomplete nested data still shows enrich', () {
    final untimed = transcriptDisplayReadiness(
      lines: untimedPhones,
      canTrustWordTimes: true,
    );
    expect(untimed.hasPhones, isTrue);
    expect(untimed.hasTimedWords, isFalse);
    expect(untimed.karaokeSwitchEnabled, isFalse);
    expect(untimed.ipaSwitchEnabled, isTrue);
    expect(untimed.showEnrich, isTrue);

    final timedNoIpa = transcriptDisplayReadiness(
      lines: timedNoPhones,
      canTrustWordTimes: true,
    );
    expect(timedNoIpa.karaokeSwitchEnabled, isTrue);
    expect(timedNoIpa.ipaSwitchEnabled, isFalse);
    expect(timedNoIpa.showEnrich, isTrue);
  });

  test('unresolved trust keeps karaoke off while enrich stays owned', () {
    final r = transcriptDisplayReadiness(
      lines: timedNoPhones,
      canTrustWordTimes: true,
      trustResolved: false,
    );
    expect(r.canTrustWordTimes, isTrue);
    expect(r.showEnrich, isTrue);
    expect(r.karaokeSwitchEnabled, isFalse);
    expect(r.ipaSwitchEnabled, isFalse);
  });

  test(
    'nested words without phones → IPA off; karaoke only if timed+owned',
    () {
      final owned = transcriptDisplayReadiness(
        lines: timedNoPhones,
        canTrustWordTimes: true,
      );
      expect(owned.ipaSwitchEnabled, isFalse);
      expect(owned.karaokeSwitchEnabled, isTrue);
      expect(owned.showEnrich, isTrue);

      final youtube = transcriptDisplayReadiness(
        lines: timedNoPhones,
        canTrustWordTimes: false,
      );
      expect(youtube.karaokeSwitchEnabled, isFalse);
    },
  );
}
