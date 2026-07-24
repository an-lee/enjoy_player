/// One-time permanent-credit package from Rails `/api/v1/credits/packages`.
library;

import 'package:enjoy_player/core/json/json_cast.dart';

class CreditsTransferRate {
  const CreditsTransferRate({required this.usd, required this.credits});

  factory CreditsTransferRate.fromJson(Map<String, dynamic> json) {
    return CreditsTransferRate(
      usd: numOrZero(json['usd']),
      credits: intOrZero(json['credits']),
    );
  }

  final num usd;
  final int credits;
}

class CreditsPackage {
  const CreditsPackage({
    required this.id,
    required this.amount,
    required this.currency,
    required this.credits,
    required this.rate,
  });

  factory CreditsPackage.fromJson(Map<String, dynamic> json) {
    final rateRaw = json['rate'];
    final rateMap = rateRaw is Map
        ? Map<String, dynamic>.from(rateRaw)
        : <String, dynamic>{};
    return CreditsPackage(
      id: json['id']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'USD',
      credits: intOrZero(json['credits']),
      rate: CreditsTransferRate.fromJson(rateMap),
    );
  }

  final String id;
  final String amount;
  final String currency;
  final int credits;
  final CreditsTransferRate rate;
}

/// Pending checkout from `POST /api/v1/credits/packages/purchases`.
class CreditsPackagePurchaseSession {
  const CreditsPackagePurchaseSession({
    required this.id,
    required this.status,
    required this.paymentType,
    required this.amount,
    this.payUrl,
    required this.package,
  });

  factory CreditsPackagePurchaseSession.fromJson(Map<String, dynamic> json) {
    final packageRaw = json['package'];
    final packageMap = packageRaw is Map
        ? Map<String, dynamic>.from(packageRaw)
        : <String, dynamic>{};
    return CreditsPackagePurchaseSession(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      paymentType: json['paymentType']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
      payUrl: json['payUrl'] as String?,
      package: CreditsPackage.fromJson({
        ...packageMap,
        if (!packageMap.containsKey('rate'))
          'rate': {'usd': 1, 'credits': 100000},
      }),
    );
  }

  final String id;
  final String status;
  final String paymentType;
  final String amount;
  final String? payUrl;
  final CreditsPackage package;
}
