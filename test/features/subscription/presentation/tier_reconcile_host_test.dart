import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_status.dart';
import 'package:enjoy_player/features/subscription/presentation/tier_reconcile_host.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Signed-in auth whose [AuthCtrl.refreshProfile] is a no-op so reconcile does
/// not touch a real repository.
class _NoOpRefreshAuthCtrl extends AuthCtrl {
  _NoOpRefreshAuthCtrl(this.profile);

  final UserProfile profile;

  @override
  Future<AuthState> build() async => AuthSignedIn(profile: profile);

  @override
  Future<void> refreshProfile() async {}
}

const _freeProfile = UserProfile(
  id: 'u1',
  email: 'a@b.com',
  name: 'Free',
  subscriptionTier: SubscriptionTier.free,
);
const _proProfile = UserProfile(
  id: 'u1',
  email: 'a@b.com',
  name: 'Pro',
  subscriptionTier: SubscriptionTier.pro,
);
const _proStatus = SubscriptionStatus(
  subscriptionActive: true,
  subscriptionTier: SubscriptionTier.pro,
);
const _liteStatus = SubscriptionStatus(
  subscriptionActive: true,
  subscriptionTier: SubscriptionTier.lite,
);

Widget _harness({
  required UserProfile profile,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      authCtrlProvider.overrideWith(() => _NoOpRefreshAuthCtrl(profile)),
      subscriptionStatusProvider.overrideWith((ref) async => _proStatus),
      ...overrides,
    ],
    child: MaterialApp(
      scaffoldMessengerKey: appScaffoldMessengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TierReconcileHost(child: Scaffold(body: SizedBox.expand())),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('celebrates a free -> Pro transition', (tester) async {
    await tester.pumpWidget(_harness(profile: _freeProfile));
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subscriptionUpgradedToPro), findsOneWidget);
  });

  testWidgets('celebrates a free -> Lite transition', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authCtrlProvider.overrideWith(
            () => _NoOpRefreshAuthCtrl(_freeProfile),
          ),
          subscriptionStatusProvider.overrideWith((ref) async => _liteStatus),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: appScaffoldMessengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TierReconcileHost(
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subscriptionUpgradedToLite), findsOneWidget);
  });

  testWidgets('does not celebrate when already Pro on mount', (tester) async {
    await tester.pumpWidget(_harness(profile: _proProfile));
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subscriptionUpgradedToPro), findsNothing);
  });

  testWidgets('renders its child unchanged', (tester) async {
    const key = Key('child');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authCtrlProvider.overrideWith(
            () => _NoOpRefreshAuthCtrl(_proProfile),
          ),
          subscriptionStatusProvider.overrideWith((ref) async => _proStatus),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: appScaffoldMessengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TierReconcileHost(
            child: Scaffold(body: Text('body', key: key)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(key), findsOneWidget);
  });
}
