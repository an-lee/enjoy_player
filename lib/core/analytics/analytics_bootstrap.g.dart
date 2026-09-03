// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_bootstrap.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(analyticsInit)
final analyticsInitProvider = AnalyticsInitProvider._();

final class AnalyticsInitProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  AnalyticsInitProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsInitProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsInitHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return analyticsInit(ref);
  }
}

String _$analyticsInitHash() => r'7c32b3a3e5debba629e5d42efc60051267807f6a';

/// Auth sync (data-model E2): events attribute to the signed-in account and
/// reset on sign-out. Attached here — outside the auth feature — so
/// `auth_controller.dart` carries no analytics code.

@ProviderFor(analyticsAuthSync)
final analyticsAuthSyncProvider = AnalyticsAuthSyncProvider._();

/// Auth sync (data-model E2): events attribute to the signed-in account and
/// reset on sign-out. Attached here — outside the auth feature — so
/// `auth_controller.dart` carries no analytics code.

final class AnalyticsAuthSyncProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Auth sync (data-model E2): events attribute to the signed-in account and
  /// reset on sign-out. Attached here — outside the auth feature — so
  /// `auth_controller.dart` carries no analytics code.
  AnalyticsAuthSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsAuthSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsAuthSyncHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return analyticsAuthSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$analyticsAuthSyncHash() => r'b770ef2fd78a9f9cb9e6b50aa3e71685596c0fd8';
