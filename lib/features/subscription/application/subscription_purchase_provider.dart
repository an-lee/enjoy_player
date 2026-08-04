/// External checkout mutations for Pro subscription (prepaid + auto-renew).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/utils/launch_pay_url.dart';
import 'package:enjoy_player/features/subscription/application/tier_reconcile_provider.dart';
import 'package:enjoy_player/features/subscription/data/subscription_repository.dart';
import 'package:enjoy_player/features/subscription/domain/auto_renew_start_result.dart';
import 'package:enjoy_player/features/subscription/domain/payment_processor.dart';
import 'package:enjoy_player/features/subscription/domain/payment_session.dart';
import 'package:enjoy_player/features/subscription/domain/purchase_request.dart';

part 'subscription_purchase_provider.g.dart';

@Riverpod(keepAlive: true)
class SubscriptionPurchaseCtrl extends _$SubscriptionPurchaseCtrl {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<PaymentSession?> purchaseExternal({
    required int months,
    required PaymentProcessor processor,
    required String tier,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final session = await repo.purchase(
        PurchaseRequest(months: months, processor: processor, tier: tier),
      );
      state = const AsyncData(null);
      await launchPayUrl(session.payUrl);
      ref.read(tierReconcileCtrlProvider.notifier).markPurchasePending();
      return session;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<AutoRenewStartResult?> startAutoRenewExternal({
    required String planId,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final result = await repo.startAutoRenew(planId: planId);
      state = const AsyncData(null);
      await launchPayUrl(result.payUrl);
      ref.read(tierReconcileCtrlProvider.notifier).markPurchasePending();
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> cancelAutoRenew() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.cancelAutoRenew();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
