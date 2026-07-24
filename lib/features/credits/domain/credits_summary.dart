/// Worker `GET /credits/summary` wallet standing.
library;

import 'package:enjoy_player/core/json/json_cast.dart';

class CreditsSummary {
  const CreditsSummary({
    required this.tier,
    required this.dailyUsed,
    required this.dailyLimit,
    required this.dailyRemaining,
    required this.permanentAvailable,
    required this.resetAt,
  });

  factory CreditsSummary.fromJson(Map<String, dynamic> json) {
    return CreditsSummary(
      tier: json['tier']?.toString() ?? '',
      dailyUsed: intOrZero(json['dailyUsed']),
      dailyLimit: intOrZero(json['dailyLimit']),
      dailyRemaining: intOrZero(json['dailyRemaining']),
      permanentAvailable: intOrZero(json['permanentAvailable']),
      resetAt: intOrZero(json['resetAt']),
    );
  }

  final String tier;
  final int dailyUsed;
  final int dailyLimit;
  final int dailyRemaining;
  final int permanentAvailable;
  final int resetAt;

  Map<String, dynamic> toJson() => {
    'tier': tier,
    'dailyUsed': dailyUsed,
    'dailyLimit': dailyLimit,
    'dailyRemaining': dailyRemaining,
    'permanentAvailable': permanentAvailable,
    'resetAt': resetAt,
  };
}
