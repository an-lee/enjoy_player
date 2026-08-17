// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_display_readiness_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// True when this item has a trusted local file (karaoke may use word clocks).

@ProviderFor(canTrustWordTimes)
final canTrustWordTimesProvider = CanTrustWordTimesFamily._();

/// True when this item has a trusted local file (karaoke may use word clocks).

final class CanTrustWordTimesProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// True when this item has a trusted local file (karaoke may use word clocks).
  CanTrustWordTimesProvider._({
    required CanTrustWordTimesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'canTrustWordTimesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$canTrustWordTimesHash();

  @override
  String toString() {
    return r'canTrustWordTimesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return canTrustWordTimes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CanTrustWordTimesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$canTrustWordTimesHash() => r'e26959a74e4faa64f61c97981098628b94b286da';

/// True when this item has a trusted local file (karaoke may use word clocks).

final class CanTrustWordTimesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  CanTrustWordTimesFamily._()
    : super(
        retry: null,
        name: r'canTrustWordTimesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// True when this item has a trusted local file (karaoke may use word clocks).

  CanTrustWordTimesProvider call(String mediaId) =>
      CanTrustWordTimesProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'canTrustWordTimesProvider';
}

/// Primary-track display capability for [mediaId].

@ProviderFor(transcriptDisplayReadinessForMedia)
final transcriptDisplayReadinessForMediaProvider =
    TranscriptDisplayReadinessForMediaFamily._();

/// Primary-track display capability for [mediaId].

final class TranscriptDisplayReadinessForMediaProvider
    extends
        $FunctionalProvider<
          TranscriptDisplayReadiness,
          TranscriptDisplayReadiness,
          TranscriptDisplayReadiness
        >
    with $Provider<TranscriptDisplayReadiness> {
  /// Primary-track display capability for [mediaId].
  TranscriptDisplayReadinessForMediaProvider._({
    required TranscriptDisplayReadinessForMediaFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transcriptDisplayReadinessForMediaProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$transcriptDisplayReadinessForMediaHash();

  @override
  String toString() {
    return r'transcriptDisplayReadinessForMediaProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TranscriptDisplayReadiness> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TranscriptDisplayReadiness create(Ref ref) {
    final argument = this.argument as String;
    return transcriptDisplayReadinessForMedia(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptDisplayReadiness value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptDisplayReadiness>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptDisplayReadinessForMediaProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transcriptDisplayReadinessForMediaHash() =>
    r'c2ff60c7bb2bd597c534ca62fb8a61880b9373d0';

/// Primary-track display capability for [mediaId].

final class TranscriptDisplayReadinessForMediaFamily extends $Family
    with $FunctionalFamilyOverride<TranscriptDisplayReadiness, String> {
  TranscriptDisplayReadinessForMediaFamily._()
    : super(
        retry: null,
        name: r'transcriptDisplayReadinessForMediaProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Primary-track display capability for [mediaId].

  TranscriptDisplayReadinessForMediaProvider call(String mediaId) =>
      TranscriptDisplayReadinessForMediaProvider._(
        argument: mediaId,
        from: this,
      );

  @override
  String toString() => r'transcriptDisplayReadinessForMediaProvider';
}
