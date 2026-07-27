// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_preferences_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppPreferencesCtrl)
final appPreferencesCtrlProvider = AppPreferencesCtrlProvider._();

final class AppPreferencesCtrlProvider
    extends $AsyncNotifierProvider<AppPreferencesCtrl, AppPreferencesState> {
  AppPreferencesCtrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appPreferencesCtrlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appPreferencesCtrlHash();

  @$internal
  @override
  AppPreferencesCtrl create() => AppPreferencesCtrl();
}

String _$appPreferencesCtrlHash() =>
    r'9cddaae8a471dcfda3a8d66c6b5d53df9e03a85f';

abstract class _$AppPreferencesCtrl
    extends $AsyncNotifier<AppPreferencesState> {
  FutureOr<AppPreferencesState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AppPreferencesState>, AppPreferencesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppPreferencesState>, AppPreferencesState>,
              AsyncValue<AppPreferencesState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
