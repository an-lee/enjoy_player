// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shadow_reading_hotkey_bus.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ShadowReadingHotkeyBus)
final shadowReadingHotkeyBusProvider = ShadowReadingHotkeyBusProvider._();

final class ShadowReadingHotkeyBusProvider
    extends
        $NotifierProvider<ShadowReadingHotkeyBus, ShadowReadingHotkeyTicks> {
  ShadowReadingHotkeyBusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shadowReadingHotkeyBusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shadowReadingHotkeyBusHash();

  @$internal
  @override
  ShadowReadingHotkeyBus create() => ShadowReadingHotkeyBus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShadowReadingHotkeyTicks value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShadowReadingHotkeyTicks>(value),
    );
  }
}

String _$shadowReadingHotkeyBusHash() =>
    r'da601ccfcfc74886f955c5f2a1740c40f10f340f';

abstract class _$ShadowReadingHotkeyBus
    extends $Notifier<ShadowReadingHotkeyTicks> {
  ShadowReadingHotkeyTicks build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<ShadowReadingHotkeyTicks, ShadowReadingHotkeyTicks>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ShadowReadingHotkeyTicks, ShadowReadingHotkeyTicks>,
              ShadowReadingHotkeyTicks,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
