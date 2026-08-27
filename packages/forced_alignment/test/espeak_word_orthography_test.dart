import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/synth/espeak_synth_host.dart';

/// Issue #621 regression: enrichment adds timings and IPA without changing
/// the source orthography. The synthesized reference must carry exactly the
/// tokenizer's words, in order, however eSpeak slices its own events.
void main() {
  const enUSCues = <String>[
    'One of the pictures hanging in my office in mid-Manhattan is a '
        'photograph of the writer E. B. White.',
    'It was taken by Jill Krementz when White was 77 years old, at his home '
        'in North Brooklin, Maine.',
    'A white-haired man is sitting on a plain wooden bench at a plain wooden '
        'table—three boards nailed to four legs—in a small boathouse.',
    'don’t stop the music.',
    'The crowd cheered 🎉 loudly when the team scored.',
    '“Well,” she said, “why not?” 1,234 people (about 5%) agreed.',
  ];

  for (var i = 0; i < enUSCues.length; i++) {
    test('en-US cue ${i + 1} keeps every source word in order', () async {
      final reference = await EspeakSynthHost.synthesize(
        text: enUSCues[i],
        language: 'en-US',
      );
      expect(reference.words.map((w) => w.text), tokenizeWords(enUSCues[i]));
      for (final word in reference.words) {
        expect(word.startTime, lessThanOrEqualTo(word.endTime));
      }
    });
  }

  test('fr-FR cue keeps every source word in order', () async {
    const text = "Le chat noir dort sur le canapé, n'est-ce pas ?";
    final reference = await EspeakSynthHost.synthesize(
      text: text,
      language: 'fr-FR',
    );
    expect(reference.words.map((w) => w.text), tokenizeWords(text));
  });

  test('cue 1 swallowed articles and Manhattan stay visible', () async {
    final reference = await EspeakSynthHost.synthesize(
      text: enUSCues[0],
      language: 'en-US',
    );
    expect(reference.words.where((w) => w.text == 'the'), hasLength(2));
    final manhattan = reference.words.firstWhere((w) => w.text == 'Manhattan');
    expect(manhattan.endTime, greaterThan(manhattan.startTime));
  });

  test(
    'cue 2 numeral 77 is one word carrying the full pronunciation',
    () async {
      final reference = await EspeakSynthHost.synthesize(
        text: enUSCues[1],
        language: 'en-US',
      );
      expect(reference.words.where((w) => w.text == '77'), hasLength(1));
      final seventySeven = reference.words.firstWhere((w) => w.text == '77');
      // "seventy seven" spans both eSpeak events, so the single token must own
      // phones from both slots (loose bound: voice data may re-segment).
      expect(seventySeven.phones.length, greaterThanOrEqualTo(2));
    },
  );

  test('cue 3 zero-length events land on table and legs', () async {
    final reference = await EspeakSynthHost.synthesize(
      text: enUSCues[2],
      language: 'en-US',
    );
    final table = reference.words.firstWhere((w) => w.text == 'table');
    final legs = reference.words.firstWhere((w) => w.text == 'legs');
    final three = reference.words.firstWhere((w) => w.text == 'three');
    final four = reference.words.firstWhere((w) => w.text == 'four');
    final legsIndex = reference.words.indexWhere((w) => w.text == 'legs');
    expect(legsIndex, isNot(-1));
    expect(legsIndex + 1, lessThan(reference.words.length));
    final inAfterLegs = reference.words[legsIndex + 1];
    expect(table.endTime, lessThanOrEqualTo(three.startTime + 1e-9));
    expect(legs.startTime, greaterThan(four.startTime));
    expect(inAfterLegs.text, 'in');
    expect(legs.endTime, lessThanOrEqualTo(inAfterLegs.startTime + 1e-9));
  });

  test('emoji cue claims every token including the last', () async {
    final reference = await EspeakSynthHost.synthesize(
      text: enUSCues[4],
      language: 'en-US',
    );
    final scored = reference.words.last;
    expect(scored.text, 'scored');
    expect(scored.startTime, greaterThan(0));
    final loudly = reference.words.firstWhere((w) => w.text == 'loudly');
    final when = reference.words.firstWhere((w) => w.text == 'when');
    expect(loudly.endTime, lessThanOrEqualTo(when.startTime + 1e-9));
  });
}
