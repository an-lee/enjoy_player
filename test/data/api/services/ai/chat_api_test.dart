import 'dart:convert';

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/ai/chat_api.dart';
import 'package:enjoy_player/features/ai/domain/chat_message.dart';
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
  group('ChatApi.completions', () {
    test('POSTs to /chat/completions with mapped messages', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{"id":"r1"}', 200);
      });

      final api = ChatApi(_client(mock));
      await api.completions(
        messages: const [
          ChatMessage(role: 'system', content: 'You translate.'),
          ChatMessage(role: 'user', content: 'hi'),
        ],
        temperature: 0.7,
        maxTokens: 256,
        stream: false,
      );

      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/chat/completions');
      final body = _decode(captured!.body);
      expect(body['temperature'], 0.7);
      expect(body['max_tokens'], 256);
      expect(body['stream'], isFalse);
      expect(body['messages'], isA<List>());
      expect((body['messages'] as List).first['role'], 'system');
      expect((body['messages'] as List).first['content'], 'You translate.');
      expect((body['messages'] as List).last['role'], 'user');
      expect((body['messages'] as List).last['content'], 'hi');
    });

    test('omits optional fields when null', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      });

      await ChatApi(_client(mock)).completions(
        messages: const [ChatMessage(role: 'user', content: 'hi')],
        stream: true,
      );

      final body = _decode(captured!.body);
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('max_tokens'), isFalse);
      expect(body.containsKey('response_format'), isFalse);
      expect(body['stream'], isTrue);
    });

    test('forwards responseFormat when provided', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      });

      await ChatApi(_client(mock)).completions(
        messages: const [ChatMessage(role: 'user', content: 'hi')],
        responseFormat: const {'type': 'json_object'},
      );

      final body = _decode(captured!.body);
      expect(body['response_format'], {'type': 'json_object'});
    });
  });

  group('ChatMessage', () {
    test('exposes canonical role constants', () {
      expect(ChatMessage.roleSystem, 'system');
      expect(ChatMessage.roleUser, 'user');
      expect(ChatMessage.roleAssistant, 'assistant');
    });

    test('toJsonBody includes role and content', () {
      const m = ChatMessage(role: 'user', content: 'hi');
      expect(m.toJsonBody(), {'role': 'user', 'content': 'hi'});
    });
  });
}
