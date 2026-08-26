/// Sign-in, profile fetch, and session lifecycle.
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/platform/linux_url_scheme_handler.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/features/auth/data/apple_sign_in_service.dart';
import 'package:enjoy_player/features/auth/data/auth_repository.dart';
import 'package:enjoy_player/features/auth/data/google_sign_in_service.dart';
import 'package:enjoy_player/features/auth/domain/auth_callback.dart';
import 'package:enjoy_player/features/auth/domain/auth_platform_support.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/pkce.dart';
import 'package:enjoy_player/features/auth/domain/update_profile_request.dart';

part 'auth_controller.g.dart';

final Logger _log = logNamed('auth');

const _pkceFlowTimeout = Duration(minutes: 5);

@Riverpod(keepAlive: true)
class AuthCtrl extends _$AuthCtrl {
  Timer? _pkceTimeoutTimer;
  int _flowGeneration = 0;

  @override
  Future<AuthState> build() async {
    ref.onDispose(_cancelPkceTimeout);
    final sw = Stopwatch()..start();
    _log.info('auth: loadInitialAuthState start');
    try {
      final state = await ref
          .read(authRepositoryProvider)
          .loadInitialAuthState();
      _log.info(
        'auth: loadInitialAuthState done in ${sw.elapsedMilliseconds}ms '
        '(${state.runtimeType})',
      );
      return state;
    } catch (e, st) {
      _log.warning(
        'auth: loadInitialAuthState failed after ${sw.elapsedMilliseconds}ms',
        e,
        st,
      );
      rethrow;
    }
  }

  void cancelSignIn() {
    _flowGeneration++;
    _cancelPkceTimeout();
    final current = state.valueOrNull;
    if (authFlowInProgress(current ?? const AuthSignedOut())) {
      state = const AsyncData(AuthSignedOut());
    }
  }

  Future<void> signInWithGoogle() async {
    final google = ref.read(googleSignInServiceProvider);
    final repo = ref.read(authRepositoryProvider);
    final gen = ++_flowGeneration;
    try {
      final idToken = await google.signInForIdToken();
      if (gen != _flowGeneration) return;
      if (idToken == null) return;
      final profile = await repo.signInGoogle(idToken: idToken);
      if (gen != _flowGeneration) return;
      state = AsyncData(AuthSignedIn(profile: profile));
    } on AuthFailure {
      if (gen != _flowGeneration) return;
      rethrow;
    } catch (e, st) {
      if (gen != _flowGeneration) return;
      _log.warning('google sign-in failed', e, st);
      throw AuthFailure('$e', code: AuthFailureCode.unknown);
    }
  }

  Future<void> signInWithApple() async {
    final apple = ref.read(appleSignInServiceProvider);
    final repo = ref.read(authRepositoryProvider);
    final gen = ++_flowGeneration;
    try {
      final credentials = await apple.signIn();
      if (gen != _flowGeneration) return;
      if (credentials == null) return;
      final profile = await repo.signInApple(
        identityToken: credentials.identityToken,
        authorizationCode: credentials.authorizationCode,
        fullName: credentials.fullName,
      );
      if (gen != _flowGeneration) return;
      state = AsyncData(AuthSignedIn(profile: profile));
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (gen != _flowGeneration) return;
      _log.warning(
        'apple sign-in authorization failed: ${e.code} ${e.message}',
      );
      throw AuthFailure(e.message, code: AuthFailureCode.invalidCredentials);
    } on AuthFailure {
      rethrow;
    } catch (e, st) {
      if (gen != _flowGeneration) return;
      _log.warning('apple sign-in failed', e, st);
      throw AuthFailure('$e', code: AuthFailureCode.unknown);
    }
  }

  Future<void> sendOtp({required String email}) async {
    final repo = ref.read(authRepositoryProvider);
    final gen = ++_flowGeneration;
    _cancelPkceTimeout();
    final response = await repo.sendOtp(email: email);
    if (gen != _flowGeneration) return;
    state = AsyncData(
      AuthAwaitingOtp(
        requestId: response.requestId,
        email: email.trim(),
        resendAfterSeconds: response.resendAfter,
        startedAt: DateTime.now(),
      ),
    );
  }

  Future<void> verifyOtp({required String code}) async {
    final current = state.valueOrNull;
    if (current is! AuthAwaitingOtp) {
      throw const AuthFailure('No OTP sign-in in progress');
    }
    final repo = ref.read(authRepositoryProvider);
    final gen = ++_flowGeneration;
    final profile = await repo.verifyOtp(
      requestId: current.requestId,
      email: current.email,
      code: code,
    );
    if (gen != _flowGeneration) return;
    state = AsyncData(AuthSignedIn(profile: profile));
  }

  Future<void> resendOtp() async {
    final current = state.valueOrNull;
    if (current is! AuthAwaitingOtp) return;
    await sendOtp(email: current.email);
  }

