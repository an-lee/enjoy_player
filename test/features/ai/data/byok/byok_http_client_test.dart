import 'dart:convert';

import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/features/ai/data/byok/byok_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guardByokBaseUrl', () {
    test('builds a Uri from a valid base URL and joins a path', () {
      final uri = guardByokBaseUrl(
        baseUrl: 'https://api.openai.com/v1/',
        path: 'audio/speech',
        purpose: 'OpenAI speech synthesis',
      );
      expect(uri.toString(), 'https://api.openai.com/v1/audio/speech');
    });

    test('drops the leading slash on the joined path', () {
      final uri = guardByokBaseUrl(
        baseUrl: 'https://api.openai.com/v1',
        path: '/models',
        purpose: 'model fetch',
      );
      expect(uri.toString(), 'https://api.openai.com/v1/models');
    });

    test('returns the base Uri when path is empty', () {
      final uri = guardByokBaseUrl(
        baseUrl: 'https://api.openai.com/v1',
        path: '',
        purpose: 'model fetch',
      );
      expect(uri.toString(), 'https://api.openai.com/v1');
    });

    test('throws ApiException(400) when the base URL is rejected', () {
      expect(
        () => guardByokBaseUrl(
          baseUrl: 'http://api.openai.com/v1',
          path: 'audio/speech',
          purpose: 'OpenAI speech synthesis',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.message,
                'message',
                contains('OpenAI speech synthesis'),
              ),
        ),
      );
    });
  });

  group('byokBearerHeaders', () {
    test('trims the apiKey and defaults Accept to application/json', () {
      expect(byokBearerHeaders(apiKey: '  sk-test  '), {
        'Authorization': 'Bearer sk-test',
        'Accept': 'application/json',
      });
    });

    test('honors a custom Accept value', () {
      expect(byokBearerHeaders(apiKey: 'sk-test', accept: 'audio/mpeg'), {
        'Authorization': 'Bearer sk-test',
        'Accept': 'audio/mpeg',
      });
    });
  });

  group('decodeByokErrorBody', () {
    test('decodes a JSON object payload', () {
      final decoded = decodeByokErrorBody('{"error":"bad"}');
      expect(decoded, {'error': 'bad'});
    });

    test('falls back to the raw string for non-JSON payloads', () {
      expect(decodeByokErrorBody('plain text error'), 'plain text error');
    });
  });

  group('throwByokHttpError', () {
    test('builds an ApiException with the decoded JSON body', () {
      expect(
        () => throwByokHttpError(
          purpose: 'Whisper transcription',
          statusCode: 502,
          body: jsonEncode({'error': 'oops'}),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having(
                (e) => e.message,
                'message',
                'Whisper transcription failed (502)',
              )
              .having((e) => e.body, 'body', {'error': 'oops'}),
        ),
      );
    });

    test('falls back to the raw string when the body is not JSON', () {
      expect(
        () => throwByokHttpError(
          purpose: 'Speech synthesis',
          statusCode: 500,
          body: 'gateway exploded',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having(
                (e) => e.message,
                'message',
                'Speech synthesis failed (500)',
              )
              .having((e) => e.body, 'body', 'gateway exploded'),
        ),
      );
    });

    test('flags the exception as originating from a BYOK provider', () {
      expect(
        () => throwByokHttpError(
          purpose: 'Translation',
          statusCode: 402,
          body: jsonEncode({'error': 'insufficient_quota'}),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 402)
              .having((e) => e.byokProvider, 'byokProvider', isTrue),
        ),
      );
    });
  });
}
