import 'package:enjoy_player/features/subscription/domain/auto_renew_billing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutoRenewBilling', () {
    test('fromJson parses full payload', () {
      final json = {
        'active': true,
        'provider': 'stripe',
        'status': 'active',
        'autoRenew': true,
        'currentPeriodEnd': '2025-12-31T00:00:00Z',
        'cancelAtPeriodEnd': false,
        'payUrl': 'https://pay.example.com',
        'planId': 'plan_123',
        'tier': 'pro',
        'interval': 'monthly',
        'amount': 9.99,
      };
      final b = AutoRenewBilling.fromJson(json);
      expect(b.active, isTrue);
      expect(b.provider, 'stripe');
      expect(b.status, 'active');
      expect(b.autoRenew, isTrue);
      expect(b.currentPeriodEnd, '2025-12-31T00:00:00Z');
      expect(b.cancelAtPeriodEnd, isFalse);
      expect(b.payUrl, 'https://pay.example.com');
      expect(b.planId, 'plan_123');
      expect(b.tier, 'pro');
      expect(b.interval, 'monthly');
      expect(b.amount, 9.99);
    });

    test('fromJson handles missing/null optional fields', () {
      final json = <String, dynamic>{
        'active': false,
        'autoRenew': false,
        'cancelAtPeriodEnd': true,
      };
      final b = AutoRenewBilling.fromJson(json);
      expect(b.active, isFalse);
      expect(b.provider, '');
      expect(b.status, '');
      expect(b.autoRenew, isFalse);
      expect(b.currentPeriodEnd, isNull);
      expect(b.cancelAtPeriodEnd, isTrue);
      expect(b.payUrl, isNull);
      expect(b.planId, isNull);
      expect(b.tier, 'pro'); // default
      expect(b.interval, '');
      expect(b.amount, isNull);
    });

    test('toJson round-trips correctly', () {
      final original = AutoRenewBilling(
        active: true,
        provider: 'stripe',
        status: 'active',
        autoRenew: true,
        currentPeriodEnd: '2025-06-01',
        cancelAtPeriodEnd: false,
        payUrl: 'https://pay.stripe.com',
        planId: 'plan_abc',
        tier: 'pro',
        interval: 'yearly',
        amount: 99,
      );
      final json = original.toJson();
      final restored = AutoRenewBilling.fromJson(json);
      expect(restored.active, original.active);
      expect(restored.provider, original.provider);
      expect(restored.status, original.status);
      expect(restored.autoRenew, original.autoRenew);
      expect(restored.currentPeriodEnd, original.currentPeriodEnd);
      expect(restored.cancelAtPeriodEnd, original.cancelAtPeriodEnd);
      expect(restored.payUrl, original.payUrl);
      expect(restored.planId, original.planId);
      expect(restored.tier, original.tier);
      expect(restored.interval, original.interval);
      expect(restored.amount, original.amount);
    });

    test('toJson omits null optional fields', () {
      final b = AutoRenewBilling(
        active: false,
        provider: 'apple',
        status: 'ended',
        autoRenew: false,
        cancelAtPeriodEnd: false,
        tier: 'pro',
        interval: 'monthly',
      );
      final json = b.toJson();
      expect(json.containsKey('currentPeriodEnd'), isFalse);
      expect(json.containsKey('payUrl'), isFalse);
      expect(json.containsKey('planId'), isFalse);
      expect(json.containsKey('amount'), isFalse);
    });

    group('isCancelable', () {
      test(
        'true when autoRenew and not cancelAtPeriodEnd and active status',
        () {
          final b = AutoRenewBilling(
            active: true,
            provider: 'stripe',
            status: 'active',
            autoRenew: true,
            cancelAtPeriodEnd: false,
            tier: 'pro',
            interval: 'monthly',
          );
          expect(b.isCancelable, isTrue);
        },
      );

      test('false when already cancelAtPeriodEnd', () {
        final b = AutoRenewBilling(
          active: true,
          provider: 'stripe',
          status: 'active',
          autoRenew: true,
          cancelAtPeriodEnd: true,
          tier: 'pro',
          interval: 'monthly',
        );
        expect(b.isCancelable, isFalse);
      });

      test('false when status is ended', () {
        final b = AutoRenewBilling(
          active: false,
          provider: 'stripe',
          status: 'ended',
          autoRenew: true,
          cancelAtPeriodEnd: false,
          tier: 'pro',
          interval: 'monthly',
        );
        expect(b.isCancelable, isFalse);
      });

      test('false when status is canceled', () {
        final b = AutoRenewBilling(
          active: false,
          provider: 'stripe',
          status: 'canceled',
          autoRenew: true,
          cancelAtPeriodEnd: false,
          tier: 'pro',
          interval: 'monthly',
        );
        expect(b.isCancelable, isFalse);
      });

      test('false when autoRenew is false', () {
        final b = AutoRenewBilling(
          active: true,
          provider: 'stripe',
          status: 'active',
          autoRenew: false,
          cancelAtPeriodEnd: false,
          tier: 'pro',
          interval: 'monthly',
        );
        expect(b.isCancelable, isFalse);
      });
    });

    group('isActivelyRenewing', () {
      test('true when active + autoRenew + not canceling + active status', () {
        final b = AutoRenewBilling(
          active: true,
          provider: 'stripe',
          status: 'active',
          autoRenew: true,
          cancelAtPeriodEnd: false,
          tier: 'pro',
          interval: 'monthly',
        );
        expect(b.isActivelyRenewing, isTrue);
      });

      test('false when not active', () {
        final b = AutoRenewBilling(
          active: false,
          provider: 'stripe',
          status: 'active',
          autoRenew: true,
          cancelAtPeriodEnd: false,
          tier: 'pro',
          interval: 'monthly',
        );
        expect(b.isActivelyRenewing, isFalse);
      });

      test('false when cancelAtPeriodEnd', () {
        final b = AutoRenewBilling(
          active: true,
          provider: 'stripe',
          status: 'active',
          autoRenew: true,
          cancelAtPeriodEnd: true,
          tier: 'pro',
          interval: 'monthly',
        );
        expect(b.isActivelyRenewing, isFalse);
      });
    });

    group('isIncomplete', () {
      test('true when status is incomplete', () {
        final b = AutoRenewBilling(
          active: false,
          provider: 'stripe',
          status: 'incomplete',
          autoRenew: false,
          cancelAtPeriodEnd: false,
          tier: 'pro',
          interval: 'monthly',
        );
        expect(b.isIncomplete, isTrue);
      });

      test('false for other statuses', () {
        final b = AutoRenewBilling(
          active: true,
          provider: 'stripe',
          status: 'active',
          autoRenew: true,
          cancelAtPeriodEnd: false,
          tier: 'pro',
          interval: 'monthly',
        );
        expect(b.isIncomplete, isFalse);
      });
    });
  });
}
