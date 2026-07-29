import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/ai/pronounce_api.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_result.dart';

void main() {
  group('PronounceResult.fromJson', () {
    test('parses snake_case worker body', () {
      final result = PronounceResult.fromJson({
        'audio_url': 'https://worker.example/pronounce/files/abc.mp3',
        'cached': true,
        'locale': 'en-US',
        'voice': 'en-US-JennyNeural',
        'format': 'mp3',
        'text': 'hello',
        'provider': 'azure',
      });
      expect(result.audioUrl, 'https://worker.example/pronounce/files/abc.mp3');
      expect(result.cached, isTrue);
      expect(result.locale, 'en-US');
      expect(result.voice, 'en-US-JennyNeural');
      expect(result.format, 'mp3');
      expect(result.text, 'hello');
      expect(result.provider, 'azure');
    });

    test('accepts camelCase audioUrl fallback', () {
      final result = PronounceResult.fromJson({
        'audioUrl': 'https://example/a.mp3',
      });
      expect(result.audioUrl, 'https://example/a.mp3');
      expect(result.cached, isFalse);
    });
  });

  group('PronounceApi', () {
    test('POST /pronounce omits voice when not provided', () async {
      http.Request? captured;
      final client = ApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'audio_url': 'https://worker.example/pronounce/files/x.mp3',
              'cached': false,
              'locale': 'ja-JP',
              'voice': 'ja-JP-NanamiNeural',
              'format': 'mp3',
              'text': 'こんにちは',
              'provider': 'azure',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        getBaseUrl: () async => 'https://worker.example.com',
        getAccessToken: () async => 'tok',
      );

      final api = PronounceApi(client);
      final json = await api.pronounce(text: 'こんにちは', locale: 'ja-JP');
      // ApiClient converts response keys to camelCase.
      expect(json['audioUrl'], contains('/pronounce/files/'));
      expect(
        PronounceResult.fromJson(json).audioUrl,
        contains('/pronounce/files/'),
      );
      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/pronounce');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['text'], 'こんにちは');
      expect(body['locale'], 'ja-JP');
      expect(body.containsKey('voice'), isFalse);
    });
  });
}
