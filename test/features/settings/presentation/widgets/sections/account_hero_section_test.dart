import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/account_hero_section.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class _FakeAuthCtrl extends AuthCtrl {
  _FakeAuthCtrl(this._state);
  AuthState _state;

  @override
  Future<AuthState> build() async => _state;

  void setState(AuthState next) {
    _state = next;
  }
}

const _profile = UserProfile(
  id: 'user-1',
  email: 'reader@example.com',
  name: 'Reader',
  balance: 12.5,
);

Widget _harness(Widget child, {required AuthCtrl authCtrl}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  return ProviderScope(
    overrides: [authCtrlProvider.overrideWith(() => authCtrl)],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      locale: const Locale('en', 'US'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Signed-in: renders name, email, profile button', (tester) async {
    final auth = _FakeAuthCtrl(const AuthSignedIn(profile: _profile));
    await tester.pumpWidget(
      _harness(const AccountHeroSection(), authCtrl: auth),
    );
    await tester.pump();

    expect(find.text('Reader'), findsWidgets);
    expect(find.text('reader@example.com'), findsWidgets);
    expect(find.text('ACCOUNT'), findsWidgets);
    expect(find.text('Profile, subscription, and sign out'), findsWidgets);
    expect(find.byIcon(Icons.manage_accounts_outlined), findsOneWidget);
    expect(find.text('Open profile'), findsOneWidget);
    // Fallback initial is rendered when no avatarUrl
    expect(find.text('R'), findsOneWidget);
  });

  testWidgets('Signed-in with empty name: shows ? placeholder for initial', (
    tester,
  ) async {
    const profile = UserProfile(
      id: 'user-2',
      email: 'noname@example.com',
      name: '',
      balance: 0,
    );
    final auth = _FakeAuthCtrl(const AuthSignedIn(profile: profile));
    await tester.pumpWidget(
      _harness(const AccountHeroSection(), authCtrl: auth),
    );
    await tester.pump();

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets(
    'Signed-out: shows sign-in CTA with login icon and navigates on tap',
    (tester) async {
      final auth = _FakeAuthCtrl(const AuthSignedOut());
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const AccountHeroSection()),
          GoRoute(
            path: '/sign-in',
            builder: (_, _) => const Scaffold(body: Text('SignIn')),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const Scaffold(body: Text('Profile')),
          ),
        ],
      );
      addTearDown(router.dispose);

      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF7B61FF),
        brightness: Brightness.dark,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authCtrlProvider.overrideWith(() => auth)],
          child: MaterialApp.router(
            theme: ThemeData(
              colorScheme: scheme,
              useMaterial3: true,
              brightness: Brightness.dark,
              extensions: [EnjoyThemeTokens.build(scheme)],
            ),
            locale: const Locale('en', 'US'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not signed in'), findsWidgets);
      expect(find.byIcon(Icons.login_rounded), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);

      // Tap the secondary button.
      await tester.tap(find.byIcon(Icons.login_rounded));
      await tester.pumpAndSettle();
      expect(find.text('SignIn'), findsOneWidget);
    },
  );

  testWidgets('Loading: renders skeleton placeholder', (tester) async {
    final pendingAuth = _PendingAuthCtrl();
    await tester.pumpWidget(
      _harness(const AccountHeroSection(), authCtrl: pendingAuth),
    );
    // Do not pump — should still be loading. Pump zero to attach.
    await tester.pump();

    expect(find.byType(Skeleton), findsOneWidget);
    pendingAuth.complete();
    await tester.pumpAndSettle();
  });
}

class _PendingAuthCtrl extends AuthCtrl {
  final Completer<AuthState> _completer = Completer<AuthState>();

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete(const AuthSignedOut());
    }
  }

  @override
  Future<AuthState> build() => _completer.future;
}
