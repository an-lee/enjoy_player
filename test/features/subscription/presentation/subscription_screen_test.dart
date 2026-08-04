import 'dart:async';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/credits/application/credits_packages_provider.dart';
import 'package:enjoy_player/features/credits/application/credits_summary_provider.dart';
import 'package:enjoy_player/features/credits/domain/credits_package.dart';
import 'package:enjoy_player/features/credits/domain/credits_summary.dart';
import 'package:enjoy_player/features/subscription/application/subscription_plans_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/subscription/domain/auto_renew_billing.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_plan.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_status.dart';
import 'package:enjoy_player/features/subscription/presentation/subscription_screen.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

class _SignedInAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'u1', email: 'a@b.com', name: 'Test'),
  );
}

const _emptySummary = CreditsSummary(
  tier: 'pro',
  dailyUsed: 0,
  dailyLimit: 60000,
  dailyRemaining: 60000,
  permanentAvailable: 0,
  resetAt: 0,
);

const _testPlans = [
  SubscriptionPlan(
    id: 'plan_monthly',
    tier: 'pro',
    interval: 'month',
    amount: 9.99,
  ),
  SubscriptionPlan(
    id: 'plan_yearly',
    tier: 'pro',
    interval: 'year',
    amount: 79.99,
  ),
];

Widget _harness(
  Widget child, {
  List<Override> overrides = const [],
  AuthCtrl Function()? authCtrlFactory,
}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
  return ProviderScope(
    overrides: [
      authCtrlProvider.overrideWith(authCtrlFactory ?? _SignedInAuthCtrl.new),
      creditsPackagesProvider.overrideWith(
        (ref) async => const <CreditsPackage>[],
      ),
      creditsSummaryProvider.overrideWith((ref) async => _emptySummary),
      subscriptionPlansProvider.overrideWith((ref) async => _testPlans),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: scheme,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows loading skeleton while status loads', (tester) async {
    final completer = Completer<SubscriptionStatus>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete(
          const SubscriptionStatus(
            subscriptionActive: true,
            subscriptionTier: SubscriptionTier.free,
          ),
        );
      }
    });

    await tester.pumpWidget(
      _harness(
        const SubscriptionScreen(),
        overrides: [
          subscriptionStatusProvider.overrideWith((ref) => completer.future),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('shows unified tier catalog for free users', (tester) async {
    await tester.pumpWidget(
      _harness(
        const SubscriptionScreen(),
        overrides: [
          subscriptionStatusProvider.overrideWith(
            (ref) async => const SubscriptionStatus(
              subscriptionActive: true,
              subscriptionTier: SubscriptionTier.free,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subscriptionTitle), findsWidgets);
    // Catalog title is shown.
    expect(find.text(l10n.subscriptionTierCatalogTitle), findsOneWidget);
    // Free + Lite + Pro tier names appear on their cards.
    expect(find.text(l10n.subscriptionTierFreeName), findsWidgets);
    expect(find.text(l10n.subscriptionTierLiteName), findsWidgets);
    expect(find.text(l10n.subscriptionTierProName), findsWidgets);
    // Pro tier CTA is "Choose Pro" (the user is not on Pro yet).
    expect(find.text(l10n.subscriptionTierCatalogChoosePro), findsOneWidget);
    expect(find.text(l10n.subscriptionTierCatalogChooseLite), findsOneWidget);
  });

  testWidgets('shows retry on error', (tester) async {
    await tester.pumpWidget(
      _harness(
        const SubscriptionScreen(),
        overrides: [
          subscriptionStatusProvider.overrideWith(
            (ref) async => throw Exception('network'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subscriptionErrorLoading), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);
  });

  testWidgets(
    'renders subscription screen on narrow phone without layout errors',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _harness(
          const SubscriptionScreen(),
          overrides: [
            subscriptionStatusProvider.overrideWith(
              (ref) async => const SubscriptionStatus(
                subscriptionActive: true,
                subscriptionTier: SubscriptionTier.free,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'auto-renew Pro hides tier catalog and shows membership cancel link',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          const SubscriptionScreen(),
          overrides: [
            subscriptionStatusProvider.overrideWith(
              (ref) async => const SubscriptionStatus(
                subscriptionActive: true,
                subscriptionTier: SubscriptionTier.pro,
                autoRenew: AutoRenewBilling(
                  active: true,
                  provider: 'stripe',
                  status: 'active',
                  autoRenew: true,
                  cancelAtPeriodEnd: false,
                  interval: 'month',
                  amount: 9.99,
                  tier: 'pro',
                  currentPeriodEnd: '2026-08-01T00:00:00.000Z',
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.subscriptionProMemberTitle), findsOneWidget);
      expect(find.text(l10n.subscriptionAutoRenewCancel), findsOneWidget);
      expect(find.text(l10n.subscriptionPayOnceTitle), findsNothing);
      // TierCatalog hides itself when a non-terminal auto-renew blocks new
      // subscriptions.
      expect(find.text(l10n.subscriptionTierCatalogTitle), findsNothing);
      expect(find.text(l10n.subscriptionTierCatalogChoosePro), findsNothing);
    },
  );

  testWidgets(
    'free user with legacy balance shows the discoverable balance-to-credits card',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          const SubscriptionScreen(),
          authCtrlFactory: () => _BalanceAuthCtrl(
            const UserProfile(
              id: 'u2',
              email: 'b@c.com',
              name: 'Balance',
              balance: 12.5,
            ),
          ),
          overrides: [
            subscriptionStatusProvider.overrideWith(
              (ref) async => const SubscriptionStatus(
                subscriptionActive: true,
                subscriptionTier: SubscriptionTier.free,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      // The balance card lives below the fold on a default test viewport;
      // scroll the ListView until it's built.
      await tester.scrollUntilVisible(
        find.text(l10n.subscriptionBalanceToCreditsTitle),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.subscriptionBalanceToCreditsTitle), findsOneWidget);
      expect(find.text(l10n.subscriptionBalanceToCreditsCta), findsOneWidget);
    },
  );
}

class _BalanceAuthCtrl extends AuthCtrl {
  _BalanceAuthCtrl(this._profile);

  final UserProfile _profile;

  @override
  Future<AuthState> build() async => AuthSignedIn(profile: _profile);
}
