/// Orchestrates subscription API calls and maps failures to [AppFailure].
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/data/api/rest_repository.dart';
import 'package:enjoy_player/data/api/services/subscription_api.dart';
import 'package:enjoy_player/data/api/services/api_providers.dart';
import 'package:enjoy_player/features/subscription/domain/auto_renew_billing.dart';
import 'package:enjoy_player/features/subscription/domain/auto_renew_start_result.dart';
import 'package:enjoy_player/features/subscription/domain/payment_session.dart';
import 'package:enjoy_player/features/subscription/domain/purchase_request.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_plan.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_status.dart';

part 'subscription_repository.g.dart';

@Riverpod(keepAlive: true)
SubscriptionRepository subscriptionRepository(Ref ref) {
  return SubscriptionRepository(ref.watch(subscriptionApiProvider));
}

class SubscriptionRepository with RestRepository {
  SubscriptionRepository(this._api);

  final SubscriptionApi _api;

  Future<SubscriptionStatus> getStatus() =>
      apiCall(() async => SubscriptionStatus.fromJson(await _api.getStatus()));

  Future<List<SubscriptionPlan>> listPlans() => apiCall(
    () async => parseJsonListField(
      await _api.listPlans(),
      'plans',
      SubscriptionPlan.fromJson,
    ),
  );

  Future<PaymentSession> purchase(PurchaseRequest request) => apiCall(
    () async => PaymentSession.fromJson(
      await _api.purchase(
        months: request.months,
        processor: request.processor,
        tier: request.tier,
      ),
    ),
  );

  Future<AutoRenewStartResult> startAutoRenew({required String planId}) =>
      apiCall(
        () async => AutoRenewStartResult.fromJson(
          await _api.startAutoRenew(planId: planId),
        ),
      );

  Future<AutoRenewBilling> cancelAutoRenew() => apiCall(() async {
    final json = await _api.cancelAutoRenew();
    // Cancel may return billing fields at top level or nested.
    final nested = json['autoRenew'];
    if (nested is Map) {
      return AutoRenewBilling.fromJson(Map<String, dynamic>.from(nested));
    }
    return AutoRenewBilling.fromJson(json);
  });

  @override
  AppFailure mapApiException(ApiException e) {
    if (e.statusCode == 402) {
      return CreditsFailure(e.message);
    }
    if (e.statusCode == 409) {
      return SubscriptionConflictFailure(e.message);
    }
    return NetworkFailure(e.message, statusCode: e.statusCode);
  }
}
