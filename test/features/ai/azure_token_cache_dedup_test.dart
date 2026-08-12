import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/ai/azure_token_api.dart';
import 'package:enjoy_player/data/api/services/ai/azure_token_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _FakeAzureTokenApi extends AzureTokenApi {
  _FakeAzureTokenApi(this.handler) : super(_NullApiClient());

  final Future<Map<String, dynamic>> Function() handler;
  int callCount = 0;
  final List<Map<String, dynamic>?> lastUsages = <Map<String, dynamic>?>[];

  @override
  Future<Map<String, dynamic>> generateToken({
    Map<String, dynamic>? usage,
  }) async {
    callCount += 1;
    lastUsages.add(usage == null ? null : Map<String, dynamic>.of(usage));
    return handler();
  }
}

/// Pass-through ApiClient that the [AzureTokenApi] super-constructor
/// will accept; the fake subclass overrides every method the cache
/// actually calls.
class _NullApiClient extends ApiClient {
  _NullApiClient()
    : super(
        httpClient: _NullHttpClient(),
        getBaseUrl: () async => 'https://test.invalid',
        getAccessToken: () async => null,
      );
}

class _NullHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnsupportedError(
      'AzureTokenCache tests must override every method '
      'they exercise; the base class should never be called.',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AzureTokenCache', () {
    test('returns the cached token on a hit', () async {
      var n = 0;
      final api = _FakeAzureTokenApi(() async {
        n += 1;
        return <String, dynamic>{'token': 'tok-1', 'region': 'westus'};
      });
      final cache = AzureTokenCache(api: api);

      final a = await cache.getToken(durationSeconds: 30);
      final b = await cache.getToken(durationSeconds: 30);

      expect(a.token, 'tok-1');
      expect(b.token, 'tok-1');
      expect(n, 1, reason: 'second call must hit the cache');
    });

    test('concurrent calls share a single fetch', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final api = _FakeAzureTokenApi(() async {
        inFlight += 1;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        // Simulate the worker taking a moment to respond.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        inFlight -= 1;
        return <String, dynamic>{'token': 'tok-1', 'region': 'westus'};
      });
      final cache = AzureTokenCache(api: api);

      final results = await Future.wait([
        cache.getToken(durationSeconds: 30),
        cache.getToken(durationSeconds: 30),
        cache.getToken(durationSeconds: 30),
      ]);

      expect(results.map((r) => r.token).toSet(), {'tok-1'});
      expect(api.callCount, 1, reason: 'deduplication must collapse fetches');
      expect(maxInFlight, 1, reason: 'only one fetch may be in flight');
    });

    test('subsequent call after expiry hits the API again', () async {
      var n = 0;
      final api = _FakeAzureTokenApi(() async {
        n += 1;
        return <String, dynamic>{'token': 'tok-$n', 'region': 'westus'};
      });
      final cache = AzureTokenCache(api: api);
      // First fetch returns a token that is *just* about to expire;
      // we clear the cache so the next call has to fetch again.
      await cache.getToken(durationSeconds: 30);
      cache.clear();
      final second = await cache.getToken(durationSeconds: 30);
      expect(second.token, 'tok-2');
      expect(n, 2);
    });

    test('a failed fetch propagates and leaves no cached value', () async {
      var n = 0;
      final api = _FakeAzureTokenApi(() async {
        n += 1;
        throw StateError('worker offline');
      });
      final cache = AzureTokenCache(api: api);

      try {
        await cache.getToken(durationSeconds: 30);
        fail('expected StateError');
      } on StateError {
        // expected
      }

      // After a failure the in-flight slot is cleared so the next
      // call can retry instead of being permanently stuck on the
      // rejected Completer.
      try {
        await cache.getToken(durationSeconds: 30);
        fail('expected StateError');
      } on StateError {
        // expected
      }
      expect(n, 2, reason: 'second call should retry after a failure');
    });

    test('throws when token or region is missing from the response', () async {
      final api = _FakeAzureTokenApi(
        () async => <String, dynamic>{'token': '', 'region': 'westus'},
      );
      final cache = AzureTokenCache(api: api);

      expect(
        () => cache.getToken(durationSeconds: 30),
        throwsA(isA<StateError>()),
      );
    });

    test('assessment purpose sends usage.assessment.durationSeconds', () async {
      final api = _FakeAzureTokenApi(
        () async => <String, dynamic>{'token': 'tok', 'region': 'westus'},
      );
      final cache = AzureTokenCache(api: api);

      await cache.getToken(durationSeconds: 30);

      expect(api.lastUsages, hasLength(1));
      final usage = api.lastUsages.single!;
      expect(usage['purpose'], 'assessment');
      expect(usage['assessment'], isA<Map<String, dynamic>>());
      expect((usage['assessment'] as Map)['durationSeconds'], 30);
      expect(usage.containsKey('tts'), isFalse);
    });

    test(
      'tts purpose sends usage.tts.textLength (not durationSeconds)',
      () async {
        final api = _FakeAzureTokenApi(
          () async => <String, dynamic>{'token': 'tok', 'region': 'westus'},
        );
        final cache = AzureTokenCache(api: api);

        // Pass a nonsense durationSeconds to prove it is NOT forwarded for TTS.
        await cache.getToken(
          purpose: 'tts',
          textLength: 42,
          durationSeconds: 9999,
        );

        expect(api.lastUsages, hasLength(1));
        final usage = api.lastUsages.single!;
        expect(usage['purpose'], 'tts');
        expect(usage['tts'], isA<Map<String, dynamic>>());
        expect((usage['tts'] as Map)['textLength'], 42);
        expect(
          (usage['tts'] as Map).containsKey('durationSeconds'),
          isFalse,
          reason: 'TTS payload must not contain durationSeconds (issue #544).',
        );
        expect(usage.containsKey('assessment'), isFalse);
      },
    );
  });
}
