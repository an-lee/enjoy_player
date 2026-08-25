/// Payment processor for Pro subscription checkout (Enjoy Rails API).
library;

import 'package:enjoy_player/core/json/json_cast.dart';

enum PaymentProcessor {
  stripe,
  mixin;

  String get apiValue => name;

  static PaymentProcessor? fromJson(Object? value) =>
      switch (stringOrNull(value)) {
        'stripe' => PaymentProcessor.stripe,
        'mixin' => PaymentProcessor.mixin,
        _ => null,
      };
}

enum PaymentStatus {
  pending,
  succeeded,
  expired;

  static PaymentStatus? fromJson(Object? value) =>
      switch (stringOrNull(value)) {
        'pending' => PaymentStatus.pending,
        'succeeded' => PaymentStatus.succeeded,
        'expired' => PaymentStatus.expired,
        _ => null,
      };
}
