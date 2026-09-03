// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_capture_pref.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AnalyticsCapturePref)
final analyticsCapturePrefProvider = AnalyticsCapturePrefProvider._();

final class AnalyticsCapturePrefProvider
    extends $AsyncNotifierProvider<AnalyticsCapturePref, bool> {
  AnalyticsCapturePrefProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsCapturePrefProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsCapturePrefHash();

  @$internal
  @override
  AnalyticsCapturePref create() => AnalyticsCapturePref();
}

String _$analyticsCapturePrefHash() =>
    r'da5280c44ce2549fc4b72701f6f6bdb59ac7846a';

abstract class _$AnalyticsCapturePref extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
