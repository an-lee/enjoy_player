import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/synth/espeak_ng_synthesizer.dart';

/// Regression coverage for issue #621: IPA enrichment must not change the
/// source orthography. Word events below are captured verbatim from
/// eSpeak-NG (en-US) for the cues reported in the issue.
void main() {
  const cue1 =
      'One of the pictures hanging in my office in mid-Manhattan is a '
      'photograph of the writer E. B. White.';
  const cue1Events = [
    (1, 3, 0),
    (5, 2, 165),
    (12, 8, 420),
    (21, 7, 929),
    (29, 2, 1236),
    (32, 2, 1411),
    (35, 6, 1512),
    (42, 2, 1861),
    (45, 3, 1980),
    (59, 2, 2703),
    (62, 1, 2819),
    (64, 10, 2874),
    (75, 2, 3431),
    (82, 6, 3660),
    (89, 1, 3951),
    (92, 1, 4128),
    (95, 5, 4357),
  ];
  const cue2 =
      'It was taken by Jill Krementz when White was 77 years old, at his '
      'home in North Brooklin, Maine.';
  const cue2Events = [
    (1, 2, 0),
    (4, 3, 146),
    (8, 5, 345),
    (14, 2, 768),
    (17, 4, 905),
    (22, 8, 1166),
    (31, 4, 1713),
    (36, 5, 1887),
    (42, 3, 2160),
    (46, 2, 2368),
    (47, 2, 2848),
    (49, 5, 3215),
    (55, 3, 3517),
    (60, 2, 4056),
    (63, 3, 4213),
    (67, 4, 4421),
    (72, 2, 4626),
    (75, 5, 4780),
    (81, 8, 5079),
    (91, 5, 5695),
  ];
  const cue3 =
      'A white-haired man is sitting on a plain wooden bench at a plain '
      'wooden table—three boards nailed to four legs—in a small boathouse.';
  const cue3Events = [
    (1, 1, 0),
    (3, 5, 62),
    (16, 3, 636),
    (20, 2, 807),
    (23, 7, 989),
    (31, 2, 1268),
    (34, 1, 1433),
    (36, 5, 1523),
    (42, 6, 1857),
    (49, 5, 2171),
    (55, 2, 2502),
    (60, 5, 2651),
    (66, 6, 2985),
    (73, 0, 3293),
    (79, 5, 3791),
    (85, 6, 4030),
    (92, 6, 4454),
    (99, 2, 4807),
    (102, 4, 4938),
    (107, 0, 5196),
    (112, 2, 5684),
    (115, 1, 5745),
    (117, 5, 5822),
    (123, 9, 6155),
  ];

  List<EspeakWordEvent> events(List<(int, int, int)> tuples) => [
    for (final (position, length, audioMs) in tuples)
      EspeakWordEvent(textPosition: position, length: length, audioMs: audioMs),
  ];

  group('buildWords keeps the tokenizer orthography', () {
    for (final (name, text, tuples, duration) in [
      ('cue 1 articles', cue1, cue1Events, 5.0),
      ('cue 2 numeral', cue2, cue2Events, 6.5),
      ('cue 3 hyphens and dashes', cue3, cue3Events, 7.0),
    ]) {
      test(name, () {
        final words = EspeakNgSynthesizer.buildWords(
          text: text,
          duration: duration,
          wordEvents: events(tuples),
          phoneEvents: const [],
        );
        expect(words.map((w) => w.text), tokenizeWords(text));
      });
    }
  });

  test('cue 1 restores both articles and Manhattan', () {
    final words = EspeakNgSynthesizer.buildWords(
      text: cue1,
      duration: 5.0,
      wordEvents: events(cue1Events),
      phoneEvents: const [],
    );
    expect(words.where((w) => w.text == 'the'), hasLength(2));
    final mid = words.firstWhere((w) => w.text == 'mid');
    final manhattan = words.firstWhere((w) => w.text == 'Manhattan');
    final is_ = words.firstWhere((w) => w.text == 'is');
    expect(manhattan.startTime, closeTo(mid.endTime, 1e-9));
    expect(manhattan.endTime, closeTo(is_.startTime, 1e-9));
    expect(manhattan.endTime, greaterThan(manhattan.startTime));
  });

  test('cue 2 keeps 77 as one display item with merged phones', () {
    // eSpeak expands 77 -> "seventy seven" and emits two word events; the
    // phones of both slots must land on the single displayed token.
    final phones = <EspeakPhoneEvent>[
      for (var ms = 2380; ms < 3200; ms += 100)
        EspeakPhoneEvent(phone: 's', audioMs: ms, textPosition: 46),
    ];
    final words = EspeakNgSynthesizer.buildWords(
      text: cue2,
      duration: 6.5,
      wordEvents: events(cue2Events),
      phoneEvents: phones,
    );
    expect(words.where((w) => w.text == '77'), hasLength(1));
    final index = words.indexWhere((w) => w.text == '77');
    final seventySeven = words[index];
    final years = words.firstWhere((w) => w.text == 'years');
    expect(seventySeven.startTime, closeTo(2.368, 1e-9));
    expect(seventySeven.endTime, closeTo(years.startTime, 1e-9));
    expect(seventySeven.phones, hasLength(phones.length));
    for (final phone in seventySeven.phones) {
      expect(phone.wordIndex, index);
      expect(phone.startTime, greaterThanOrEqualTo(seventySeven.startTime));
      expect(phone.endTime, lessThanOrEqualTo(seventySeven.endTime));
    }
  });

  test('cue 3 relabels zero-length events to their own tokens', () {
    final words = EspeakNgSynthesizer.buildWords(
      text: cue3,
      duration: 7.0,
      wordEvents: events(cue3Events),
      phoneEvents: const [],
    );
    // Both len=0 events (positions 73 and 107) previously fell back to
    // tokens[13] ('plain') and tokens[19] ('to').
    final table = words.firstWhere((w) => w.text == 'table');
    final legs = words.firstWhere((w) => w.text == 'legs');
    final three = words.firstWhere((w) => w.text == 'three');
    final four = words.firstWhere((w) => w.text == 'four');
    final inAfterLegs = words[words.indexOf(legs) + 1];
    expect(table.startTime, closeTo(3.293, 1e-9));
    expect(table.endTime, closeTo(three.startTime, 1e-9));
    expect(legs.startTime, closeTo(5.196, 1e-9));
    expect(legs.startTime, greaterThan(four.startTime));
    expect(inAfterLegs.text, 'in');
    expect(legs.endTime, closeTo(inAfterLegs.startTime, 1e-9));
  });

  test('cue 3 splits white-haired across the single white event', () {
    final words = EspeakNgSynthesizer.buildWords(
      text: cue3,
      duration: 7.0,
      wordEvents: events(cue3Events),
      phoneEvents: const [],
    );
    final white = words.firstWhere((w) => w.text == 'white');
    final haired = words.firstWhere((w) => w.text == 'haired');
    final man = words.firstWhere((w) => w.text == 'man');
    expect(haired.startTime, closeTo(white.endTime, 1e-9));
    expect(haired.endTime, closeTo(man.startTime, 1e-9));
    expect(haired.endTime, greaterThan(haired.startTime));
  });

  test('token spans tile the reference audio for every cue', () {
    for (final (text, tuples, duration) in [
      (cue1, cue1Events, 5.0),
      (cue2, cue2Events, 6.5),
      (cue3, cue3Events, 7.0),
    ]) {
      final words = EspeakNgSynthesizer.buildWords(
        text: text,
        duration: duration,
        wordEvents: events(tuples),
        phoneEvents: const [],
      );
      expect(words.first.startTime, 0);
      for (var i = 0; i < words.length; i++) {
        expect(words[i].startTime, lessThanOrEqualTo(words[i].endTime));
        if (i + 1 < words.length) {
          expect(words[i].endTime, closeTo(words[i + 1].startTime, 1e-9));
        } else {
          expect(words[i].endTime, closeTo(duration, 1e-9));
        }
      }
    }
  });

  test('mapWordEventsToTokenSpans resolves the documented collisions', () {
    final spans = tokenizeWordSpans(cue2);
    final owners = mapWordEventsToTokenSpans(spans, const [
      0,
      3,
      7,
      13,
      16,
      21,
      30,
      35,
      41,
      45,
      46,
      48,
      54,
      59,
      62,
      66,
      71,
      74,
      80,
      90,
    ]);
    // Both numeral expansion events (zero-based positions 45 and 46) own
    // the token '77'.
    final token77 = spans.indexWhere((s) => s.text == '77');
    expect(owners[9], token77);
    expect(owners[10], token77);
    expect(owners, everyElement(lessThan(spans.length)));

    final spans3 = tokenizeWordSpans(cue3);
    final owners3 = mapWordEventsToTokenSpans(spans3, const [72, 106]);
    expect(spans3[owners3[0]].text, 'table');
    expect(spans3[owners3[1]].text, 'legs');
  });

  test('no word events falls back to token spans', () {
    final words = EspeakNgSynthesizer.buildWords(
      text: 'hello world',
      duration: 1.0,
      wordEvents: const [],
      phoneEvents: const [],
      requireWordEvents: false,
    );
    expect(words.map((w) => w.text), ['hello', 'world']);
    expect(
      () => EspeakNgSynthesizer.buildWords(
        text: 'hello world',
        duration: 1.0,
        wordEvents: const [],
        phoneEvents: const [],
      ),
      throwsA(isA<SpokenReferenceException>()),
    );
  });
}
