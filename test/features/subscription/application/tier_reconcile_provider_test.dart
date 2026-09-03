import 'dart:async';

import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/credits/application/credits_summary_provider.dart';
import 'package:enjoy_player/features/credits/domain/credits_summary.dart';
import 'package:enjoy_player/features/subscription/application/current_tier_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/subscription/application/tier_reconcile_provider.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _freeProfile = UserProfile(
  id: 'u1',
  email: 'a@b.com',
  name: 'Free',
  subscriptionTier: SubscriptionTier.free,
);
const _proStatus = SubscriptionStatus(
  subscriptionActive: true,
  subscriptionTier: SubscriptionTier.pro,
);
const _liteStatus = SubscriptionStatus(
  subscriptionActive: true,
  subscriptionTier: SubscriptionTier.lite,
);
const _freeStatus = SubscriptionStatus(
  subscriptionActive: true,
  subscriptionTier: SubscriptionTier.free,
);

CreditsSummary _summary({required int permanent}) => CreditsSummary(
  tier: 'free',
  dailyUsed: 0,
  dailyLimit: 1000,
  dailyRemaining: 1000,
  permanentAvailable: permanent,
  resetAt: 0,
);

/// Signed-in auth whose [AuthCtrl.refreshProfile] is a no-op recording stub,
/// so reconcile can be exercised without a real network/repository.
class _RecordingAuthCtrl extends AuthCtrl {
  int refreshCalls = 0;

  @override
  Future<AuthState> build() async => const AuthSignedIn(profile: _freeProfile);

  @override
  Future<void> refreshProfile() async {
    refreshCalls++;
  }
}

