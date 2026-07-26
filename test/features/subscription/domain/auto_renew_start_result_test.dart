import 'package:enjoy_player/features/subscription/domain/auto_renew_start_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutoRenewStartResult.fromJson', () {
    test('reads top-level scalars and defaults', () {
      final result = AutoRenewStartResult.fromJson({
        'id': 42,
        'provider': 'stripe',
        'status': 'pending',
        'autoRenew': true,
        'payUrl': 'https://stripe.example/checkout',
        'currentPeriodEnd': '2026-12-31T00:00:00Z',
        'planId': 7,
      });
      expect(result.id, '42');
      expect(result.provider, 'stripe');
      expect(result.status, 'pending');
      expect(result.autoRenew, isTrue);
      expect(result.payUrl, 'https://stripe.example/checkout');
      expect(result.currentPeriodEnd, '2026-12-31T00:00:00Z');
      expect(result.planId, '7');
      // tier defaults to 'pro' when missing.
      expect(result.tier, 'pro');
      expect(result.interval, isEmpty);
      expect(result.priceAmount, isNull);
      expect(result.priceInterval, isNull);
      expect(result.currencyNote, isNull);
    });

    test('flattens price.amount / price.interval / price.currencyNote', () {
      final result = AutoRenewStartResult.fromJson({
        'id': 'sub_123',
        'provider': 'mixin',
        'status': 'succeeded',
        'autoRenew': false,
        'price': {
          'amount': '12.50',
          'interval': 'month',
          'currencyNote': 'USD',
        },
        'amount': 'ignored-when-price-set',
        'tier': 'pro_plus',
        'interval': 'year',
      });
      // price sub-map wins over top-level 'amount'.
      expect(result.priceAmount, 12.50);
      expect(result.priceInterval, 'month');
      expect(result.currencyNote, 'USD');
      expect(result.tier, 'pro_plus');
      expect(result.interval, 'year');
    });

    test('top-level amount fallback when price is absent', () {
      final result = AutoRenewStartResult.fromJson({
        'id': 'sub_x',
        'provider': 'stripe',
        'status': 'pending',
        'autoRenew': false,
        'amount': 7,
      });
      expect(result.priceAmount, 7);
    });

    test('autoRenew must be exactly true to flip the flag', () {
      final result = AutoRenewStartResult.fromJson({
        'id': 'sub',
        'provider': 'stripe',
        'status': 'pending',
        'autoRenew': 'true', // string → not true
      });
      expect(result.autoRenew, isFalse);
    });
  });
}
