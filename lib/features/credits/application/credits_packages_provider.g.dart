// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credits_packages_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(creditsPackages)
final creditsPackagesProvider = CreditsPackagesProvider._();

final class CreditsPackagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CreditsPackage>>,
          List<CreditsPackage>,
          FutureOr<List<CreditsPackage>>
        >
    with
        $FutureModifier<List<CreditsPackage>>,
        $FutureProvider<List<CreditsPackage>> {
  CreditsPackagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditsPackagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creditsPackagesHash();

  @$internal
  @override
  $FutureProviderElement<List<CreditsPackage>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CreditsPackage>> create(Ref ref) {
    return creditsPackages(ref);
  }
}

String _$creditsPackagesHash() => r'b02f5a3e956d469a8f62046afceb1ebbc0e10e7d';

@ProviderFor(CreditsPackagePurchaseCtrl)
final creditsPackagePurchaseCtrlProvider =
    CreditsPackagePurchaseCtrlProvider._();

final class CreditsPackagePurchaseCtrlProvider
    extends $NotifierProvider<CreditsPackagePurchaseCtrl, AsyncValue<void>> {
  CreditsPackagePurchaseCtrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditsPackagePurchaseCtrlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creditsPackagePurchaseCtrlHash();

  @$internal
  @override
  CreditsPackagePurchaseCtrl create() => CreditsPackagePurchaseCtrl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$creditsPackagePurchaseCtrlHash() =>
    r'5d0e8686729f788f119eecba7434ad20a010af4d';

abstract class _$CreditsPackagePurchaseCtrl
    extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
