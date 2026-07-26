// Tests for `lib/features/ai/data/enjoy/enjoy_llm_capability.dart` — pure
// content-extraction logic for OpenAI-compatible `/chat/completions`
// responses. We fake the `ChatApi` boundary and exercise every `_contentFromResponse`
// branch.
import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/data/api/services/ai/chat_api.dart';
import 'package:enjoy_player/features/ai/data/enjoy/enjoy_llm_capability.dart';
import 'package:enjoy_player/features/ai/domain/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _NullHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnsupportedError('unused');
}

class _NullApiClient extends ApiClient {
  _NullApiClient()
    : super(
        httpClient: _NullHttpClient(),
        getBaseUrl: () async => 'https://test.invalid',
        getAccessToken: () async => null,
      );
}

class _FakeChatApi extends ChatApi {
  _FakeChatApi(this._response) : super(_NullApiClient());

  final JsonMap _response;

  @override
  Future<JsonMap> completions({
    required List<ChatMessage> messages,
    double? temperature,
    int? maxTokens,
    bool stream = false,
    JsonMap? responseFormat,
  }) async => _response;
}

void main() {
  group('EnjoyLlmCapability.generateChatCompletion', () {
    test(
      'returns trimmed content from a healthy OpenAI-shaped response',
      () async {
        final api = _FakeChatApi({
          'choices': [
            {
              'message': {'content': '  hello world  '},
            },
          ],
        });
        final cap = EnjoyLlmCapability(api);

        final text = await cap.generateChatCompletion(
          messages: const [
            ChatMessage(role: ChatMessage.roleUser, content: 'say hi'),
          ],
        );
        expect(text, 'hello world');
      },
    );

    test('throws ApiException when choices list is missing', () async {
      final cap = EnjoyLlmCapability(_FakeChatApi(<String, dynamic>{}));
      await expectLater(
        () => cap.generateChatCompletion(
          messages: const [
            ChatMessage(role: ChatMessage.roleUser, content: 'hi'),
          ],
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having((e) => e.message, 'message', contains('No choices')),
        ),
      );
    });

    test('throws ApiException when choices list is empty', () async {
      final cap = EnjoyLlmCapability(_FakeChatApi({'choices': <dynamic>[]}));
      await expectLater(
        () => cap.generateChatCompletion(
          messages: const [
            ChatMessage(role: ChatMessage.roleUser, content: 'hi'),
          ],
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('No choices'),
          ),
        ),
      );
    });

    test('throws ApiException when first choice is not an object', () async {
      final cap = EnjoyLlmCapability(
        _FakeChatApi({
          'choices': ['raw'],
        }),
      );
      await expectLater(
        () => cap.generateChatCompletion(
          messages: const [
            ChatMessage(role: ChatMessage.roleUser, content: 'hi'),
          ],
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('throws ApiException when choice has no message', () async {
      final cap = EnjoyLlmCapability(
        _FakeChatApi({
          'choices': [<String, dynamic>{}],
        }),
      );
      await expectLater(
        () => cap.generateChatCompletion(
          messages: const [
            ChatMessage(role: ChatMessage.roleUser, content: 'hi'),
          ],
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('No message'),
          ),
        ),
      );
    });

    test('throws ApiException when message content is empty string', () async {
      final cap = EnjoyLlmCapability(
        _FakeChatApi({
          'choices': [
            {
              'message': {'content': '   '},
            },
          ],
        }),
      );
      await expectLater(
        () => cap.generateChatCompletion(
          messages: const [
            ChatMessage(role: ChatMessage.roleUser, content: 'hi'),
          ],
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Empty completion'),
          ),
        ),
      );
    });

    test('throws ApiException when message content is null', () async {
      final cap = EnjoyLlmCapability(
        _FakeChatApi({
          'choices': [
            {'message': <String, dynamic>{}},
          ],
        }),
      );
      await expectLater(
        () => cap.generateChatCompletion(
          messages: const [
            ChatMessage(role: ChatMessage.roleUser, content: 'hi'),
          ],
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Empty completion'),
          ),
        ),
      );
    });

    test(
      'throws ApiException when message content is a non-string type',
      () async {
        final cap = EnjoyLlmCapability(
          _FakeChatApi({
            'choices': [
              {
                'message': {'content': 42},
              },
            ],
          }),
        );
        await expectLater(
          () => cap.generateChatCompletion(
            messages: const [
              ChatMessage(role: ChatMessage.roleUser, content: 'hi'),
            ],
          ),
          throwsA(isA<ApiException>()),
        );
      },
    );
  });

  group('EnjoyLlmCapability.generateText', () {
    test(
      'prepends a system prompt when one is provided and non-empty',
      () async {
        final messagesSeen = <List<ChatMessage>>[];
        final api = _RecordingChatApi(messagesSeen, _okResponse());
        final cap = EnjoyLlmCapability(api);

        await cap.generateText(systemPrompt: 'be polite', userPrompt: 'hi');

        final sent = messagesSeen.single;
        expect(sent, hasLength(2));
        expect(sent.first.role, ChatMessage.roleSystem);
        expect(sent.first.content, 'be polite');
        expect(sent.last.role, ChatMessage.roleUser);
        expect(sent.last.content, 'hi');
      },
    );

    test('omits the system prompt when it is null or empty', () async {
      final messagesSeen = <List<ChatMessage>>[];
      final api = _RecordingChatApi(messagesSeen, _okResponse());
      final cap = EnjoyLlmCapability(api);

      await cap.generateText(userPrompt: 'hi');
      await cap.generateText(systemPrompt: '', userPrompt: 'hi');

      expect(messagesSeen[0], hasLength(1));
      expect(messagesSeen[1], hasLength(1));
    });

    test(
      'uses default temperature 0.7 and maxTokens 2048 when unset',
      () async {
        final temps = <double?>[];
        final tokens = <int?>[];
        final api = _RecordingChatApi(
          <List<ChatMessage>>[],
          _okResponse(),
          onTemp: temps.add,
          onTokens: tokens.add,
        );
        final cap = EnjoyLlmCapability(api);

        await cap.generateText(userPrompt: 'hi');
        expect(temps.single, 0.7);
        expect(tokens.single, 2048);
      },
    );

    test('explicit temperature and maxTokens override defaults', () async {
      final temps = <double?>[];
      final tokens = <int?>[];
      final api = _RecordingChatApi(
        <List<ChatMessage>>[],
        _okResponse(),
        onTemp: temps.add,
        onTokens: tokens.add,
      );
      final cap = EnjoyLlmCapability(api);

      await cap.generateText(userPrompt: 'hi', temperature: 0.1, maxTokens: 8);
      expect(temps.single, 0.1);
      expect(tokens.single, 8);
    });
  });

  group('ChatApi factory for tests', () {
    test('null client can be instantiated for capability wiring', () {
      final api = ChatApi(_NullApiClient());
      expect(api.client, isA<ApiClient>());
    });
  });
}

class _RecordingChatApi extends ChatApi {
  _RecordingChatApi(
    this.messagesSeen,
    this.response, {
    this.onTemp,
    this.onTokens,
  }) : super(_NullApiClient());

  final List<List<ChatMessage>> messagesSeen;
  final JsonMap response;
  final void Function(double?)? onTemp;
  final void Function(int?)? onTokens;

  @override
  Future<JsonMap> completions({
    required List<ChatMessage> messages,
    double? temperature,
    int? maxTokens,
    bool stream = false,
    JsonMap? responseFormat,
  }) async {
    messagesSeen.add(messages);
    onTemp?.call(temperature);
    onTokens?.call(maxTokens);
    return response;
  }
}

JsonMap _okResponse() => {
  'choices': [
    {
      'message': {'content': 'ok'},
    },
  ],
};