  Future<void> startWebPkceSignIn() async {
    final repo = ref.read(authRepositoryProvider);
    final gen = ++_flowGeneration;
    _cancelPkceTimeout();
    final pkce = generatePkcePair();
    final oauthState = generateOAuthState();
    final redirectUri = authPkceRedirectUri();
    final authorizeUri = await repo.buildPkceAuthorizeUri(
      redirectUri: redirectUri,
      codeChallenge: pkce.challenge,
      state: oauthState,
    );
    if (gen != _flowGeneration) return;
    state = AsyncData(
      AuthSigningInWebPkce(
        oauthState: oauthState,
        codeVerifier: pkce.verifier,
        redirectUri: redirectUri,
        startedAt: DateTime.now(),
      ),
    );
    _pkceTimeoutTimer = Timer(_pkceFlowTimeout, () {
      if (gen != _flowGeneration) return;
      final s = state.valueOrNull;
      if (s is AuthSigningInWebPkce) {
        state = const AsyncData(AuthSignedOut());
      }
    });
    // Refresh the enjoyplayer:// handler registration right before the
    // browser opens: a moved binary or fresh AppImage run may not have a
    // valid handler yet. Failures are contained inside the helper.
    if (defaultTargetPlatform == TargetPlatform.linux) {
      await ensureEnjoyplayerSchemeHandler();
    }
    final launched = await launchUrl(
      authorizeUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      if (gen != _flowGeneration) return;
      _cancelPkceTimeout();
      state = const AsyncData(AuthSignedOut());
      throw const AuthFailure('Could not open sign-in browser');
    }
  }

  Future<void> handleAuthCallbackUri(Uri uri) async {
    final current = state.valueOrNull;
    if (current is! AuthSigningInWebPkce) {
      // Typical when the callback arrives in a fresh process (the app was
      // restarted while the browser was open): the in-memory PKCE verifier
      // and state are gone, so sign-in must be retried.
      _log.info('auth callback ignored: no web PKCE flow in progress');
      return;
    }
    final parsed = parseAuthCallbackUri(uri);
    if (parsed == null) {
      _log.warning('auth callback ignored: invalid uri or missing params');
      return;
    }
    if (parsed.state != current.oauthState) {
      _log.warning('auth callback ignored: state mismatch');
      return;
    }
    final gen = _flowGeneration;
    final repo = ref.read(authRepositoryProvider);
    try {
      final profile = await repo.exchangePkceCode(
        code: parsed.code,
        codeVerifier: current.codeVerifier,
        redirectUri: current.redirectUri,
      );
      if (gen != _flowGeneration) return;
      _cancelPkceTimeout();
      state = AsyncData(AuthSignedIn(profile: profile));
    } on AuthFailure {
      if (gen != _flowGeneration) return;
      _cancelPkceTimeout();
      state = const AsyncData(AuthSignedOut());
      rethrow;
    } catch (e, st) {
      // Any other failure here (e.g. a secure-storage PlatformException
      // persisting tokens) must still reset state and surface to the user —
      // otherwise the flow stays stuck on the "waiting for browser" pane
      // forever even though the server-side exchange already succeeded.
      if (gen != _flowGeneration) return;
      _cancelPkceTimeout();
      state = const AsyncData(AuthSignedOut());
      _log.warning('web PKCE callback failed', e, st);
      throw AuthFailure('$e', code: AuthFailureCode.unknown);
    }
  }

  Future<void> signOut() async {
    _flowGeneration++;
    _cancelPkceTimeout();
    await ref.read(authRepositoryProvider).clearSession();
    // Update auth state before optional provider sign-out so a Google SDK
    // failure (common when the user signed in via email or PKCE) cannot
    // leave the UI showing a signed-in session after tokens were cleared.
    state = const AsyncData(AuthSignedOut());
    try {
      await ref.read(googleSignInServiceProvider).signOut();
    } catch (e, st) {
      _log.warning('google sign-out failed after session cleared', e, st);
    }
  }

  Future<void> refreshProfile() async {
    final cur = state.valueOrNull;
    if (cur is! AuthSignedIn) return;
    final profile = await ref.read(authRepositoryProvider).fetchProfile();
    state = AsyncData(AuthSignedIn(profile: profile));
  }

  Future<void> updateProfile(UpdateProfileRequest request) async {
    final cur = state.valueOrNull;
    if (cur is! AuthSignedIn) {
      throw const AuthFailure(
        'Not signed in',
        code: AuthFailureCode.sessionRevoked,
      );
    }
    final profile = await ref
        .read(authRepositoryProvider)
        .updateProfile(request);
    state = AsyncData(AuthSignedIn(profile: profile));
  }

  Future<void> updateAvatar({
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    final cur = state.valueOrNull;
    if (cur is! AuthSignedIn) {
      throw const AuthFailure(
        'Not signed in',
        code: AuthFailureCode.sessionRevoked,
      );
    }
    final profile = await ref
        .read(authRepositoryProvider)
        .updateAvatar(
          bytes: bytes,
          filename: filename,
          contentType: contentType,
        );
    state = AsyncData(AuthSignedIn(profile: profile));
  }

  Future<void> syncLocaleToServerIfSignedIn(Locale? locale) async {
    final cur = state.valueOrNull;
    if (cur is! AuthSignedIn) return;
    final tag = locale?.toLanguageTag();
    if (tag == null) return;
    await updateProfile(UpdateProfileRequest(locale: tag));
  }

  void _cancelPkceTimeout() {
    _pkceTimeoutTimer?.cancel();
    _pkceTimeoutTimer = null;
  }
}
