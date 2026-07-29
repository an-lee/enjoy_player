import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/ai/ai_api_providers.dart';
import 'package:enjoy_player/data/api/services/ai/pronounce_api.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_audio_engine.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';

PronounceApi _stubApi({
  required String audioUrl,
  Duration delay = Duration.zero,
  int? statusCode,
}) {
  final client = ApiClient(
    httpClient: MockClient((request) async {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (statusCode != null && statusCode != 200) {
        return http.Response('{"error":"fail"}', statusCode);
      }
      return http.Response(
        '{"audio_url":"$audioUrl","cached":false,"locale":"en-US",'
        '"voice":"en-US-JennyNeural","format":"mp3","text":"hello",'
        '"provider":"azure"}',
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
    getBaseUrl: () async => 'https://worker.example.com',
    getAccessToken: () async => 'tok',
  );
  return PronounceApi(client);
}

void main() {
  late FakePronounceAudioEngine engine;
  late ProviderContainer container;

  setUp(() {
    engine = FakePronounceAudioEngine();
    PronouncePlaybackController.debugEngineFactory = () => engine;
  });

  tearDown(() {
    PronouncePlaybackController.debugEngineFactory = null;
    container.dispose();
  });

  ProviderContainer makeContainer({PronounceApi? api}) {
    return ProviderContainer(
      overrides: [
        pronounceApiProvider.overrideWithValue(
          api ?? _stubApi(audioUrl: 'https://worker.example/a.mp3'),
        ),
      ],
    );
  }

  PronounceTarget target([String text = 'hello']) => PronounceTarget.tryCreate(
    text: text,
    localeTag: 'en-US',
    surfaceId: PronounceSurfaceId.lookup,
  )!;

  test('play → loading → playing; stop returns idle', () async {
    container = makeContainer(
      api: _stubApi(
        audioUrl: 'https://worker.example/a.mp3',
        delay: const Duration(milliseconds: 40),
      ),
    );
    final ctrl = container.read(pronouncePlaybackControllerProvider.notifier);

    final playFuture = ctrl.play(target());
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(
      container.read(pronouncePlaybackControllerProvider).isLoading,
      isTrue,
    );
    await playFuture;
    expect(
      container.read(pronouncePlaybackControllerProvider).isPlaying,
      isTrue,
    );
    expect(engine.playedUrls, ['https://worker.example/a.mp3']);

    await ctrl.stop();
    expect(container.read(pronouncePlaybackControllerProvider).isIdle, isTrue);
    expect(engine.stopCount, greaterThan(0));
  });

  test('second play of same target stops', () async {
    container = makeContainer();
    final ctrl = container.read(pronouncePlaybackControllerProvider.notifier);
    final t = target();
    await ctrl.play(t);
    expect(
      container.read(pronouncePlaybackControllerProvider).isPlaying,
      isTrue,
    );

    await ctrl.play(t);
    expect(container.read(pronouncePlaybackControllerProvider).isIdle, isTrue);
  });

  test('stale generation is ignored when stop races fetch', () async {
    container = makeContainer(
      api: _stubApi(
        audioUrl: 'https://worker.example/slow.mp3',
        delay: const Duration(milliseconds: 80),
      ),
    );
    final ctrl = container.read(pronouncePlaybackControllerProvider.notifier);

    final playFuture = ctrl.play(target());
    await ctrl.stop();
    await playFuture;

    expect(container.read(pronouncePlaybackControllerProvider).isIdle, isTrue);
    expect(engine.playedUrls, isEmpty);
  });

  test(
    'caches URL so second distinct session reuses without second POST',
    () async {
      var posts = 0;
      final client = ApiClient(
        httpClient: MockClient((request) async {
          posts++;
          return http.Response(
            '{"audio_url":"https://worker.example/cached.mp3","cached":true,'
            '"locale":"en-US","voice":"v","format":"mp3","text":"hello",'
            '"provider":"azure"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        getBaseUrl: () async => 'https://worker.example.com',
        getAccessToken: () async => 'tok',
      );
      container = makeContainer(api: PronounceApi(client));
      final ctrl = container.read(pronouncePlaybackControllerProvider.notifier);
      final t = target();

      await ctrl.play(t);
      await ctrl.stop();
      await ctrl.play(t);

      expect(posts, 1);
      expect(engine.playedUrls.length, 2);
    },
  );
}
