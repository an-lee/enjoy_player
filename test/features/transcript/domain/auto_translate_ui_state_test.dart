import 'package:enjoy_player/features/transcript/domain/auto_translate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutoTranslateUiState equality', () {
    test('equal instances with same values', () {
      const a = AutoTranslateUiState(
        status: AutoTranslateStatus.active,
        aiTranscriptId: 'ai-1',
        primaryTranscriptId: 'prim-1',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        inFlightIndexes: {1, 2},
        failedLineIndexes: {5},
      );
      const b = AutoTranslateUiState(
        status: AutoTranslateStatus.active,
        aiTranscriptId: 'ai-1',
        primaryTranscriptId: 'prim-1',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        inFlightIndexes: {1, 2},
        failedLineIndexes: {5},
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when status differs', () {
      const a = AutoTranslateUiState(status: AutoTranslateStatus.active);
      const b = AutoTranslateUiState(status: AutoTranslateStatus.idle);
      expect(a, isNot(equals(b)));
    });

    test('not equal when blockReason differs', () {
      const a = AutoTranslateUiState(
        status: AutoTranslateStatus.blocked,
        blockReason: AutoTranslateBlockReason.credits,
      );
      const b = AutoTranslateUiState(
        status: AutoTranslateStatus.blocked,
        blockReason: AutoTranslateBlockReason.auth,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equal when inFlightIndexes differs', () {
      const a = AutoTranslateUiState(inFlightIndexes: {1, 2});
      const b = AutoTranslateUiState(inFlightIndexes: {1, 3});
      expect(a, isNot(equals(b)));
    });

    test('not equal when failedLineIndexes differs', () {
      const a = AutoTranslateUiState(failedLineIndexes: {10});
      const b = AutoTranslateUiState(failedLineIndexes: {20});
      expect(a, isNot(equals(b)));
    });

    test('identical instance is equal', () {
      const a = AutoTranslateUiState();
      expect(a == a, isTrue);
    });

    test('not equal to different type', () {
      const a = AutoTranslateUiState();
      // ignore: unrelated_type_equality_checks
      expect(a == 'other', isFalse);
    });

    test('hashCode is consistent', () {
      const a = AutoTranslateUiState(
        status: AutoTranslateStatus.active,
        sourceLanguage: 'en',
        targetLanguage: 'ja',
      );
      expect(a.hashCode, equals(a.hashCode));
    });
  });
}
