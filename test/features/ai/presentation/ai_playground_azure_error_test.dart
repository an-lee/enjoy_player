// Coverage for:
//   * lib/features/ai/presentation/ai_playground_azure_error.dart
//   * lib/features/player/application/engines/youtube/youtube_page_inject.dart
//
// Both files are tiny re-export shims / pure helpers.
import 'package:azure_speech/azure_speech.dart';
import 'package:enjoy_player/features/ai/presentation/ai_playground_azure_error.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_page_inject.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isAzureSpeechException', () {
    test('returns true for an AzureSpeechException', () {
      final ex = AzureSpeechException(
        code: 'BadRequest',
        message: 'something went wrong',
      );
      expect(isAzureSpeechException(ex), isTrue);
    });

    test('returns false for a generic Exception', () {
      expect(isAzureSpeechException(Exception('nope')), isFalse);
    });

    test('returns false for a StateError', () {
      expect(isAzureSpeechException(StateError('boom')), isFalse);
    });

    test('returns false for a plain string (no runtime type check)', () {
      // The implementation checks `e is AzureSpeechException`; a bare string
      // cannot be an AzureSpeechException.
      expect(isAzureSpeechException('boom'), isFalse);
    });
  });

  group('formatAzureSpeechError', () {
    test(
      'formats an AzureSpeechException as "AzureSpeech <code>: <message>"',
      () {
        final ex = AzureSpeechException(
          code: 'Unauthorized',
          message: 'missing key',
        );
        expect(
          formatAzureSpeechError(ex),
          'AzureSpeech Unauthorized: missing key',
        );
      },
    );

    test('returns null for a non-Azure exception', () {
      expect(formatAzureSpeechError(Exception('nope')), isNull);
      expect(formatAzureSpeechError(StateError('boom')), isNull);
    });

    test('includes both code and message verbatim', () {
      final ex = AzureSpeechException(code: '429', message: 'rate limited');
      final formatted = formatAzureSpeechError(ex);
      expect(formatted, contains('429'));
      expect(formatted, contains('rate limited'));
    });

    test('omits details section (only code: message is formatted)', () {
      final ex = AzureSpeechException(
        code: 'BadRequest',
        message: 'invalid input',
        details: {'field': 'audio'},
      );
      final formatted = formatAzureSpeechError(ex)!;
      // Sanity: the formatted string should not embed a '{field: audio}'
      // substring — the contract is "code: message" only.
      expect(formatted, isNot(contains('field')));
    });
  });

  group('kYoutubeMobileWatchInjectScript', () {
    test('is a non-empty multi-line JavaScript string', () {
      expect(kYoutubeMobileWatchInjectScript, isNotEmpty);
      expect(kYoutubeMobileWatchInjectScript, contains('function'));
      // The guard for repeat-injection is part of the contract — pin it.
      expect(kYoutubeMobileWatchInjectScript, contains('__enjoyYtMwc'));
    });
  });
}
