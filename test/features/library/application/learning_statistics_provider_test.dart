// Coverage: lib/features/library/application/learning_statistics_provider.dart
import 'dart:async';

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/secure_token_store.dart';
import 'package:enjoy_player/data/api/services/api_providers.dart';
import 'package:enjoy_player/data/api/services/auth_api.dart';
import 'package:enjoy_player/data/api/services/direct_uploads_api.dart';
import 'package:enjoy_player/data/api/services/stats_api.dart';
import 'package:enjoy_player/features/auth/data/auth_repository.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/library/application/learning_statistics_provider.dart';
import 'package:enjoy_player/features/library/domain/learning_statistics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _profile = UserProfile(id: 'u1', email: 'user@example.com', name: 'User');

ApiClient _testClient() => ApiClient(
  httpClient: http.Client(),
  getBaseUrl: () async => 'https://example.invalid',
  getAccessToken: () async => null,
);

class _FakeStatsApi extends StatsApi {
  _FakeStatsApi({this.response, this.error})
    : delay = Duration.zero,
      super(_testClient());

  final Map<String, dynamic>? response;
  final Object? error;
  final Duration delay;
  String? lastTimezone;
  int callCount = 0;

  @override
  Future<Map<String, dynamic>> learningStatistics({String? timezone}) async {
    callCount += 1;
    lastTimezone = timezone;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (error != null) throw error!;
    return response ?? const {};
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this._initial)
    : super(
        authApi: AuthApi(authClient: _testClient(), userClient: _testClient()),
        directUploadsApi: DirectUploadsApi(_testClient()),
        tokenStore: SecureTokenStore(const FlutterSecureStorage()),
        getBaseUrl: () async => 'https://example.invalid',
      );

  final AuthState _initial;

  @override
  Future<AuthState> loadInitialAuthState() async => _initial;
}

Future<AsyncValue<LearningStatistics?>> _awaitFirstEmission(
  ProviderContainer container,
) async {
  final completer = Completer<AsyncValue<LearningStatistics?>>();
  final sub = container.listen<AsyncValue<LearningStatistics?>>(
    learningStatisticsProvider,
    (_, next) {
      if (!completer.isCompleted && (next.hasValue || next.hasError)) {
        completer.complete(next);
      }
    },
    fireImmediately: true,
  );
  try {
    return await completer.future.timeout(const Duration(seconds: 5));
  } finally {
    sub.close();
  }
}

ProviderContainer _container({
  required _FakeStatsApi api,
  required AuthState initial,
}) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository(initial)),
      statsApiProvider.overrideWithValue(api),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('learningStatistics', () {
    test('returns null when not signed in (AuthSignedOut)', () async {
      final api = _FakeStatsApi(response: const {});
      final container = _container(api: api, initial: const AuthSignedOut());
      addTearDown(container.dispose);

      final result = await _awaitFirstEmission(container);
      expect(result.hasValue, isTrue);
      expect(result.requireValue, isNull);
      expect(api.callCount, 0);
    });

    test('parses LearningStatistics on success', () async {
      final api = _FakeStatsApi(
        response: const {
          'today': {'recordingDuration': 5000, 'recordingCount': 2},
          'week': {'recordingDuration': 30000, 'recordingCount': 12},
          'month': {'recordingDuration': 120000, 'recordingCount': 50},
        },
      );
      final container = _container(
        api: api,
        initial: const AuthSignedIn(profile: _profile),
      );
      addTearDown(container.dispose);

      final result = await _awaitFirstEmission(container);
      expect(result.hasValue, isTrue);
      final data = result.requireValue!;
      expect(data.today.recordingDurationMs, 5000);
      expect(data.today.recordingCount, 2);
      expect(data.week.recordingDurationMs, 30000);
      expect(data.month.recordingCount, 50);
      expect(api.callCount, 1);
    });

    test('passes timezone to StatsApi.learningStatistics', () async {
      final api = _FakeStatsApi(response: const {});
      final container = _container(
        api: api,
        initial: const AuthSignedIn(profile: _profile),
      );
      addTearDown(container.dispose);

      await _awaitFirstEmission(container);
      expect(api.lastTimezone, isNotNull);
      expect(api.lastTimezone!.isNotEmpty, isTrue);
    });

    test('returns empty LearningStatistics on TimeoutException', () async {
      final api = _FakeStatsApi(error: TimeoutException('slow'));
      final container = _container(
        api: api,
        initial: const AuthSignedIn(profile: _profile),
      );
      addTearDown(container.dispose);

      final result = await _awaitFirstEmission(container);
      expect(result.hasValue, isTrue);
      final data = result.requireValue!;
      expect(data.today.recordingDurationMs, 0);
      expect(data.today.recordingCount, 0);
    });

    test('returns empty LearningStatistics on generic exception', () async {
      final api = _FakeStatsApi(error: StateError('boom'));
      final container = _container(
        api: api,
        initial: const AuthSignedIn(profile: _profile),
      );
      addTearDown(container.dispose);

      final result = await _awaitFirstEmission(container);
      expect(result.hasValue, isTrue);
      final data = result.requireValue!;
      expect(data.today.recordingDurationMs, 0);
      expect(data.week.recordingCount, 0);
      expect(data.month.recordingDurationMs, 0);
    });

    test('returns null when auth is AuthAwaitingOtp', () async {
      final api = _FakeStatsApi(response: const {});
      final container = _container(
        api: api,
        initial: AuthAwaitingOtp(
          requestId: 'req-1',
          email: 'a@b.com',
          resendAfterSeconds: 30,
          startedAt: DateTime(2026),
        ),
      );
      addTearDown(container.dispose);

      final result = await _awaitFirstEmission(container);
      expect(result.hasValue, isTrue);
      expect(result.requireValue, isNull);
    });
  });
}
