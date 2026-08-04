import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/subscription_api.dart';
import 'package:enjoy_player/features/subscription/application/subscription_purchase_provider.dart';
import 'package:enjoy_player/features/subscription/application/tier_reconcile_provider.dart';
import 'package:enjoy_player/features/subscription/data/subscription_repository.dart';
import 'package:enjoy_player/features/subscription/domain/auto_renew_billing.dart';
import 'package:enjoy_player/features/subscription/domain/auto_renew_start_result.dart';
import 'package:enjoy_player/features/subscription/domain/payment_processor.dart';
import 'package:enjoy_player/features/subscription/domain/payment_session.dart';
import 'package:enjoy_player/features/subscription/domain/purchase_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  _FakeUrlLauncherPlatform({this.launchResult = true});

  final bool launchResult;
  String? lastLaunchedUrl;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastLaunchedUrl = url;
    return launchResult;
  }

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<void> closeWebView() async {}

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => false;
}

ApiClient _testApiClient() => ApiClient(
  httpClient: http.Client(),
  getBaseUrl: () async => 'https://enjoy.bot',
  getAccessToken: () async => null,
);

class _FakeSubscriptionRepository extends SubscriptionRepository {
  _FakeSubscriptionRepository({
    this.purchaseResult,
    this.purchaseError,
    this.startAutoRenewResult,
    this.startAutoRenewError,
    this.cancelAutoRenewError,
  }) : super(SubscriptionApi(_testApiClient()));

  final PaymentSession? purchaseResult;
  final Object? purchaseError;
  final AutoRenewStartResult? startAutoRenewResult;
  final Object? startAutoRenewError;
  final Object? cancelAutoRenewError;

  int purchaseCalls = 0;
  int startAutoRenewCalls = 0;
  int cancelAutoRenewCalls = 0;
  PurchaseRequest? lastPurchaseRequest;
  String? lastAutoRenewPlanId;

  @override
  Future<PaymentSession> purchase(PurchaseRequest request) async {
    purchaseCalls++;
    lastPurchaseRequest = request;
    if (purchaseError != null) throw purchaseError!;
    return purchaseResult!;
  }

  @override
  Future<AutoRenewStartResult> startAutoRenew({required String planId}) async {
    startAutoRenewCalls++;
    lastAutoRenewPlanId = planId;
    if (startAutoRenewError != null) throw startAutoRenewError!;
    return startAutoRenewResult!;
  }

  @override
  Future<AutoRenewBilling> cancelAutoRenew() async {
    cancelAutoRenewCalls++;
    if (cancelAutoRenewError != null) throw cancelAutoRenewError!;
    return const AutoRenewBilling(
      active: false,
      provider: 'stripe',
      status: 'canceled',
      autoRenew: false,
      cancelAtPeriodEnd: false,
      tier: 'free',
      interval: 'month',
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _validSession = PaymentSession(
  id: 'sess-1',
  paymentType: 'prepaid',
  processor: PaymentProcessor.stripe,
  status: PaymentStatus.pending,
  payUrl: 'https://pay.example.com/checkout/123',
  createdAt: '2025-01-01T00:00:00Z',
);

const _sessionNoUrl = PaymentSession(
  id: 'sess-2',
  paymentType: 'prepaid',
  processor: PaymentProcessor.stripe,
  status: PaymentStatus.pending,
  payUrl: null,
  createdAt: '2025-01-01T00:00:00Z',
);

const _sessionEmptyUrl = PaymentSession(
  id: 'sess-3',
  paymentType: 'prepaid',
  processor: PaymentProcessor.stripe,
  status: PaymentStatus.pending,
  payUrl: '',
  createdAt: '2025-01-01T00:00:00Z',
);

const _autoRenewResult = AutoRenewStartResult(
  id: 'ar-1',
  provider: 'stripe',
  status: 'active',
  autoRenew: true,
  payUrl: 'https://pay.example.com/auto-renew/456',
  tier: 'pro',
  interval: 'month',
);

const _autoRenewNoUrl = AutoRenewStartResult(
  id: 'ar-2',
  provider: 'stripe',
  status: 'active',
  autoRenew: true,
  payUrl: null,
  tier: 'pro',
  interval: 'month',
);

ProviderContainer _container({required _FakeSubscriptionRepository repo}) {
  return ProviderContainer(
    overrides: [subscriptionRepositoryProvider.overrideWithValue(repo)],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeUrlLauncherPlatform fakeUrlLauncher;

  setUp(() {
    fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
  });

  group('SubscriptionPurchaseCtrl.purchaseExternal', () {
    test('initial state is AsyncData(null)', () {
      final repo = _FakeSubscriptionRepository(purchaseResult: _validSession);
      final container = _container(repo: repo);
      addTearDown(container.dispose);

      final state = container.read(subscriptionPurchaseCtrlProvider);
      expect(state, const AsyncData<void>(null));
    });

    test('successful purchase launches URL and marks pending', () async {
      final repo = _FakeSubscriptionRepository(purchaseResult: _validSession);
      final container = _container(repo: repo);
      addTearDown(container.dispose);

      final result = await container
          .read(subscriptionPurchaseCtrlProvider.notifier)
          .purchaseExternal(
            months: 3,
            processor: PaymentProcessor.stripe,
            tier: 'pro',
          );

      expect(result, isNotNull);
      expect(result!.id, 'sess-1');
      expect(repo.purchaseCalls, 1);
      expect(repo.lastPurchaseRequest!.months, 3);
      expect(repo.lastPurchaseRequest!.processor, PaymentProcessor.stripe);
      expect(
        fakeUrlLauncher.lastLaunchedUrl,
        'https://pay.example.com/checkout/123',
      );

      // State returns to AsyncData after success.
      final state = container.read(subscriptionPurchaseCtrlProvider);
      expect(state, const AsyncData<void>(null));

      // Tier reconcile pending flag is set.
      final reconcile = container.read(tierReconcileCtrlProvider.notifier);
      expect(reconcile.hasPendingPurchase, isTrue);
    });

    test('throws StateError when payUrl is null', () async {
      final repo = _FakeSubscriptionRepository(purchaseResult: _sessionNoUrl);
      final container = _container(repo: repo);
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(subscriptionPurchaseCtrlProvider.notifier)
            .purchaseExternal(
              months: 1,
              processor: PaymentProcessor.mixin,
              tier: 'pro',
            ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'missing_pay_url',
          ),
        ),
      );

      // State is AsyncError after failure.
      final state = container.read(subscriptionPurchaseCtrlProvider);
      expect(state, isA<AsyncError<void>>());
    });

    test('throws StateError when payUrl is empty', () async {
      final repo = _FakeSubscriptionRepository(
        purchaseResult: _sessionEmptyUrl,
      );
      final container = _container(repo: repo);
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(subscriptionPurchaseCtrlProvider.notifier)
            .purchaseExternal(
              months: 1,
              processor: PaymentProcessor.stripe,
              tier: 'pro',
            ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'missing_pay_url',
          ),
        ),
      );
    });

    test('throws StateError when launch fails', () async {
      fakeUrlLauncher = _FakeUrlLauncherPlatform(launchResult: false);
      UrlLauncherPlatform.instance = fakeUrlLauncher;

      final repo = _FakeSubscriptionRepository(purchaseResult: _validSession);
      final container = _container(repo: repo);
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(subscriptionPurchaseCtrlProvider.notifier)
            .purchaseExternal(
              months: 1,
              processor: PaymentProcessor.stripe,
              tier: 'pro',
            ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'launch_failed',
          ),
        ),
      );

      final state = container.read(subscriptionPurchaseCtrlProvider);
      expect(state, isA<AsyncError<void>>());
    });

