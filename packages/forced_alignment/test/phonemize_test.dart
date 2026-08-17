import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

ReferenceAudio _fakeHello() {
  return ReferenceAudio(
    pcm: Float32List(0),
    durationSeconds: 0.4,
    words: const [
      ReferenceWord(
        text: 'Hello',
        startTime: 0,
        endTime: 0.4,
        phones: [
          ReferencePhone(phone: 'h', startTime: 0, endTime: 0.1, wordIndex: 0),
          ReferencePhone(
            phone: 'ə',
            startTime: 0.1,
            endTime: 0.4,
            wordIndex: 0,
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('unsupported language fails closed without synthesizing', () async {
    var called = false;
    final outcome = await phonemizeLines(
      texts: const ['Hello'],
      language: 'xx-XX',
      synthesize: ({required text, required language, cancel}) async {
        called = true;
        return _fakeHello();
      },
    );
    expect(outcome, isA<PhonemizeFailed>());
    expect(
      (outcome as PhonemizeFailed).failure.reason,
      AlignmentFailureReason.unsupportedLanguage,
    );
    expect(called, isFalse);
  });

  test('cancel between lines fails closed', () async {
    final cancel = AlignmentCancelToken()..cancel();
    final outcome = await phonemizeLines(
      texts: const ['Hello'],
      language: 'en-US',
      cancel: cancel,
      synthesize: ({required text, required language, cancel}) async {
        fail('should not synthesize after cancel');
      },
    );
    expect(outcome, isA<PhonemizeFailed>());
    expect(
      (outcome as PhonemizeFailed).failure.reason,
      AlignmentFailureReason.cancelled,
    );
  });

  test(
    'injected synth returns token + IPA labels without source-audio times',
    () async {
      final outcome = await phonemizeLines(
        texts: const ['Hello'],
        language: 'en-US',
        synthesize: ({required text, required language, cancel}) async =>
            _fakeHello(),
      );
      expect(outcome, isA<PhonemizeSuccess>());
      final lines = (outcome as PhonemizeSuccess).lines;
      expect(lines, hasLength(1));
      expect(lines.single.words, hasLength(1));
      expect(lines.single.words.single.text, 'Hello');
      expect(lines.single.words.single.phones, ['h', 'ə']);
    },
  );

  test('native phonemize returns labels when eSpeak is available', () async {
    final outcome = await phonemizeLines(
      texts: const ['Hello'],
      language: 'en-US',
    );
    expect(outcome, isA<PhonemizeSuccess>());
    final words = (outcome as PhonemizeSuccess).lines.single.words;
    expect(words, isNotEmpty);
    expect(words.first.phones, isNotEmpty);
  });
}
