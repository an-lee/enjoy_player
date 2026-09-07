// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tier_reconcile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Orchestrates tier reconciliation between the app and the Enjoy API.
///
/// Reconciliation refreshes *both* sources of truth consumed by
/// [currentTierProvider]: the cached profile ([authCtrlProvider], via
/// [AuthCtrl.refreshProfile]) and the live status
/// ([subscriptionStatusProvider]). This guarantees a tier change made on the
/// web (with or without an app-initiated checkout) surfaces in the app on the
/// next resume or cold start — see ADR-0041.

@ProviderFor(TierReconcileCtrl)
final tierReconcileCtrlProvider = TierReconcileCtrlProvider._();

/// Orchestrates tier reconciliation between the app and the Enjoy API.
///
/// Reconciliation refreshes *both* sources of truth consumed by
/// [currentTierProvider]: the cached profile ([authCtrlProvider], via
/// [AuthCtrl.refreshProfile]) and the live status
/// ([subscriptionStatusProvider]). This guarantees a tier change made on the
/// web (with or without an app-initiated checkout) surfaces in the app on the
/// next resume or cold start — see ADR-0041.
final class TierReconcileCtrlProvider
    extends $NotifierProvider<TierReconcileCtrl, void> {
  /// Orchestrates tier reconciliation between the app and the Enjoy API.
  ///
  /// Reconciliation refreshes *both* sources of truth consumed by
  /// [currentTierProvider]: the cached profile ([authCtrlProvider], via
  /// [AuthCtrl.refreshProfile]) and the live status
  /// ([subscriptionStatusProvider]). This guarantees a tier change made on the
  /// web (with or without an app-initiated checkout) surfaces in the app on the
  /// next resume or cold start — see ADR-0041.
  TierReconcileCtrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tierReconcileCtrlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tierReconcileCtrlHash();

  @$internal
  @override
  TierReconcileCtrl create() => TierReconcileCtrl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$tierReconcileCtrlHash() => r'79fbae2e2188dc197b8770884382d66422adeae1';

/// Orchestrates tier reconciliation between the app and the Enjoy API.
///
/// Reconciliation refreshes *both* sources of truth consumed by
/// [currentTierProvider]: the cached profile ([authCtrlProvider], via
/// [AuthCtrl.refreshProfile]) and the live status
/// ([subscriptionStatusProvider]). This guarantees a tier change made on the
/// web (with or without an app-initiated checkout) surfaces in the app on the
/// next resume or cold start — see ADR-0041.

abstract class _$TierReconcileCtrl extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