    test('propagates repository error and sets AsyncError', () async {
      final repo = _FakeSubscriptionRepository(
        purchaseError: StateError('network_down'),
      );
      final container = _container(repo: repo);
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(subscriptionPurchaseCtrlProvider.notifier)
            .purchaseExternal(
              months: 6,
              processor: PaymentProcessor.stripe,
              tier: 'pro',
            ),
        throwsA(isA<StateError>()),
      );

      final state = container.read(subscriptionPurchaseCtrlProvider);
      expect(state, isA<AsyncError<void>>());
      expect(repo.purchaseCalls, 1);
    });
  });

  group('SubscriptionPurchaseCtrl.startAutoRenewExternal', () {
    test('successful auto-renew launches URL and marks pending', () async {
      final repo = _FakeSubscriptionRepository(
        startAutoRenewResult: _autoRenewResult,
      );
      final container = _container(repo: repo);
      addTearDown(container.dispose);

      final result = await container
          .read(subscriptionPurchaseCtrlProvider.notifier)
          .startAutoRenewExternal(planId: 'plan-pro-monthly');

      expect(result, isNotNull);
      expect(result!.id, 'ar-1');
      expect(repo.startAutoRenewCalls, 1);
      expect(repo.lastAutoRenewPlanId, 'plan-pro-monthly');
      expect(
        fakeUrlLauncher.lastLaunchedUrl,
        'https://pay.example.com/auto-renew/456',
      );

      final reconcile = container.read(tierReconcileCtrlProvider.notifier);
      expect(reconcile.hasPendingPurchase, isTrue);
    });

    test('throws StateError when auto-renew payUrl is null', () async {
      final repo = _FakeSubscriptionRepository(
        startAutoRenewResult: _autoRenewNoUrl,
      );
      final container = _container(repo: repo);
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(subscriptionPurchaseCtrlProvider.notifier)
            .startAutoRenewExternal(planId: 'plan-x'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'missing_pay_url',
          ),
        ),
      );

      final state = container.read(subscriptionPurchaseCtrlProvider);
      expect(state, isA<AsyncError<void>>());
    });

    test('propagates repository error', () async {
      final repo = _FakeSubscriptionRepository(
        startAutoRenewError: StateError('api_error'),
      );
      final container = _container(repo: repo);
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(subscriptionPurchaseCtrlProvider.notifier)
            .startAutoRenewExternal(planId: 'plan-x'),
        throwsA(isA<StateError>()),
      );

      final state = container.read(subscriptionPurchaseCtrlProvider);
      expect(state, isA<AsyncError<void>>());
    });
  });

  group('SubscriptionPurchaseCtrl.cancelAutoRenew', () {
    test('successful cancel resets state to AsyncData', () async {
      final repo = _FakeSubscriptionRepository(
        startAutoRenewResult: _autoRenewResult,
      );
      final container = _container(repo: repo);
      addTearDown(container.dispose);

      await container
          .read(subscriptionPurchaseCtrlProvider.notifier)
          .cancelAutoRenew();

      expect(repo.cancelAutoRenewCalls, 1);
      final state = container.read(subscriptionPurchaseCtrlProvider);
      expect(state, const AsyncData<void>(null));
    });

    test('propagates cancel error and sets AsyncError', () async {
      final repo = _FakeSubscriptionRepository(
        cancelAutoRenewError: StateError('cancel_failed'),
      );
      final container = _container(repo: repo);
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(subscriptionPurchaseCtrlProvider.notifier)
            .cancelAutoRenew(),
        throwsA(isA<StateError>()),
      );

      final state = container.read(subscriptionPurchaseCtrlProvider);
      expect(state, isA<AsyncError<void>>());
    });
  });
}
