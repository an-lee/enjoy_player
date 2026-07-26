import 'dart:convert';

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/ai/translation_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _client(MockClient mock) => ApiClient(
  httpClient: mock,
  getBaseUrl: () async => 'https://worker.example.com',
  getAccessToken: () async => 'tok',
);

Map<String, dynamic> _decode(String body) =>
    Map<String, dynamic>.from(jsonDecode(body) as Map);

void main() {
  group('TranslationApi.translate', () {
    test('POSTs to /translations with all arguments', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{"text":"konnichiwa"}', 200);
      });

      final api = TranslationApi(_client(mock));
      await api.translate(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'ja',
        forceRefresh: true,
      );

      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/translations');
      final body = _decode(captured!.body);
      expect(body['text'], 'hello');
      expect(body['source_lang'], 'en');
      expect(body['target_lang'], 'ja');
      expect(body['force_refresh'], isTrue);
    });

    test('omits forceRefresh when null', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      });

      await TranslationApi(
        _client(mock),
      ).translate(text: 'hello', sourceLanguage: 'en', targetLanguage: 'ja');

      final body = _decode(captured!.body);
      expect(body.containsKey('force_refresh'), isFalse);
    });

    test('explicit forceRefresh false is sent on the wire', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      });

      await TranslationApi(_client(mock)).translate(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'ja',
        forceRefresh: false,
      );

      final body = _decode(captured!.body);
      // ?bool null-shorthand drops only null, not explicit false.
      expect(body['force_refresh'], isFalse);
    });
  });
}
