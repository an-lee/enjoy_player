import 'dart:async';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/subscription/application/subscription_plans_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_purchase_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/subscription/domain/auto_renew_billing.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_plan.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_status.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/auto_renew_plan_sheet.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/tier_catalog.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

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

class _IdlePurchaseCtrl extends SubscriptionPurchaseCtrl {
  @override
  AsyncValue<void> build() => const AsyncData(null);
}

Widget _harness({
  required List<Override> overrides,
  required Widget child,
  TargetPlatform platform = TargetPlatform.linux,
}) {
  debugDefaultTargetPlatformOverride = platform;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
  return ProviderScope(
    overrides: [
      subscriptionPurchaseCtrlProvider.overrideWith(_IdlePurchaseCtrl.new),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      home: child,
    ),
  );
}

/// A scaffold with a button that opens the unified purchase sheet at the
/// chosen [interval] (defaults to monthly).
class _SheetLauncher extends StatelessWidget {
  // ignore: unused_element_parameter
  const _SheetLauncher({this.interval = CatalogInterval.month});

  final CatalogInterval interval;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showUnifiedPurchaseSheet(
            context,
            tier: SubscriptionTier.pro,
            interval: interval,
          ),
          child: const Text('Open Sheet'),
        ),
      ),
    );
  }
}

