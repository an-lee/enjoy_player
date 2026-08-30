// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asr_generation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AsrGenerationController)
final asrGenerationControllerProvider = AsrGenerationControllerFamily._();

final class AsrGenerationControllerProvider
    extends
        $NotifierProvider<
          AsrGenerationController,
          AsyncValue<AsrGenerationJob?>
        > {
  AsrGenerationControllerProvider._({
    required AsrGenerationControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'asrGenerationControllerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$asrGenerationControllerHash();

  @override
  String toString() {
    return r'asrGenerationControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AsrGenerationController create() => AsrGenerationController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AsrGenerationJob?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<AsrGenerationJob?>>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AsrGenerationControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$asrGenerationControllerHash() =>
    r'20a1dec8557cfeafd730df5bf27be6ad349c0ec6';

final class AsrGenerationControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          AsrGenerationController,
          AsyncValue<AsrGenerationJob?>,
          AsyncValue<AsrGenerationJob?>,
          AsyncValue<AsrGenerationJob?>,
          String
        > {
  AsrGenerationControllerFamily._()
    : super(
        retry: null,
        name: r'asrGenerationControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  AsrGenerationControllerProvider call(String mediaId) =>
      AsrGenerationControllerProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'asrGenerationControllerProvider';
}

abstract class _$AsrGenerationController
    extends $Notifier<AsyncValue<AsrGenerationJob?>> {
  late final _$args = ref.$arg as String;
  String get mediaId => _$args;

  AsyncValue<AsrGenerationJob?> build(String mediaId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<AsrGenerationJob?>,
              AsyncValue<AsrGenerationJob?>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AsrGenerationJob?>,
                AsyncValue<AsrGenerationJob?>
              >,
              AsyncValue<AsrGenerationJob?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Singleton extractor (cheap; no state).

@ProviderFor(asrAudioExtractor)
final asrAudioExtractorProvider = AsrAudioExtractorProvider._();

/// Singleton extractor (cheap; no state).

final class AsrAudioExtractorProvider
    extends
        $FunctionalProvider<
          AsrAudioExtractor,
          AsrAudioExtractor,
          AsrAudioExtractor
        >
    with $Provider<AsrAudioExtractor> {
  /// Singleton extractor (cheap; no state).
  AsrAudioExtractorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'asrAudioExtractorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$asrAudioExtractorHash();

  @$internal
  @override
  $ProviderElement<AsrAudioExtractor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsrAudioExtractor create(Ref ref) {
    return asrAudioExtractor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsrAudioExtractor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsrAudioExtractor>(value),
    );
  }
}

String _$asrAudioExtractorHash() => r'6d9a5570cb6919372e9bd8329500ce0533ca02d8';
