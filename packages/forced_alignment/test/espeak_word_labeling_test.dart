import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/synth/espeak_ng_synthesizer.dart';

import 'helpers/espeak_word_event_fixtures.dart';

/// Regression coverage for issue #621: IPA enrichment must not change the
/// source orthography. Word events are captured verbatim from eSpeak-NG
/// (en-US) for the reported cues plus edge-case sentences.
void main() {
  group('buildWords keeps the tokenizer orthography', () {
    for (final cue in capturedCues) {
      test(cue.text, () {
        final words = EspeakNgSynthesizer.buildWords(
          text: cue.text,
          duration: cue.durationSeconds,
          wordEvents: cueWordEvents(cue),
          phoneEvents: const [],
        );
        expect(words.map((w) => w.text), tokenizeWords(cue.text));
      });
    }
  });

  test('cue 1 restores both articles and Manhattan', () {
    final words = _build(cueArticles);
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
      text: cueNumeral.text,
      duration: cueNumeral.durationSeconds,
      wordEvents: cueWordEvents(cueNumeral),
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
    final words = _build(cueHyphens);
    // Both len=0 events (positions 73 and 107) previously fell back to
    // tokens[13] ('plain') and tokens[19] ('to').
    final table = words.firstWhere((w) => w.text == 'table');
    final legs = words.firstWhere((w) => w.text == 'legs');
    final three = words.firstWhere((w) => w.text == 'three');
    final four = words.firstWhere((w) => w.text == 'four');
    final inAfterLegs = words[words.indexOf(legs) + 1];
    expect(table.startTime, closeTo(3.293, 1e-9));
    expect(table.endTime, closeTo(three.startTime, 1e-9));
    expect(legs.startTime, greaterThan(four.startTime));
    expect(inAfterLegs.text, 'in');
    expect(legs.endTime, closeTo(inAfterLegs.startTime, 1e-9));
  });

  test('cue 3 splits white-haired across the single white event', () {
    final words = _build(cueHyphens);
    final white = words.firstWhere((w) => w.text == 'white');
    final haired = words.firstWhere((w) => w.text == 'haired');
    final man = words.firstWhere((w) => w.text == 'man');
    expect(haired.startTime, closeTo(white.endTime, 1e-9));
    expect(haired.endTime, closeTo(man.startTime, 1e-9));
    expect(haired.endTime, greaterThan(haired.startTime));
  });

  test('token spans tile from the first event to the duration', () {
    for (final cue in capturedCues) {
      final words = _build(cue);
      for (var i = 0; i < words.length; i++) {
        expect(words[i].startTime, lessThanOrEqualTo(words[i].endTime));
        if (i + 1 < words.length) {
          expect(words[i].endTime, closeTo(words[i + 1].startTime, 1e-9));
        } else {
          expect(words[i].endTime, closeTo(cue.durationSeconds, 1e-9));
        }
      }
    }
  });

  test('leading punctuation keeps its silence before the first word', () {
    final words = _build(cueQuoted);
    expect(words.first.text, 'Well');
    expect(words.first.startTime, closeTo(0.109, 1e-9));
    expect(words.first.endTime, closeTo(words[1].startTime, 1e-9));
  });

  test('every token of the emoji sentence is claimed in order', () {
    final words = _build(cueEmoji);
    final scored = words.last;
    expect(scored.text, 'scored');
    expect(scored.startTime, greaterThan(0));
    expect(scored.endTime, closeTo(cueEmoji.durationSeconds, 1e-9));
    final loudly = words.firstWhere((w) => w.text == 'loudly');
    final when = words.firstWhere((w) => w.text == 'when');
    expect(loudly.endTime, closeTo(when.startTime, 1e-9));
  });

  test('out-of-order event times stay monotone and throw-free', () {
    final words = EspeakNgSynthesizer.buildWords(
      text: 'hello world foo',
      duration: 1.0,
      wordEvents: const [
        EspeakWordEvent(textPosition: 10, length: 5, audioMs: 900),
        EspeakWordEvent(textPosition: 1, length: 5, audioMs: 100),
        EspeakWordEvent(textPosition: 7, length: 4, audioMs: 500),
      ],
      phoneEvents: const [
        EspeakPhoneEvent(phone: 'ə', audioMs: 500, textPosition: 1),
      ],
      requireWordEvents: true,
    );
    expect(words.map((w) => w.text), ['hello', 'world', 'foo']);
    for (var i = 0; i < words.length; i++) {
      expect(words[i].startTime, lessThanOrEqualTo(words[i].endTime));
      if (i + 1 < words.length) {
        expect(words[i].startTime, lessThanOrEqualTo(words[i + 1].startTime));
      }
    }
    // The 500 ms phone lands in the window it belongs to, not on a later
    // token, and no clamp throws on the inverted raw order.
    final withPhones = words.where((w) => w.phones.isNotEmpty).toList();
    expect(withPhones, hasLength(1));
    expect(withPhones.first.text, 'world');
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

  test('fallback path threads the injected phone events', () {
    final words = EspeakNgSynthesizer.buildWords(
      text: 'hello world',
      duration: 1.0,
      wordEvents: const [],
      phoneEvents: const [
        EspeakPhoneEvent(phone: 'h', audioMs: 10, textPosition: 1),
        EspeakPhoneEvent(phone: 'w', audioMs: 20, textPosition: 7),
      ],
      requireWordEvents: false,
    );
    expect(words[0].phones.single.phone, 'h');
    expect(words[1].phones.single.phone, 'w');
  });

  group('mapWordEventsToTokenSpans', () {
    test('resolves the documented collisions', () {
      final spans = tokenizeWordSpans(cueNumeral.text);
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

      final spans3 = tokenizeWordSpans(cueHyphens.text);
      final owners3 = mapWordEventsToTokenSpans(spans3, const [72, 106]);
      expect(spans3[owners3[0]].text, 'table');
      expect(spans3[owners3[1]].text, 'legs');
    });

    test('keeps one token across combining marks and curly apostrophes', () {
      // NFD resumé: 'resume' followed by a combining acute (U+0301).
      expect(tokenizeWords('resume\u0301'), ['resume\u0301']);
      expect(tokenizeWords("don't don’t ‘tis"), ["don't", 'don’t', '‘tis']);
    });
  });
}

List<ReferenceWord> _build(CapturedCue cue) {
  return EspeakNgSynthesizer.buildWords(
    text: cue.text,
    duration: cue.durationSeconds,
    wordEvents: cueWordEvents(cue),
    phoneEvents: const [],
  );
}
