import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/synth/espeak_synth_host.dart';

/// Issue #621 regression: enrichment adds timings and IPA without changing
/// the source orthography. The synthesized reference must carry exactly the
/// tokenizer's words, in order, however eSpeak slices its own events.
void main() {
  const cues = <String>[
    'One of the pictures hanging in my office in mid-Manhattan is a '
        'photograph of the writer E. B. White.',
    'It was taken by Jill Krementz when White was 77 years old, at his home '
        'in North Brooklin, Maine.',
    'A white-haired man is sitting on a plain wooden bench at a plain wooden '
        'table—three boards nailed to four legs—in a small boathouse.',
  ];

  for (var i = 0; i < cues.length; i++) {
    test('cue ${i + 1} keeps every source word in order', () async {
      final reference = await EspeakSynthHost.synthesize(
        text: cues[i],
        language: 'en-US',
      );
      expect(reference.words.map((w) => w.text), tokenizeWords(cues[i]));
      for (final word in reference.words) {
        expect(word.startTime, lessThanOrEqualTo(word.endTime));
      }
    });
  }

  test('cue 1 swallowed articles and Manhattan stay visible', () async {
    final reference = await EspeakSynthHost.synthesize(
      text: cues[0],
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
        text: cues[1],
        language: 'en-US',
      );
      expect(reference.words.where((w) => w.text == '77'), hasLength(1));
      final seventySeven = reference.words.firstWhere((w) => w.text == '77');
      // "seventy seven" spans both eSpeak events, so it must own phones from
      // both slots.
      expect(seventySeven.phones.length, greaterThanOrEqualTo(10));
    },
  );

  test('cue 3 zero-length events land on table and legs', () async {
    final reference = await EspeakSynthHost.synthesize(
      text: cues[2],
      language: 'en-US',
    );
    final table = reference.words.firstWhere((w) => w.text == 'table');
    final legs = reference.words.firstWhere((w) => w.text == 'legs');
    final three = reference.words.firstWhere((w) => w.text == 'three');
    final inAfterLegs = reference
        .words[reference.words.indexWhere((w) => w.text == 'legs') + 1];
    expect(table.endTime, lessThanOrEqualTo(three.startTime + 1e-9));
    expect(legs.startTime, greaterThan(4.0));
    expect(inAfterLegs.text, 'in');
    expect(legs.endTime, lessThanOrEqualTo(inAfterLegs.startTime + 1e-9));
  });
}
