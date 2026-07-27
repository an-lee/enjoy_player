// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credits_usage_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CreditsUsageFiltersCtrl)
final creditsUsageFiltersCtrlProvider = CreditsUsageFiltersCtrlProvider._();

final class CreditsUsageFiltersCtrlProvider
    extends $NotifierProvider<CreditsUsageFiltersCtrl, CreditsUsageFilters> {
  CreditsUsageFiltersCtrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditsUsageFiltersCtrlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creditsUsageFiltersCtrlHash();

  @$internal
  @override
  CreditsUsageFiltersCtrl create() => CreditsUsageFiltersCtrl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreditsUsageFilters value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreditsUsageFilters>(value),
    );
  }
}

String _$creditsUsageFiltersCtrlHash() =>
    r'169354c7fd76367d26adbeed32ef33fc32388af5';

abstract class _$CreditsUsageFiltersCtrl
    extends $Notifier<CreditsUsageFilters> {
  CreditsUsageFilters build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CreditsUsageFilters, CreditsUsageFilters>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CreditsUsageFilters, CreditsUsageFilters>,
              CreditsUsageFilters,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(creditsUsagePage)
final creditsUsagePageProvider = CreditsUsagePageProvider._();

final class CreditsUsagePageProvider
    extends
        $FunctionalProvider<
          AsyncValue<CreditsUsagePage>,
          CreditsUsagePage,
          FutureOr<CreditsUsagePage>
        >
    with $FutureModifier<CreditsUsagePage>, $FutureProvider<CreditsUsagePage> {
  CreditsUsagePageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditsUsagePageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creditsUsagePageHash();

  @$internal
  @override
  $FutureProviderElement<CreditsUsagePage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CreditsUsagePage> create(Ref ref) {
    return creditsUsagePage(ref);
  }
}

String _$creditsUsagePageHash() => r'fcc9040723308271a80995e3843f1adf2c2e6e8c';
