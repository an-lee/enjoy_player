// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UpdateCtrl)
final updateCtrlProvider = UpdateCtrlProvider._();

final class UpdateCtrlProvider
    extends $NotifierProvider<UpdateCtrl, UpdateCheckResult?> {
  UpdateCtrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateCtrlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateCtrlHash();

  @$internal
  @override
  UpdateCtrl create() => UpdateCtrl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateCheckResult? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateCheckResult?>(value),
    );
  }
}

String _$updateCtrlHash() => r'8769a898c8253ae2fda256f1b60a23d6fdde33b1';

abstract class _$UpdateCtrl extends $Notifier<UpdateCheckResult?> {
  UpdateCheckResult? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UpdateCheckResult?, UpdateCheckResult?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UpdateCheckResult?, UpdateCheckResult?>,
              UpdateCheckResult?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether Settings / Profile should show an update notification dot.

@ProviderFor(updateAvailableBadge)
final updateAvailableBadgeProvider = UpdateAvailableBadgeProvider._();

/// Whether Settings / Profile should show an update notification dot.

final class UpdateAvailableBadgeProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether Settings / Profile should show an update notification dot.
  UpdateAvailableBadgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateAvailableBadgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateAvailableBadgeHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return updateAvailableBadge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$updateAvailableBadgeHash() =>
    r'f5e4df3407ad3052a9fb53c8a5952424fdddc66e';