void _resetPlatform() {
  debugDefaultTargetPlatformOverride = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnifiedPurchaseSheet', () {
    testWidgets('shows unified title and both payment options', (tester) async {
      await tester.pumpWidget(
        _harness(
          overrides: [
            subscriptionPlansProvider.overrideWith((ref) async => _testPlans),
            subscriptionStatusProvider.overrideWith(
              (ref) async => const SubscriptionStatus(
                subscriptionActive: false,
                subscriptionTier: SubscriptionTier.free,
              ),
            ),
          ],
          child: const _SheetLauncher(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));

      // Unified modal title includes tier + interval label.
      expect(
        find.text(
          l10n.subscriptionPurchaseModalUnifiedTitle(
            l10n.subscriptionTierProName,
            l10n.subscriptionAutoRenewMonthly,
          ),
        ),
        findsOneWidget,
      );

      // Both options are visible.
      expect(
        find.text(l10n.subscriptionPurchaseModalOptionAutoRenew),
        findsOneWidget,
      );
      expect(
        find.text(l10n.subscriptionPurchaseModalOptionPrepaid),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
      _resetPlatform();
    });

    testWidgets('auto-renew is the default-selected path with CTA visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          overrides: [
            subscriptionPlansProvider.overrideWith((ref) async => _testPlans),
            subscriptionStatusProvider.overrideWith(
              (ref) async => const SubscriptionStatus(
                subscriptionActive: false,
                subscriptionTier: SubscriptionTier.free,
              ),
            ),
          ],
          child: const _SheetLauncher(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));

      // The auto-renew CTA is rendered (default path).
      expect(
        find.text(l10n.subscriptionPurchaseModalSubscribeAutoRenewCta),
        findsOneWidget,
      );

      // Pay-once controls are NOT rendered yet (duration / processor live in
      // the prepaid panel which is collapsed by default).
      expect(find.text(l10n.subscriptionPurchaseDuration), findsNothing);

      expect(tester.takeException(), isNull);
      _resetPlatform();
    });

    testWidgets(
      'switching to pay-once reveals prepaid duration + processor controls',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            overrides: [
              subscriptionPlansProvider.overrideWith((ref) async => _testPlans),
              subscriptionStatusProvider.overrideWith(
                (ref) async => const SubscriptionStatus(
                  subscriptionActive: false,
                  subscriptionTier: SubscriptionTier.free,
                ),
              ),
            ],
            child: const _SheetLauncher(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));

        // Tap the prepaid card to switch paths.
        await tester.tap(
          find.text(l10n.subscriptionPurchaseModalOptionPrepaid),
        );
        await tester.pumpAndSettle();

        // Prepaid panel content is now visible.
        expect(find.text(l10n.subscriptionPurchaseDuration), findsOneWidget);
        expect(
          find.text(l10n.subscriptionPurchasePaymentMethod),
          findsOneWidget,
        );
        expect(find.text(l10n.subscriptionContinueToPayment), findsOneWidget);

        expect(tester.takeException(), isNull);
        _resetPlatform();
      },
    );

    testWidgets(
      'shows active auto-renew warning + disables auto-renew CTA when active',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            overrides: [
              subscriptionPlansProvider.overrideWith((ref) async => _testPlans),
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
                  ),
                ),
              ),
            ],
            child: const _SheetLauncher(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));

        // Warning is shown.
        expect(
          find.text(l10n.subscriptionPurchaseModalAutoRenewActiveWarning),
          findsOneWidget,
        );

        // Auto-renew CTA is rendered but disabled.
        final cta = find.text(
          l10n.subscriptionPurchaseModalSubscribeAutoRenewCta,
        );
        expect(cta, findsOneWidget);
        final widget = tester.widget<FilledButton>(
          find.ancestor(of: cta, matching: find.byType(FilledButton)).first,
        );
        expect(widget.onPressed, isNull);

        expect(tester.takeException(), isNull);
        _resetPlatform();
      },
    );

    testWidgets('shows loading indicator while plans load', (tester) async {
      final completer = Completer<List<SubscriptionPlan>>();
      addTearDown(() {
        if (!completer.isCompleted) completer.complete(_testPlans);
      });

      await tester.pumpWidget(
        _harness(
          overrides: [
            subscriptionPlansProvider.overrideWith((ref) => completer.future),
            subscriptionStatusProvider.overrideWith(
              (ref) async => const SubscriptionStatus(
                subscriptionActive: false,
                subscriptionTier: SubscriptionTier.free,
              ),
            ),
          ],
          child: const _SheetLauncher(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pump();

      // Either the option-card skeleton or a CircularProgressIndicator shows.
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      expect(tester.takeException(), isNull);
      _resetPlatform();
    });

    testWidgets('shows unavailable message when plans list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          overrides: [
            subscriptionPlansProvider.overrideWith(
              (ref) async => const <SubscriptionPlan>[],
            ),
            subscriptionStatusProvider.overrideWith(
              (ref) async => const SubscriptionStatus(
                subscriptionActive: false,
                subscriptionTier: SubscriptionTier.free,
              ),
            ),
          ],
          child: const _SheetLauncher(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(l10n.subscriptionAutoRenewPlansUnavailable),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
      _resetPlatform();
    });

    testWidgets(
      'auto-renew falls back to a skeleton when no matching plan is loaded',
      (tester) async {
        // Only a yearly pro plan exists, so opening the sheet at the monthly
        // interval forces the no-plan-for-this-interval path. The UI must
        // show a skeleton, never a hardcoded fallback price.
        const yearlyOnly = [
          SubscriptionPlan(
            id: 'plan_yearly',
            tier: 'pro',
            interval: 'year',
            amount: 79.99,
          ),
        ];
        await tester.pumpWidget(
          _harness(
            overrides: [
              subscriptionPlansProvider.overrideWith((ref) async => yearlyOnly),
              subscriptionStatusProvider.overrideWith(
                (ref) async => const SubscriptionStatus(
                  subscriptionActive: false,
                  subscriptionTier: SubscriptionTier.free,
                ),
              ),
            ],
            child: const _SheetLauncher(interval: CatalogInterval.month),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // When the selected plan is missing, the auto-renew CTA is rendered
        // but disabled (so the user cannot proceed with a stale price).
        final l10n = lookupAppLocalizations(const Locale('en'));
        final cta = find.text(l10n.subscriptionPurchaseModalSubscribeAutoRenewCta);
        expect(cta, findsOneWidget);
        final widget = tester.widget<FilledButton>(
          find.ancestor(of: cta, matching: find.byType(FilledButton)).first,
        );
        expect(widget.onPressed, isNull);

        // No hardcoded fallback price is rendered.
        expect(
          find.text(l10n.subscriptionAutoRenewPriceMonth('9.99')),
          findsNothing,
        );
        expect(
          find.text(l10n.subscriptionAutoRenewPriceMonth('99.99')),
          findsNothing,
        );

        expect(tester.takeException(), isNull);
        _resetPlatform();
      },
    );

    testWidgets(
      'mobile platform surfaces coming-soon dialog instead of sheet',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            platform: TargetPlatform.iOS,
            overrides: [
              subscriptionPlansProvider.overrideWith((ref) async => _testPlans),
              subscriptionStatusProvider.overrideWith(
                (ref) async => const SubscriptionStatus(
                  subscriptionActive: false,
                  subscriptionTier: SubscriptionTier.free,
                ),
              ),
            ],
            child: const _SheetLauncher(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.subscriptionMobilePurchaseTitle), findsOneWidget);
        expect(
          find.text(
            l10n.subscriptionPurchaseModalUnifiedTitle(
              l10n.subscriptionTierProName,
              l10n.subscriptionAutoRenewMonthly,
            ),
          ),
          findsNothing,
        );

        _resetPlatform();
      },
    );
  });
}
