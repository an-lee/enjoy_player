import 'dart:convert';
import 'dart:io';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/data/api/secure_token_store.dart';
import 'package:enjoy_player/data/api/services/auth_api.dart';
import 'package:enjoy_player/data/api/services/direct_uploads_api.dart';
import 'package:enjoy_player/features/auth/data/auth_repository.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/update_profile_request.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureTokenStore tokenStore;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    tokenStore = SecureTokenStore(const FlutterSecureStorage());
  });

  AuthRepository buildRepo(http.Client client, {String? accessToken}) {
    final sharedClient = ApiClient(
      httpClient: client,
      getBaseUrl: () async => 'https://enjoy.bot',
      getAccessToken: () async => accessToken,
    );
    final api = AuthApi(authClient: sharedClient, userClient: sharedClient);
    return AuthRepository(
      authApi: api,
      directUploadsApi: DirectUploadsApi(sharedClient),
      tokenStore: tokenStore,
      getBaseUrl: () async => 'https://enjoy.bot',
    );
  }

  AuthRepository buildRepoWithBaseUrl(
    http.Client client,
    Future<String> Function() getBaseUrl,
  ) {
    final sharedClient = ApiClient(
      httpClient: client,
      getBaseUrl: getBaseUrl,
      getAccessToken: () async => null,
    );
    final api = AuthApi(authClient: sharedClient, userClient: sharedClient);
    return AuthRepository(
      authApi: api,
      directUploadsApi: DirectUploadsApi(sharedClient),
      tokenStore: tokenStore,
      getBaseUrl: getBaseUrl,
    );
  }

  // ---------------------------------------------------------------------------
  // sendOtp
  // ---------------------------------------------------------------------------
  group('AuthRepository.sendOtp', () {
    test('returns OtpSendResponse on success', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/otp/send');
        return http.Response(
          jsonEncode({
            'requestId': 'req-1',
            'expiresIn': 300,
            'resendAfter': 60,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = buildRepo(client);

      final response = await repo.sendOtp(email: ' test@example.com ');

      expect(response.requestId, 'req-1');
      expect(response.expiresIn, 300);
      expect(response.resendAfter, 60);
    });

    test('throws AuthFailure on ApiException', () async {
      final client = MockClient(
        (_) async => http.Response('rate limited', 429),
      );
      final repo = buildRepo(client);

      expect(
        () => repo.sendOtp(email: 'a@b.com'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.rateLimited,
          ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // signInGoogle (exercises _completeSignIn with user in response)
  // ---------------------------------------------------------------------------
  group('AuthRepository.signInGoogle', () {
    test('persists tokens and returns user from response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/google');
        return http.Response(
          jsonEncode({
            'accessToken': 'at-1',
            'refreshToken': 'rt-1',
            'expiresIn': 3600,
            'user': {'id': 'u1', 'email': 'g@x.com', 'name': 'G'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = buildRepo(client);

      final profile = await repo.signInGoogle(idToken: 'google-id-token');

      expect(profile.id, 'u1');
      expect(profile.email, 'g@x.com');
      expect(await tokenStore.readAccessToken(), 'at-1');
      expect(await tokenStore.readRefreshToken(), 'rt-1');
      // Profile should be cached
      final cached = await repo.readCachedProfile();
      expect(cached?.id, 'u1');
    });

    test('fetches profile when user is null in token response', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (request.url.path == '/api/v1/auth/google') {
          return http.Response(
            jsonEncode({
              'accessToken': 'at-2',
              'refreshToken': 'rt-2',
              'expiresIn': 7200,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/profile') {
          return http.Response(
            jsonEncode({'id': 'u2', 'email': 'p@x.com', 'name': 'P'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        fail('Unexpected ${request.url.path}');
      });
      final repo = buildRepo(client, accessToken: 'at-2');

      final profile = await repo.signInGoogle(idToken: 'tok');

      expect(profile.id, 'u2');
      expect(callCount, 2);
    });

    test('throws AuthFailure on API error', () async {
      final client = MockClient((_) async => http.Response('bad', 400));
      final repo = buildRepo(client);

      expect(
        () => repo.signInGoogle(idToken: 'bad-token'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.invalidCredentials,
          ),
        ),
      );
    });

    test(
      'throws AuthFailure on malformed token response (FormatException)',
      () async {
        final client = MockClient((_) async {
          return http.Response(
            jsonEncode({'accessToken': '', 'refreshToken': '', 'expiresIn': 0}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final repo = buildRepo(client);

        expect(
          () => repo.signInGoogle(idToken: 'tok'),
          throwsA(isA<AuthFailure>()),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // signInApple
  // ---------------------------------------------------------------------------
  group('AuthRepository.signInApple', () {
    test('persists tokens and returns user', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/apple');
        return http.Response(
          jsonEncode({
            'accessToken': 'at-a',
            'refreshToken': 'rt-a',
            'expiresIn': 3600,
            'user': {'id': 'apple-u', 'email': 'a@icloud.com', 'name': 'A'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = buildRepo(client);

      final profile = await repo.signInApple(
        identityToken: 'id-tok',
        authorizationCode: 'auth-code',
        fullName: {'givenName': 'Ada', 'familyName': 'L'},
      );

      expect(profile.id, 'apple-u');
      expect(await tokenStore.readAccessToken(), 'at-a');
    });
  });

  // ---------------------------------------------------------------------------
  // verifyOtp
  // ---------------------------------------------------------------------------
  group('AuthRepository.verifyOtp', () {
    test('returns profile on success', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/otp/verify');
        return http.Response(
          jsonEncode({
            'accessToken': 'at-otp',
            'refreshToken': 'rt-otp',
            'expiresIn': 3600,
            'user': {'id': 'otp-u', 'email': 'o@x.com', 'name': 'O'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = buildRepo(client);

      final profile = await repo.verifyOtp(
        requestId: 'req-1',
        email: ' o@x.com ',
        code: ' 123456 ',
      );

      expect(profile.id, 'otp-u');
    });

    test('throws AuthFailure with invalidCredentials on 422', () async {
      final client = MockClient((_) async => http.Response('wrong code', 422));
      final repo = buildRepo(client);

      expect(
        () => repo.verifyOtp(requestId: 'r', email: 'e', code: 'bad'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.invalidCredentials,
          ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // exchangePkceCode
  // ---------------------------------------------------------------------------
  group('AuthRepository.exchangePkceCode', () {
    test('returns profile on success', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/token');
        return http.Response(
          jsonEncode({
            'accessToken': 'at-pkce',
            'refreshToken': 'rt-pkce',
            'expiresIn': 3600,
            'user': {'id': 'pkce-u', 'email': 'p@x.com', 'name': 'P'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = buildRepo(client);

      final profile = await repo.exchangePkceCode(
        code: 'auth-code',
        codeVerifier: 'verifier',
        redirectUri: 'enjoyplayer://auth/callback',
      );

      expect(profile.id, 'pkce-u');
      expect(await tokenStore.readRefreshToken(), 'rt-pkce');
    });

    test('throws AuthFailure on server error', () async {
      final client = MockClient((_) async => http.Response('oops', 500));
      final repo = buildRepo(client);

      expect(
        () => repo.exchangePkceCode(
          code: 'c',
          codeVerifier: 'v',
          redirectUri: 'r',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.serverError,
          ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // buildPkceAuthorizeUri
  // ---------------------------------------------------------------------------
  group('AuthRepository.buildPkceAuthorizeUri', () {
    test('builds correct URI without trailing slash in base', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final repo = buildRepoWithBaseUrl(
        client,
        () async => 'https://enjoy.bot',
      );

      final uri = await repo.buildPkceAuthorizeUri(
        redirectUri: 'enjoyplayer://auth/callback',
        codeChallenge: 'challenge123',
        state: 'state-abc',
      );

      expect(
        uri.toString(),
        startsWith('https://enjoy.bot/api/v1/auth/authorize'),
      );
      expect(uri.queryParameters['client_id'], 'enjoy_player');
      expect(
        uri.queryParameters['redirect_uri'],
        'enjoyplayer://auth/callback',
      );
      expect(uri.queryParameters['code_challenge'], 'challenge123');
      expect(uri.queryParameters['code_challenge_method'], 'S256');
      expect(uri.queryParameters['state'], 'state-abc');
    });

    test('trims trailing slash from base URL', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final repo = buildRepoWithBaseUrl(
        client,
        () async => 'https://enjoy.bot/',
      );

      final uri = await repo.buildPkceAuthorizeUri(
        redirectUri: 'enjoyplayer://auth/callback',
        codeChallenge: 'ch',
        state: 'st',
      );

      expect(
        uri.toString(),
        startsWith('https://enjoy.bot/api/v1/auth/authorize'),
      );
      expect(uri.toString(), isNot(contains('//api')));
    });
  });

  // ---------------------------------------------------------------------------
  // fetchProfile
  // ---------------------------------------------------------------------------
  group('AuthRepository.fetchProfile', () {
    test('returns profile and caches it on success', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/profile');
        return http.Response(
          jsonEncode({'id': 'fp-1', 'email': 'f@x.com', 'name': 'F'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = buildRepo(client, accessToken: 'tok');

      final profile = await repo.fetchProfile();

      expect(profile.id, 'fp-1');
      final cached = await repo.readCachedProfile();
      expect(cached?.id, 'fp-1');
    });

    test('clears session and throws on 401', () async {
      await tokenStore.writeAccessToken('old-token');
      await tokenStore.writeRefreshToken('old-refresh');
      final client = MockClient(
        (_) async => http.Response('unauthorized', 401),
      );
      final repo = buildRepo(client, accessToken: 'old-token');

      expect(
        () => repo.fetchProfile(),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.sessionRevoked,
          ),
        ),
      );

      // Wait for the async clearSession to complete
      await Future<void>.delayed(Duration.zero);
      expect(await tokenStore.readAccessToken(), isNull);
      expect(await tokenStore.readRefreshToken(), isNull);
    });

    test('throws AuthFailure without clearing session on 500', () async {
      await tokenStore.writeAccessToken('tok-500');
      final client = MockClient((_) async => http.Response('error', 500));
      final repo = buildRepo(client, accessToken: 'tok-500');

      expect(
        () => repo.fetchProfile(),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.serverError,
          ),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(await tokenStore.readAccessToken(), 'tok-500');
    });
  });

  // ---------------------------------------------------------------------------
  // updateProfile
  // ---------------------------------------------------------------------------
  group('AuthRepository.updateProfile', () {
    test('PATCHes profile and caches result', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/profile');
        return http.Response(
          jsonEncode({'id': 'up-1', 'email': 'u@x.com', 'name': 'NewName'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = buildRepo(client, accessToken: 'tok');

      final profile = await repo.updateProfile(
        const UpdateProfileRequest(name: 'NewName'),
      );

      expect(profile.name, 'NewName');
      final cached = await repo.readCachedProfile();
      expect(cached?.name, 'NewName');
    });

    test('falls back to fetchProfile when body is empty', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/profile');
        return http.Response(
          jsonEncode({'id': 'up-2', 'email': 'u@x.com', 'name': 'Fetched'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = buildRepo(client, accessToken: 'tok');

      final profile = await repo.updateProfile(const UpdateProfileRequest());

      expect(profile.name, 'Fetched');
    });

    test('clears session and throws on 401', () async {
      await tokenStore.writeAccessToken('tok-up');
      await tokenStore.writeRefreshToken('ref-up');
      final client = MockClient(
        (_) async => http.Response('unauthorized', 401),
      );
      final repo = buildRepo(client, accessToken: 'tok-up');

      expect(
        () => repo.updateProfile(const UpdateProfileRequest(name: 'X')),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.sessionRevoked,
          ),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(await tokenStore.readAccessToken(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // updateAvatar — additional edge cases
  // ---------------------------------------------------------------------------
  group('AuthRepository.updateAvatar edge cases', () {
    test('rejects empty file', () async {
      final client = MockClient((_) async {
        fail('should not call network');
      });
      final repo = buildRepo(client, accessToken: 'tok');

      expect(
        () => repo.updateAvatar(bytes: [], filename: 'a.jpg'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            'Avatar file is empty',
          ),
        ),
      );
    });

    test('rejects unsupported content type', () async {
      final client = MockClient((_) async {
        fail('should not call network');
      });
      final repo = buildRepo(client, accessToken: 'tok');

      expect(
        () => repo.updateAvatar(
          bytes: [1, 2, 3],
          filename: 'a.gif',
          contentType: 'image/gif',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            'Avatar must be JPEG, PNG, or WebP',
          ),
        ),
      );
    });

    test('rejects file with no recognizable extension and null mime', () async {
      final client = MockClient((_) async {
        fail('should not call network');
      });
      final repo = buildRepo(client, accessToken: 'tok');

      expect(
        () => repo.updateAvatar(bytes: [1, 2, 3], filename: 'noext'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('throws AuthFailure on upload API error with 401', () async {
      await tokenStore.writeAccessToken('tok-av');
      await tokenStore.writeRefreshToken('ref-av');
      final client = MockClient(
        (_) async => http.Response('unauthorized', 401),
      );
      final repo = buildRepo(client, accessToken: 'tok-av');

      expect(
        () => repo.updateAvatar(
          bytes: [1, 2, 3],
          filename: 'a.png',
          contentType: 'image/png',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.sessionRevoked,
          ),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(await tokenStore.readAccessToken(), isNull);
    });

    test(
      'infers content type from filename when contentType is empty',
      () async {
        var sawCreate = false;
        final client = MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path == '/api/v1/direct_uploads') {
            sawCreate = true;
            return http.Response(
              jsonEncode({
                'signed_id': 'sid-1',
                'direct_upload': {
                  'url': 'https://storage.example/up',
                  'headers': <String, String>{},
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.method == 'PUT' &&
              request.url.host == 'storage.example') {
            return http.Response('', 200);
          }
          if (request.method == 'PATCH' &&
              request.url.path == '/api/v1/profile') {
            return http.Response(
              jsonEncode({'id': 'av-1', 'email': 'a@b.c', 'name': 'A'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          fail('Unexpected ${request.method} ${request.url}');
        });
        final repo = buildRepo(client, accessToken: 'tok');

        final profile = await repo.updateAvatar(
          bytes: [1, 2, 3],
          filename: 'photo.webp',
          contentType: '  ',
        );

        expect(sawCreate, isTrue);
        expect(profile.id, 'av-1');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // readCachedProfile
  // ---------------------------------------------------------------------------
  group('AuthRepository.readCachedProfile', () {
    test('returns null when no cached profile exists', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final repo = buildRepo(client);

      expect(await repo.readCachedProfile(), isNull);
    });

    test('returns null when cached profile is empty string', () async {
      await tokenStore.writeCachedProfileJson('');
      final client = MockClient((_) async => http.Response('{}', 200));
      final repo = buildRepo(client);

      expect(await repo.readCachedProfile(), isNull);
    });

    test('returns null when cached profile is invalid JSON', () async {
      await tokenStore.writeCachedProfileJson('not-json{{{');
      final client = MockClient((_) async => http.Response('{}', 200));
      final repo = buildRepo(client);

      expect(await repo.readCachedProfile(), isNull);
    });

    test(
      'returns null when cached profile is a JSON array (not a map)',
      () async {
        await tokenStore.writeCachedProfileJson('[1,2,3]');
        final client = MockClient((_) async => http.Response('{}', 200));
        final repo = buildRepo(client);

        expect(await repo.readCachedProfile(), isNull);
      },
    );

    test('returns UserProfile for valid cached JSON', () async {
      await tokenStore.writeCachedProfileJson(
        jsonEncode({'id': 'c1', 'email': 'c@x.com', 'name': 'Cached'}),
      );
      final client = MockClient((_) async => http.Response('{}', 200));
      final repo = buildRepo(client);

      final profile = await repo.readCachedProfile();

      expect(profile, isNotNull);
      expect(profile!.id, 'c1');
      expect(profile.name, 'Cached');
    });
  });

  // ---------------------------------------------------------------------------
  // hasAccessToken
  // ---------------------------------------------------------------------------
  group('AuthRepository.hasAccessToken', () {
    test('returns false when no token stored', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final repo = buildRepo(client);

      expect(await repo.hasAccessToken(), isFalse);
    });

    test('returns false when token is empty string', () async {
      await tokenStore.writeAccessToken('');
      final client = MockClient((_) async => http.Response('{}', 200));
      final repo = buildRepo(client);

      expect(await repo.hasAccessToken(), isFalse);
    });

    test('returns true when token is present', () async {
      await tokenStore.writeAccessToken('real-token');
      final client = MockClient((_) async => http.Response('{}', 200));
      final repo = buildRepo(client);

      expect(await repo.hasAccessToken(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // clearSession
  // ---------------------------------------------------------------------------
  group('AuthRepository.clearSession', () {
    test('clears all auth secrets', () async {
      await tokenStore.writeAccessToken('a');
      await tokenStore.writeRefreshToken('r');
      await tokenStore.writeCachedProfileJson('{}');
      await tokenStore.writeTokenExpiresAt('2099-01-01T00:00:00Z');
      final client = MockClient((_) async => http.Response('{}', 200));
      final repo = buildRepo(client);

      await repo.clearSession();

      expect(await tokenStore.readAccessToken(), isNull);
      expect(await tokenStore.readRefreshToken(), isNull);
      expect(await tokenStore.readCachedProfileJson(), isNull);
      expect(await tokenStore.readTokenExpiresAt(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // loadInitialAuthState — additional branches
  // ---------------------------------------------------------------------------
  group('AuthRepository.loadInitialAuthState (extended)', () {
    test(
      'refreshes expired token and returns signed in with cached profile',
      () async {
        await tokenStore.writeAccessToken('expired-token');
        await tokenStore.writeRefreshToken('refresh-1');
        // Set expiry in the past
        await tokenStore.writeTokenExpiresAt('2020-01-01T00:00:00.000Z');
        await tokenStore.writeCachedProfileJson(
          jsonEncode({'id': 'u-exp', 'email': 'e@x.com', 'name': 'E'}),
        );

        final client = MockClient((request) async {
          if (request.url.path == '/api/v1/auth/refresh') {
            return http.Response(
              jsonEncode({
                'accessToken': 'new-at',
                'refreshToken': 'new-rt',
                'expiresIn': 3600,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          fail('Unexpected ${request.url.path}');
        });
        final repo = buildRepo(client);

        final state = await repo.loadInitialAuthState();

        expect(state, isA<AuthSignedIn>());
        expect((state as AuthSignedIn).profile.id, 'u-exp');
        expect(await tokenStore.readAccessToken(), 'new-at');
      },
    );

    test('returns signed out when token expired and refresh fails', () async {
      await tokenStore.writeAccessToken('expired-token');
      await tokenStore.writeRefreshToken('bad-refresh');
      await tokenStore.writeTokenExpiresAt('2020-01-01T00:00:00.000Z');

      final client = MockClient((_) async => http.Response('denied', 401));
      final repo = buildRepo(client);

      final state = await repo.loadInitialAuthState();

      expect(state, isA<AuthSignedOut>());
    });

    test('fetches profile from network when no cached profile', () async {
      await tokenStore.writeAccessToken('valid-token');
      // No expiry set — token is not expired

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/profile') {
          return http.Response(
            jsonEncode({'id': 'net-u', 'email': 'n@x.com', 'name': 'Net'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        fail('Unexpected ${request.url.path}');
      });
      final repo = buildRepo(client, accessToken: 'valid-token');

      final state = await repo.loadInitialAuthState();

      expect(state, isA<AuthSignedIn>());
      expect((state as AuthSignedIn).profile.id, 'net-u');
    });

    test(
      'returns signed out and clears session when fetchProfile throws AuthFailure',
      () async {
        await tokenStore.writeAccessToken('valid-token');
        await tokenStore.writeRefreshToken('ref-1');

        final client = MockClient(
          (_) async => http.Response('unauthorized', 401),
        );
        final repo = buildRepo(client, accessToken: 'valid-token');

        final state = await repo.loadInitialAuthState();

        expect(state, isA<AuthSignedOut>());
        // Session should be cleared by the AuthFailure path
        expect(await tokenStore.readAccessToken(), isNull);
      },
    );

    test(
      'returns signed out without clearing tokens on generic (non-AuthFailure) error',
      () async {
        await tokenStore.writeAccessToken('valid-token');
        await tokenStore.writeRefreshToken('ref-1');

        final client = MockClient((_) async {
          throw const SocketException('network down');
        });
        final repo = buildRepo(client, accessToken: 'valid-token');

        final state = await repo.loadInitialAuthState();

        expect(state, isA<AuthSignedOut>());
        // Tokens preserved — transient error
        expect(await tokenStore.readAccessToken(), 'valid-token');
      },
    );

    test('token not expired when expiresAt is in the future', () async {
      await tokenStore.writeAccessToken('valid-token');
      await tokenStore.writeTokenExpiresAt('2099-12-31T23:59:59.000Z');
      await tokenStore.writeCachedProfileJson(
        jsonEncode({'id': 'future-u', 'email': 'f@x.com', 'name': 'F'}),
      );

      final client = MockClient((_) async {
        fail('network should not be called');
      });
      final repo = buildRepo(client);

      final state = await repo.loadInitialAuthState();

      expect(state, isA<AuthSignedIn>());
      expect((state as AuthSignedIn).profile.id, 'future-u');
    });

    test('token not expired when expiresAt is unparseable', () async {
      await tokenStore.writeAccessToken('valid-token');
      await tokenStore.writeTokenExpiresAt('not-a-date');
      await tokenStore.writeCachedProfileJson(
        jsonEncode({'id': 'bad-date-u', 'email': 'b@x.com', 'name': 'B'}),
      );

      final client = MockClient((_) async {
        fail('network should not be called');
      });
      final repo = buildRepo(client);

      final state = await repo.loadInitialAuthState();

      expect(state, isA<AuthSignedIn>());
      expect((state as AuthSignedIn).profile.id, 'bad-date-u');
    });

    test('token not expired when expiresAt is empty', () async {
      await tokenStore.writeAccessToken('valid-token');
      await tokenStore.writeTokenExpiresAt('');
      await tokenStore.writeCachedProfileJson(
        jsonEncode({'id': 'empty-date-u', 'email': 'e@x.com', 'name': 'E'}),
      );

      final client = MockClient((_) async {
        fail('network should not be called');
      });
      final repo = buildRepo(client);

      final state = await repo.loadInitialAuthState();

      expect(state, isA<AuthSignedIn>());
    });

    test('clears cached profile when no access token', () async {
      await tokenStore.writeCachedProfileJson(
        jsonEncode({'id': 'stale', 'email': 's@x.com', 'name': 'S'}),
      );

      final client = MockClient((_) async => http.Response('{}', 200));
      final repo = buildRepo(client);

      final state = await repo.loadInitialAuthState();

      expect(state, isA<AuthSignedOut>());
      expect(await tokenStore.readCachedProfileJson(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // refreshSession — empty refresh token
  // ---------------------------------------------------------------------------
  group('AuthRepository.refreshSession (extended)', () {
    test('returns false when refresh token is empty string', () async {
      await tokenStore.writeAccessToken('access-1');
      await tokenStore.writeRefreshToken('');
      final client = MockClient((_) async {
        fail('should not call network');
      });
      final repo = buildRepo(client);

      final ok = await repo.refreshSession();

      expect(ok, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // authFailureCodeForApiException — additional status codes
  // ---------------------------------------------------------------------------
  group('authFailureCodeForApiException (extended)', () {
    test('status 418 (teapot) maps to unknown', () {
      const e = ApiException(message: 'teapot', statusCode: 418);
      expect(authFailureCodeForApiException(e), AuthFailureCode.unknown);
    });

    test('status 502 maps to serverError', () {
      const e = ApiException(message: 'bad gateway', statusCode: 502);
      expect(authFailureCodeForApiException(e), AuthFailureCode.serverError);
    });
  });
}
