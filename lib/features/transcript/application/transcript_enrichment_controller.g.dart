// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_enrichment_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(transcriptEnricher)
final transcriptEnricherProvider = TranscriptEnricherProvider._();

final class TranscriptEnricherProvider
    extends
        $FunctionalProvider<
          TranscriptEnricher,
          TranscriptEnricher,
          TranscriptEnricher
        >
    with $Provider<TranscriptEnricher> {
  TranscriptEnricherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transcriptEnricherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transcriptEnricherHash();

  @$internal
  @override
  $ProviderElement<TranscriptEnricher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TranscriptEnricher create(Ref ref) {
    return transcriptEnricher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptEnricher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptEnricher>(value),
    );
  }
}

String _$transcriptEnricherHash() =>
    r'2de1e4884094f26def55abd9b9a0143a5af86aef';

@ProviderFor(TranscriptEnrichmentController)
final transcriptEnrichmentControllerProvider =
    TranscriptEnrichmentControllerFamily._();

final class TranscriptEnrichmentControllerProvider
    extends
        $NotifierProvider<
          TranscriptEnrichmentController,
          TranscriptEnrichmentState
        > {
  TranscriptEnrichmentControllerProvider._({
    required TranscriptEnrichmentControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transcriptEnrichmentControllerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transcriptEnrichmentControllerHash();

  @override
  String toString() {
    return r'transcriptEnrichmentControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TranscriptEnrichmentController create() => TranscriptEnrichmentController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptEnrichmentState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptEnrichmentState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptEnrichmentControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transcriptEnrichmentControllerHash() =>
    r'4b554b8e23a0c6f639509820c19bc8c6482eefe2';

final class TranscriptEnrichmentControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TranscriptEnrichmentController,
          TranscriptEnrichmentState,
          TranscriptEnrichmentState,
          TranscriptEnrichmentState,
          String
        > {
  TranscriptEnrichmentControllerFamily._()
    : super(
        retry: null,
        name: r'transcriptEnrichmentControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  TranscriptEnrichmentControllerProvider call(String mediaId) =>
      TranscriptEnrichmentControllerProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'transcriptEnrichmentControllerProvider';
}

abstract class _$TranscriptEnrichmentController
    extends $Notifier<TranscriptEnrichmentState> {
  late final _$args = ref.$arg as String;
  String get mediaId => _$args;

  TranscriptEnrichmentState build(String mediaId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<TranscriptEnrichmentState, TranscriptEnrichmentState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TranscriptEnrichmentState, TranscriptEnrichmentState>,
              TranscriptEnrichmentState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
