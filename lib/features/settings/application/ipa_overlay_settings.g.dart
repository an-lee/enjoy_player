// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ipa_overlay_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(IpaOverlaySettings)
final ipaOverlaySettingsProvider = IpaOverlaySettingsProvider._();

final class IpaOverlaySettingsProvider
    extends $AsyncNotifierProvider<IpaOverlaySettings, bool> {
  IpaOverlaySettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ipaOverlaySettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ipaOverlaySettingsHash();

  @$internal
  @override
  IpaOverlaySettings create() => IpaOverlaySettings();
}

String _$ipaOverlaySettingsHash() =>
    r'5d59c15118846bb7d92d1bb0a5249136cf73bd27';

abstract class _$IpaOverlaySettings extends $AsyncNotifier<bool> {
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
