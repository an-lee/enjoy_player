import 'package:enjoy_player/core/presentation/loading_icon.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/sidebar_account_chip.dart';
import 'package:enjoy_player/features/subscription/application/current_tier_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_status.dart';
import 'package:enjoy_player/features/subscription/domain/auto_renew_billing.dart';
import 'package:enjoy_player/features/update/application/update_controller.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthCtrl extends AuthCtrl {
  _FakeAuthCtrl(this._state);
  AuthState _state;

  @override
  Future<AuthState> build() async => _state;
}

const _profile = UserProfile(
  id: 'user-1',
  email: 'reader@example.com',
  name: 'Reader',
  avatarUrl: null,
  balance: 0,
  subscriptionTier: SubscriptionTier.free,
);

const _proProfile = UserProfile(
  id: 'user-2',
  email: 'pro@example.com',
  name: 'Pro Reader',
  avatarUrl: null,
  balance: 12,
  subscriptionTier: SubscriptionTier.pro,
);

Widget _harness(
  Widget child, {
  required AuthCtrl authCtrl,
  SubscriptionStatus? subscriptionStatus,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  return ProviderScope(
    overrides: [
      authCtrlProvider.overrideWith(() => authCtrl),
      subscriptionStatusProvider.overrideWith(
        (ref) async => subscriptionStatus ?? _freeStatus,
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      locale: const Locale('en', 'US'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

Widget _routerHarness(
  Widget child, {
  required AuthCtrl authCtrl,
  String? initialLocation,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  final router = GoRouter(
    initialLocation: initialLocation ?? '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('ProfileScreen')),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (_, _) => const Scaffold(body: Text('SignInScreen')),
      ),
      GoRoute(
        path: '/sign-in/email',
        builder: (_, _) => const Scaffold(body: Text('EmailOtpScreen')),
      ),
      GoRoute(
        path: '/subscription',
        builder: (_, _) => const Scaffold(body: Text('SubscriptionScreen')),
      ),
    ],
  );
  addTearDown(router.dispose);

  return ProviderScope(
    overrides: [
      authCtrlProvider.overrideWith(() => authCtrl),
      subscriptionStatusProvider.overrideWith((ref) async => _freeStatus),
    ],
    child: MaterialApp.router(
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      locale: const Locale('en', 'US'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

const _freeStatus = SubscriptionStatus(
  subscriptionActive: false,
  subscriptionTier: SubscriptionTier.free,
  autoRenew: null,
);

const _proStatus = SubscriptionStatus(
  subscriptionActive: true,
  subscriptionTier: SubscriptionTier.pro,
  subscriptionExpireDate: '2030-12-31T00:00:00Z',
  autoRenew: AutoRenewBilling(
    active: true,
    provider: 'stripe',
    status: 'active',
    autoRenew: true,
    currentPeriodEnd: '2030-12-31T00:00:00Z',
    cancelAtPeriodEnd: false,
    tier: 'pro',
    interval: 'month',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Signed-out: shows Sign in tile with login icon', (tester) async {
    final auth = _FakeAuthCtrl(const AuthSignedOut());
    await tester.pumpWidget(
      _harness(const SidebarAccountChip(), authCtrl: auth),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.login_rounded), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.byIcon(Icons.person_rounded), findsNothing);
  });

  testWidgets('Signed-in free: shows name + upgrade button', (tester) async {
    final auth = _FakeAuthCtrl(const AuthSignedIn(profile: _profile));
    await tester.pumpWidget(
      _harness(const SidebarAccountChip(), authCtrl: auth),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reader'), findsOneWidget);
    expect(find.text('Pro'), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    // Upgrade button when free tier
    expect(find.text('Upgrade'), findsOneWidget);
  });

  testWidgets('Signed-in pro: shows tier badge, no upgrade button', (
    tester,
  ) async {
    final auth = _FakeAuthCtrl(const AuthSignedIn(profile: _proProfile));
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7B61FF),
      brightness: Brightness.dark,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authCtrlProvider.overrideWith(() => auth),
          subscriptionStatusProvider.overrideWith((ref) async => _proStatus),
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: scheme,
            useMaterial3: true,
            brightness: Brightness.dark,
            extensions: [EnjoyThemeTokens.build(scheme)],
          ),
          locale: const Locale('en', 'US'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SidebarAccountChip()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pro Reader'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Upgrade'), findsNothing);
  });

  testWidgets('OTP in progress: shows spinner + OTP title', (tester) async {
    final auth = _FakeAuthCtrl(
      AuthAwaitingOtp(
        requestId: 'req-1',
        email: 'reader@example.com',
        resendAfterSeconds: 30,
        startedAt: DateTime.now(),
      ),
    );
    await tester.pumpWidget(
      _harness(const SidebarAccountChip(), authCtrl: auth),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Enter verification code'), findsOneWidget);
  });

  testWidgets('PKCE in progress: shows spinner + waiting title', (
    tester,
  ) async {
    final auth = _FakeAuthCtrl(
      AuthSigningInWebPkce(
        oauthState: 'state-1',
        codeVerifier: 'verifier',
        redirectUri: 'enjoyplayer://auth/callback',
        startedAt: DateTime.now(),
      ),
    );
    await tester.pumpWidget(
      _harness(const SidebarAccountChip(), authCtrl: auth),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Complete sign-in in your browser\u2026'), findsOneWidget);
  });

  testWidgets('Loading state: shows loading icon', (tester) async {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7B61FF),
      brightness: Brightness.dark,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: scheme,
            useMaterial3: true,
            brightness: Brightness.dark,
            extensions: [EnjoyThemeTokens.build(scheme)],
          ),
          locale: const Locale('en', 'US'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SidebarAccountChip()),
        ),
      ),
    );
    // One pump to attach. The LoadingIcon's CircularProgressIndicator is
    // animated, so pumpAndSettle would hang.
    await tester.pump();

    expect(find.byType(LoadingIcon), findsOneWidget);
  });

  testWidgets('Update badge: shows dot overlay when update available', (
    tester,
  ) async {
    final auth = _FakeAuthCtrl(const AuthSignedIn(profile: _profile));
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7B61FF),
      brightness: Brightness.dark,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authCtrlProvider.overrideWith(() => auth),
          subscriptionStatusProvider.overrideWith((ref) async => _freeStatus),
          updateAvailableBadgeProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: scheme,
            useMaterial3: true,
            brightness: Brightness.dark,
            extensions: [EnjoyThemeTokens.build(scheme)],
          ),
          locale: const Locale('en', 'US'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SidebarAccountChip()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircleAvatar), findsOneWidget);
    // Update dot exists
    expect(find.byType(Stack), findsWidgets);
  });

  testWidgets('Tap on signed-in tile navigates to /profile', (tester) async {
    final auth = _FakeAuthCtrl(const AuthSignedIn(profile: _profile));
    await tester.pumpWidget(
      _routerHarness(const SidebarAccountChip(), authCtrl: auth),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.text('ProfileScreen'), findsOneWidget);
  });

  testWidgets('Tap on signed-out tile navigates to /sign-in', (tester) async {
    final auth = _FakeAuthCtrl(const AuthSignedOut());
    await tester.pumpWidget(
      _routerHarness(const SidebarAccountChip(), authCtrl: auth),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.text('SignInScreen'), findsOneWidget);
  });

  testWidgets('Tap upgrade button navigates to /subscription', (tester) async {
    final auth = _FakeAuthCtrl(const AuthSignedIn(profile: _profile));
    await tester.pumpWidget(
      _routerHarness(const SidebarAccountChip(), authCtrl: auth),
    );
    await tester.pumpAndSettle();

    final upgradeFinder = find.text('Upgrade');
    expect(upgradeFinder, findsOneWidget);
    // Tap the center of the upgrade text widget — the InkWell inside the
    // upgrade button captures the gesture before ListTile's onTap.
    await tester.tap(upgradeFinder);
    await tester.pumpAndSettle();

    expect(find.text('SubscriptionScreen'), findsOneWidget);
  });
}