class _SignedOutAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reconcile is a no-op when signed out (status never fetched)', () async {
    var statusCalls = 0;
    final container = ProviderContainer(
      overrides: [
        authCtrlProvider.overrideWith(_SignedOutAuthCtrl.new),
        subscriptionStatusProvider.overrideWith((ref) async {
          statusCalls++;
          return _proStatus;
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authCtrlProvider.future);

    await container.read(tierReconcileCtrlProvider.notifier).reconcile();

    expect(statusCalls, 0);
  });

  test(
    'non-eager reconcile refreshes profile + status + credits when signed in',
    () async {
      var statusCalls = 0;
      var summaryCalls = 0;
      final container = ProviderContainer(
        overrides: [
          authCtrlProvider.overrideWith(_RecordingAuthCtrl.new),
          subscriptionStatusProvider.overrideWith((ref) async {
            statusCalls++;
            return _proStatus;
          }),
          creditsSummaryProvider.overrideWith((ref) async {
            summaryCalls++;
            return _summary(permanent: 0);
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);
      final authNotifier =
          container.read(authCtrlProvider.notifier) as _RecordingAuthCtrl;

      final result = await container
          .read(tierReconcileCtrlProvider.notifier)
          .reconcile();

      expect(result, isTrue);
      expect(authNotifier.refreshCalls, 1);
      expect(statusCalls, greaterThanOrEqualTo(1));
      expect(summaryCalls, greaterThanOrEqualTo(1));
    },
  );

  test('non-eager reconcile debounces rapid re-runs', () async {
    final container = ProviderContainer(
      overrides: [
        authCtrlProvider.overrideWith(_RecordingAuthCtrl.new),
        subscriptionStatusProvider.overrideWith((ref) async => _proStatus),
        creditsSummaryProvider.overrideWith(
          (ref) async => _summary(permanent: 0),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authCtrlProvider.future);
    final authNotifier =
        container.read(authCtrlProvider.notifier) as _RecordingAuthCtrl;
    final notifier = container.read(tierReconcileCtrlProvider.notifier);

    expect(await notifier.reconcile(), isTrue);
    expect(await notifier.reconcile(), isNull);

    expect(authNotifier.refreshCalls, 1);
  });

  test('markPurchasePending toggles hasPendingPurchase', () {
    final container = ProviderContainer(
      overrides: [
        authCtrlProvider.overrideWith(_RecordingAuthCtrl.new),
        subscriptionStatusProvider.overrideWith((ref) async => _proStatus),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(tierReconcileCtrlProvider.notifier);

    expect(notifier.hasPendingPurchase, isFalse);
    notifier.markPurchasePending();
    expect(notifier.hasPendingPurchase, isTrue);
  });

  test(
    'eager reconcile polls until paid and clears the pending flag',
    () async {
      var statusCalls = 0;
      final container = ProviderContainer(
        overrides: [
          authCtrlProvider.overrideWith(_RecordingAuthCtrl.new),
          subscriptionStatusProvider.overrideWith((ref) async {
            statusCalls++;
            return statusCalls >= 2 ? _proStatus : _freeStatus;
          }),
          creditsSummaryProvider.overrideWith(
            (ref) async => _summary(permanent: 0),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);
      final authNotifier =
          container.read(authCtrlProvider.notifier) as _RecordingAuthCtrl;
      final notifier = container.read(tierReconcileCtrlProvider.notifier);

      notifier.markPurchasePending();
      expect(await notifier.reconcile(eager: true), isTrue);

      expect(container.read(currentTierProvider), SubscriptionTier.pro);
      expect(authNotifier.refreshCalls, greaterThanOrEqualTo(1));
      expect(notifier.hasPendingPurchase, isFalse);
    },
  );

  test('eager reconcile also confirms Lite as a paid tier', () async {
    var statusCalls = 0;
    final container = ProviderContainer(
      overrides: [
        authCtrlProvider.overrideWith(_RecordingAuthCtrl.new),
        subscriptionStatusProvider.overrideWith((ref) async {
          statusCalls++;
          return statusCalls >= 2 ? _liteStatus : _freeStatus;
        }),
        creditsSummaryProvider.overrideWith(
          (ref) async => _summary(permanent: 0),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authCtrlProvider.future);
    final notifier = container.read(tierReconcileCtrlProvider.notifier);

    notifier.markPurchasePending();
    expect(await notifier.reconcile(eager: true), isTrue);

    expect(container.read(currentTierProvider), SubscriptionTier.lite);
    expect(notifier.hasPendingPurchase, isFalse);
  });

  test('eager package reconcile confirms from pre-checkout baseline', () async {
    var summaryCalls = 0;
    final container = ProviderContainer(
      overrides: [
        authCtrlProvider.overrideWith(_RecordingAuthCtrl.new),
        subscriptionStatusProvider.overrideWith((ref) async => _freeStatus),
        creditsSummaryProvider.overrideWith((ref) async {
          summaryCalls++;
          // First poll already includes the grant relative to baseline 100.
          return _summary(permanent: summaryCalls >= 1 ? 300 : 100);
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authCtrlProvider.future);
    final notifier = container.read(tierReconcileCtrlProvider.notifier);

    notifier.markPackagePurchasePending(
      packageId: 'pkg-test',
      expectedCredits: 200,
      baselinePermanent: 100,
    );
    expect(await notifier.reconcile(eager: true), isTrue);
    expect(notifier.hasPendingPackagePurchase, isFalse);
  });

  test(
    'eager package reconcile without baseline uses consecutive growth only',
    () async {
      var summaryCalls = 0;
      final container = ProviderContainer(
        overrides: [
          authCtrlProvider.overrideWith(_RecordingAuthCtrl.new),
          subscriptionStatusProvider.overrideWith((ref) async => _freeStatus),
          creditsSummaryProvider.overrideWith((ref) async {
            summaryCalls++;
            // First sample is pre-grant; second includes the package.
            return _summary(permanent: summaryCalls >= 2 ? 300 : 100);
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);
      final notifier = container.read(tierReconcileCtrlProvider.notifier);

      notifier.markPackagePurchasePending(
        packageId: 'pkg-test',
        expectedCredits: 200,
        baselinePermanent: null,
      );
      expect(await notifier.reconcile(eager: true), isTrue);
    },
  );

  test(
    'concurrent non-eager reconcile returns null instead of false',
    () async {
      final started = <Completer<CreditsSummary>>[];
      final container = ProviderContainer(
        overrides: [
          authCtrlProvider.overrideWith(_RecordingAuthCtrl.new),
          subscriptionStatusProvider.overrideWith((ref) async => _proStatus),
          creditsSummaryProvider.overrideWith((ref) {
            final c = Completer<CreditsSummary>();
            started.add(c);
            return c.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authCtrlProvider.future);
      final notifier = container.read(tierReconcileCtrlProvider.notifier);

      final first = notifier.reconcile();
      // Allow the first reconcile to take the lock and hit credits fetch.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(started, isNotEmpty);

      final second = await notifier.reconcile();
      expect(second, isNull);

      started.first.complete(_summary(permanent: 0));
      expect(await first, isTrue);
    },
  );
}
