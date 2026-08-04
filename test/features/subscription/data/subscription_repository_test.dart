import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/data/api/services/subscription_api.dart';
import 'package:enjoy_player/features/subscription/data/subscription_repository.dart';
import 'package:enjoy_player/features/subscription/domain/payment_processor.dart';
import 'package:enjoy_player/features/subscription/domain/purchase_request.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSubscriptionApi implements SubscriptionApi {
  _FakeSubscriptionApi(this._handler);

  final Future<Map<String, dynamic>> Function(String method) _handler;

  @override
  ApiClient get client => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getStatus() => _handler('getStatus');

  @override
  Future<Map<String, dynamic>> listPlans() => _handler('listPlans');

  @override
  Future<Map<String, dynamic>> purchase({
    required int months,
    PaymentProcessor processor = PaymentProcessor.stripe,
    required String tier,
  }) => _handler('purchase');

  @override
  Future<Map<String, dynamic>> startAutoRenew({required String planId}) =>
      _handler('startAutoRenew');

  @override
  Future<Map<String, dynamic>> cancelAutoRenew() => _handler('cancelAutoRenew');
}

void main() {
  group('SubscriptionRepository', () {
    test('getStatus returns parsed model with autoRenew', () async {
      final repo = SubscriptionRepository(
        _FakeSubscriptionApi((_) async {
          return {
            'subscriptionActive': true,
            'subscriptionTier': 'pro',
            'subscriptionExpireDate': null,
            'autoRenew': {
              'active': true,
              'provider': 'stripe',
              'status': 'active',
              'autoRenew': true,
              'cancelAtPeriodEnd': false,
              'planId': 'pro_month',
              'tier': 'pro',
              'interval': 'month',
              'amount': 9.99,
            },
          };
        }),
      );

      final status = await repo.getStatus();
      expect(status.isPro, isTrue);
      expect(status.autoRenew?.interval, 'month');
      expect(status.autoRenew?.isCancelable, isTrue);
    });

    test('listPlans parses catalog', () async {
      final repo = SubscriptionRepository(
        _FakeSubscriptionApi((method) async {
          expect(method, 'listPlans');
          return {
            'plans': [
              {
                'id': 'pro_month',
                'tier': 'pro',
                'interval': 'month',
                'amount': 9.99,
              },
            ],
          };
        }),
      );
      final plans = await repo.listPlans();
      expect(plans, hasLength(1));
      expect(plans.first.id, 'pro_month');
    });

    test('purchase returns payment session with payUrl', () async {
      final repo = SubscriptionRepository(
        _FakeSubscriptionApi((method) async {
          expect(method, 'purchase');
          return {
            'id': 'p1',
            'paymentType': 'subscription',
            'processor': 'stripe',
            'status': 'pending',
            'payUrl': 'https://pay.example.com',
            'createdAt': '2026-06-30T00:00:00.000Z',
          };
        }),
      );

      final session = await repo.purchase(
        const PurchaseRequest(
          months: 1,
          processor: PaymentProcessor.stripe,
          tier: 'pro',
        ),
      );
      expect(session.payUrl, 'https://pay.example.com');
    });

    test('startAutoRenew maps 409 to SubscriptionConflictFailure', () async {
      final repo = SubscriptionRepository(
        _ThrowingApi(const ApiException(message: 'conflict', statusCode: 409)),
      );
      expect(
        () => repo.startAutoRenew(planId: 'pro_month'),
        throwsA(isA<SubscriptionConflictFailure>()),
      );
    });

    test('maps 402 to CreditsFailure', () async {
      final repo = SubscriptionRepository(
        _ThrowingApi(const ApiException(message: 'limit', statusCode: 402)),
      );

      expect(() => repo.getStatus(), throwsA(isA<CreditsFailure>()));
    });
  });
}

class _ThrowingApi implements SubscriptionApi {
  _ThrowingApi(this.error);

  final ApiException error;

  @override
  ApiClient get client => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getStatus() => throw error;

  @override
  Future<Map<String, dynamic>> listPlans() => throw error;

  @override
  Future<Map<String, dynamic>> purchase({
    required int months,
    PaymentProcessor processor = PaymentProcessor.stripe,
    required String tier,
  }) => throw error;

  @override
  Future<Map<String, dynamic>> startAutoRenew({required String planId}) =>
      throw error;

  @override
  Future<Map<String, dynamic>> cancelAutoRenew() => throw error;
}
