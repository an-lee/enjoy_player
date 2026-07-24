/// Catalog row from `GET /api/v1/subscriptions/plans`.
library;

import 'package:enjoy_player/core/json/json_cast.dart';

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.tier,
    required this.interval,
    required this.amount,
    this.currencyNote,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id']?.toString() ?? '',
      tier: json['tier']?.toString() ?? 'pro',
      interval: json['interval']?.toString() ?? '',
      amount: numOrZero(json['amount']),
      currencyNote: json['currencyNote']?.toString(),
    );
  }

  final String id;
  final String tier;
  final String interval;
  final num amount;
  final String? currencyNote;

  bool get isMonthly => interval == 'month';
  bool get isYearly => interval == 'year';

  Map<String, dynamic> toJson() => {
    'id': id,
    'tier': tier,
    'interval': interval,
    'amount': amount,
    if (currencyNote != null) 'currencyNote': currencyNote,
  };
}
