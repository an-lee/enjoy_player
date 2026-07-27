// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_modality_config_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiModalityConfigRepository)
final aiModalityConfigRepositoryProvider =
    AiModalityConfigRepositoryProvider._();

final class AiModalityConfigRepositoryProvider
    extends
        $FunctionalProvider<
          AiModalityConfigRepository,
          AiModalityConfigRepository,
          AiModalityConfigRepository
        >
    with $Provider<AiModalityConfigRepository> {
  AiModalityConfigRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiModalityConfigRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiModalityConfigRepositoryHash();

  @$internal
  @override
  $ProviderElement<AiModalityConfigRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiModalityConfigRepository create(Ref ref) {
    return aiModalityConfigRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiModalityConfigRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiModalityConfigRepository>(value),
    );
  }
}

String _$aiModalityConfigRepositoryHash() =>
    r'268e3671285105579a570aeabd17ac632440818d';

@ProviderFor(AiModalityConfigCtrl)
final aiModalityConfigCtrlProvider = AiModalityConfigCtrlProvider._();

final class AiModalityConfigCtrlProvider
    extends $NotifierProvider<AiModalityConfigCtrl, AiModalityConfigs> {
  AiModalityConfigCtrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiModalityConfigCtrlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiModalityConfigCtrlHash();

  @$internal
  @override
  AiModalityConfigCtrl create() => AiModalityConfigCtrl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiModalityConfigs value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiModalityConfigs>(value),
    );
  }
}

String _$aiModalityConfigCtrlHash() =>
    r'6683c27e48b8ccdf96cd08870ce0c7493c236bbf';

abstract class _$AiModalityConfigCtrl extends $Notifier<AiModalityConfigs> {
  AiModalityConfigs build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AiModalityConfigs, AiModalityConfigs>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AiModalityConfigs, AiModalityConfigs>,
              AiModalityConfigs,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
