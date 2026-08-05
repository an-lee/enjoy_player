/// REST client for Enjoy subscription endpoints.
library;

import 'package:enjoy_player/data/api/rest_api.dart';
import 'package:enjoy_player/features/subscription/domain/payment_processor.dart';

class SubscriptionApi extends RestApi {
  SubscriptionApi(super.client);

  static const _path = '/api/v1/subscriptions';

  Future<Map<String, dynamic>> getStatus() => client.getJson(_path);

  Future<Map<String, dynamic>> listPlans() => client.getJson('$_path/plans');

  Future<Map<String, dynamic>> purchase({
    required int months,
    PaymentProcessor processor = PaymentProcessor.stripe,
    required String tier,
  }) => client.postJson(
    _path,
    body: {'months': months, 'processor': processor.apiValue, 'tier': tier},
  );

  Future<Map<String, dynamic>> startAutoRenew({required String planId}) =>
      client.postJson('$_path/auto_renew', body: {'planId': planId});

  Future<Map<String, dynamic>> cancelAutoRenew() =>
      client.postJson('$_path/cancel');
}
