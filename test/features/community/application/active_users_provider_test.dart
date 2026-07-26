// Coverage: lib/features/community/application/active_users_provider.dart
import 'dart:async';

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/secure_token_store.dart';
import 'package:enjoy_player/data/api/services/api_providers.dart';
import 'package:enjoy_player/data/api/services/auth_api.dart';
import 'package:enjoy_player/data/api/services/direct_uploads_api.dart';
import 'package:enjoy_player/data/api/services/user_api.dart';
import 'package:enjoy_player/features/auth/data/auth_repository.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/community/application/active_users_provider.dart';
import 'package:enjoy_player/features/community/domain/active_user.dart';
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

class _FakeUserApi extends UserApi {
  _FakeUserApi({this.response, this.error, this.delay = Duration.zero})
    : super(_testClient());

  final Map<String, dynamic>? response;
  final Object? error;
  final Duration delay;
  String? lastTimezone;
  int callCount = 0;

  @override
  Future<Map<String, dynamic>> activeUsers({String? timezone}) async {
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

Future<AsyncValue<ActiveUsersResponse?>> _awaitFirstEmission(
  ProviderContainer container,
) async {
  final completer = Completer<AsyncValue<ActiveUsersResponse?>>();
  final sub = container.listen<AsyncValue<ActiveUsersResponse?>>(
    activeUsersProvider,
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
  required _FakeUserApi api,
  required AuthState initial,
}) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository(initial)),
      userApiProvider.overrideWithValue(api),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('activeUsers', () {
    test('returns null when not signed in (AuthSignedOut)', () async {
      final api = _FakeUserApi(response: const {'users': [], 'count': 0});
      final container = _container(api: api, initial: const AuthSignedOut());
      addTearDown(container.dispose);

      final result = await _awaitFirstEmission(container);
      expect(result.hasValue, isTrue);
      expect(result.requireValue, isNull);
      expect(api.callCount, 0);
    });

    test('parses ActiveUsersResponse on success', () async {
      final api = _FakeUserApi(
        response: const {
          'users': [
            {'id': 'u1', 'name': 'Alice'},
            {'id': 'u2', 'name': 'Bob'},
          ],
          'count': 2,
          'recordingsCountToday': 3,
          'recordingsDurationToday': 60000,
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
      expect(data.users.length, 2);
      expect(data.count, 2);
      expect(data.recordingsCountToday, 3);
      expect(data.recordingsDurationToday, 60000);
      expect(api.callCount, 1);
    });

    test('passes timezone to UserApi.activeUsers', () async {
      final api = _FakeUserApi(response: const {'users': [], 'count': 0});
      final container = _container(
        api: api,
        initial: const AuthSignedIn(profile: _profile),
      );
      addTearDown(container.dispose);

      await _awaitFirstEmission(container);
      expect(api.lastTimezone, isNotNull);
      expect(api.lastTimezone!.isNotEmpty, isTrue);
    });

    test('returns null on TimeoutException', () async {
      // The provider wraps the API call in a 8s `.timeout`. To exercise that
      // catch path quickly, throw TimeoutException from the fake (the
      // provider does not need to wait the full 8s).
      final api = _FakeUserApi(error: TimeoutException('slow'));
      final container = _container(
        api: api,
        initial: const AuthSignedIn(profile: _profile),
      );
      addTearDown(container.dispose);

      final result = await _awaitFirstEmission(container);
      expect(result.hasValue, isTrue);
      expect(result.requireValue, isNull);
    });

    test('rethrows non-timeout exceptions', () async {
      final api = _FakeUserApi(error: StateError('boom'));
      final container = _container(
        api: api,
        initial: const AuthSignedIn(profile: _profile),
      );
      addTearDown(container.dispose);

      final result = await _awaitFirstEmission(container);
      expect(result.hasError, isTrue);
      expect(result.error, isA<StateError>());
    });

    test('returns null when auth is AuthAwaitingOtp', () async {
      final api = _FakeUserApi(response: const {'users': [], 'count': 0});
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

    test('returns null when auth is AuthSigningInWebPkce', () async {
      final api = _FakeUserApi(response: const {'users': [], 'count': 0});
      final container = _container(
        api: api,
        initial: AuthSigningInWebPkce(
          oauthState: 's',
          codeVerifier: 'v',
          redirectUri: 'enjoyplayer://auth/callback',
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
