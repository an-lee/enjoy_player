import 'package:enjoy_player/features/ai/domain/modality_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModalityKind', () {
    test('toJsonKey returns the enum name', () {
      expect(ModalityKind.llm.toJsonKey(), 'llm');
      expect(ModalityKind.asr.toJsonKey(), 'asr');
      expect(ModalityKind.tts.toJsonKey(), 'tts');
      expect(ModalityKind.assessment.toJsonKey(), 'assessment');
    });

    test('fromJsonKey maps known names to enum values', () {
      expect(ModalityKindJson.fromJsonKey('llm'), ModalityKind.llm);
      expect(ModalityKindJson.fromJsonKey('asr'), ModalityKind.asr);
      expect(ModalityKindJson.fromJsonKey('tts'), ModalityKind.tts);
      expect(
        ModalityKindJson.fromJsonKey('assessment'),
        ModalityKind.assessment,
      );
    });

    test('fromJsonKey returns null for unknown values', () {
      expect(ModalityKindJson.fromJsonKey('unknown'), isNull);
      expect(ModalityKindJson.fromJsonKey(''), isNull);
      expect(ModalityKindJson.fromJsonKey(null), isNull);
      expect(ModalityKindJson.fromJsonKey('LLM'), isNull);
    });

    test('round-trips through toJsonKey + fromJsonKey', () {
      for (final k in ModalityKind.values) {
        expect(ModalityKindJson.fromJsonKey(k.toJsonKey()), k);
      }
    });
  });
}
