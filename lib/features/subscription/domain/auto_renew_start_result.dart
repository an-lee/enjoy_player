/// Result of `POST /api/v1/subscriptions/auto_renew`.
library;

import 'package:enjoy_player/core/json/json_cast.dart';

class AutoRenewStartResult {
  const AutoRenewStartResult({
    required this.id,
    required this.provider,
    required this.status,
    required this.autoRenew,
    this.payUrl,
    this.currentPeriodEnd,
    this.planId,
    required this.tier,
    required this.interval,
    this.priceAmount,
    this.priceInterval,
    this.currencyNote,
  });

  factory AutoRenewStartResult.fromJson(Map<String, dynamic> json) {
    final price = json['price'];
    Map<String, dynamic>? priceMap;
    if (price is Map) {
      priceMap = Map<String, dynamic>.from(price);
    }
    return AutoRenewStartResult(
      id: json['id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      autoRenew: json['autoRenew'] == true,
      payUrl: json['payUrl'] as String?,
      currentPeriodEnd: json['currentPeriodEnd'] as String?,
      planId: json['planId']?.toString(),
      tier: json['tier']?.toString() ?? 'pro',
      interval: json['interval']?.toString() ?? '',
      priceAmount: numOrNull(priceMap?['amount'] ?? json['amount']),
      priceInterval: priceMap?['interval']?.toString(),
      currencyNote: priceMap?['currencyNote']?.toString(),
    );
  }

  final String id;
  final String provider;
  final String status;
  final bool autoRenew;
  final String? payUrl;
  final String? currentPeriodEnd;
  final String? planId;
  final String tier;
  final String interval;
  final num? priceAmount;
  final String? priceInterval;
  final String? currencyNote;
}
