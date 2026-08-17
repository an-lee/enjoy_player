import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/synth/espeak_synth_host.dart';

void main() {
  test(
    'eSpeak hello-world golden ±50 ms vs that run’s word events',
    () async {
      const text = 'hello world';
      final reference = await EspeakSynthHost.synthesize(
        text: text,
        language: 'en-US',
      );
      expect(reference.words, hasLength(2));
      final n = math.max(reference.pcm.length, kAlignmentSampleRate);
      final source = Float32List(n);
      source.setRange(0, reference.pcm.length, reference.pcm);
      final outcome = await align(
        sourcePcm16k: source,
        transcript: text,
        language: 'en-US',
      );
      final failureReason = switch (outcome) {
        AlignmentFailed(:final failure) => failure.toString(),
        _ => '$outcome',
      };
      expect(outcome, isA<AlignmentSuccess>(), reason: failureReason);
      final result = (outcome as AlignmentSuccess).result;
      expect(result.wordTimeline, hasLength(2));
      expect(result.wordTimeline.map((w) => w.text), ['hello', 'world']);
      for (var i = 0; i < result.wordTimeline.length; i++) {
        expect(
          result.wordTimeline[i].startTime,
          closeTo(reference.words[i].startTime, 0.050),
        );
      }
      final flat = flattenToWordPhoneTimings(result);
      expect(flat.phones, isNotEmpty);
      expect(
        flat.phones.every(
          (p) => p.wordIndex != null && p.wordIndex! < flat.words.length,
        ),
        isTrue,
      );
      final helloPhones = flat.phones
          .where((p) => p.wordIndex == 0)
          .map((p) => p.phone)
          .toList();
      expect(helloPhones, isNot(equals(['h', 'e', 'l', 'l', 'o'])));
      expect(
        helloPhones.join(),
        isNot(contains('Ã')),
        reason: 'phonemes must be UTF-8 IPA, not Latin-1 mojibake',
      );
    },
    skip: espeakFfiIsAvailable()
        ? false
        : 'eSpeak-NG FFI not loaded on this runner',
  );

  test(
    'concurrent align jobs share one serial spoken-reference host',
    () async {
      const text = 'hello world';
      final reference = await EspeakSynthHost.synthesize(
        text: text,
        language: 'en-US',
      );
      final n = math.max(reference.pcm.length, kAlignmentSampleRate);
      final source = Float32List(n);
      source.setRange(0, reference.pcm.length, reference.pcm);
      final outcomes = await Future.wait([
        align(sourcePcm16k: source, transcript: text, language: 'en-US'),
        align(
          sourcePcm16k: Float32List.fromList(source),
          transcript: text,
          language: 'en-US',
        ),
      ]);
      for (final outcome in outcomes) {
        expect(outcome, isA<AlignmentSuccess>());
        expect((outcome as AlignmentSuccess).result.wordTimeline, hasLength(2));
      }
    },
    skip: espeakFfiIsAvailable()
        ? false
        : 'eSpeak-NG FFI not loaded on this runner',
  );
}
