/// User profile returned by `GET/PATCH /api/v1/profile` (camelCase JSON).
library;

import 'package:enjoy_player/core/json/json_cast.dart';
import 'package:enjoy_player/core/utils/avatar_url.dart';

enum SubscriptionTier { free, pro }

SubscriptionTier? _subscriptionTierFromJson(Object? value) {
  if (value == null) return null;
  final s = value.toString().toLowerCase();
  if (s == 'pro') return SubscriptionTier.pro;
  return SubscriptionTier.free;
}

class UserProfile {
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: rasterAvatarUrl(json['avatarUrl'] as String?),
      balance: _doubleFromJson(json['balance']),
      hasMixin: json['hasMixin'] as bool?,
      mixinId: json['mixinId']?.toString(),
      subscriptionTier: _subscriptionTierFromJson(json['subscriptionTier']),
      subscriptionExpireDate: json['subscriptionExpireDate'] as String?,
      locale: json['locale'] as String?,
      learningLanguage: json['learningLanguage'] as String?,
      nativeLanguage: json['nativeLanguage'] as String?,
      goal: intFromJson(json['goal']),
      createdAt: json['createdAt'] as String?,
    );
  }
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.balance,
    this.hasMixin,
    this.mixinId,
    this.subscriptionTier,
    this.subscriptionExpireDate,
    this.locale,
    this.learningLanguage,
    this.nativeLanguage,
    this.goal,
    this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final double? balance;
  final bool? hasMixin;

  /// Linked Mixin number when present; null / empty means not linked.
  final String? mixinId;
  final SubscriptionTier? subscriptionTier;
  final String? subscriptionExpireDate;
  final String? locale;
  final String? learningLanguage;
  final String? nativeLanguage;
  final int? goal;
  final String? createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'name': name,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (balance != null) 'balance': balance,
      if (hasMixin != null) 'hasMixin': hasMixin,
      if (mixinId != null) 'mixinId': mixinId,
      if (subscriptionTier != null) 'subscriptionTier': subscriptionTier!.name,
      if (subscriptionExpireDate != null)
        'subscriptionExpireDate': subscriptionExpireDate,
      if (locale != null) 'locale': locale,
      if (learningLanguage != null) 'learningLanguage': learningLanguage,
      if (nativeLanguage != null) 'nativeLanguage': nativeLanguage,
      if (goal != null) 'goal': goal,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    double? balance,
    bool? hasMixin,
    String? mixinId,
    SubscriptionTier? subscriptionTier,
    String? subscriptionExpireDate,
    String? locale,
    String? learningLanguage,
    String? nativeLanguage,
    int? goal,
    String? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      balance: balance ?? this.balance,
      hasMixin: hasMixin ?? this.hasMixin,
      mixinId: mixinId ?? this.mixinId,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionExpireDate:
          subscriptionExpireDate ?? this.subscriptionExpireDate,
      locale: locale ?? this.locale,
      learningLanguage: learningLanguage ?? this.learningLanguage,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      goal: goal ?? this.goal,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

double? _doubleFromJson(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
