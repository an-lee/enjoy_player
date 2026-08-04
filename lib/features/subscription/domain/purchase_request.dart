/// Desktop subscription purchase parameters.
library;

import 'package:enjoy_player/features/subscription/domain/payment_processor.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_plan.dart';

class PurchaseRequest {
  const PurchaseRequest({
    required this.months,
    required this.processor,
    required this.tier,
  });

  final int months;
  final PaymentProcessor processor;
  final String tier;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'months': months,
      'processor': processor.apiValue,
      'tier': tier,
    };
  }
}

/// Monthly plan amount for a tier from the loaded catalog.
///
/// Returns `null` when [plans] is empty or the tier has no monthly plan —
/// callers should treat that as a loading state (disable CTAs, show skeleton)
/// rather than a fallback price. The Rails API is the single source of truth
/// for tier pricing (`GET /api/v1/subscriptions/plans`).
double? prepaidUnitPriceForTier(List<SubscriptionPlan> plans, String tier) {
  for (final plan in plans) {
    if (plan.tier == tier && plan.isMonthly) {
      return plan.amount.toDouble();
    }
  }
  return null;
}
