// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_display_readiness_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// True when this item is owned media (local file or the user's cloud URL).
///
/// Karaoke may use stored word clocks. YouTube stays false.

@ProviderFor(canTrustWordTimes)
final canTrustWordTimesProvider = CanTrustWordTimesFamily._();

/// True when this item is owned media (local file or the user's cloud URL).
///
/// Karaoke may use stored word clocks. YouTube stays false.

final class CanTrustWordTimesProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// True when this item is owned media (local file or the user's cloud URL).
  ///
  /// Karaoke may use stored word clocks. YouTube stays false.
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

String _$canTrustWordTimesHash() => r'6add1f0dc4e43589f180e6b3146d3cc20601c834';

/// True when this item is owned media (local file or the user's cloud URL).
///
/// Karaoke may use stored word clocks. YouTube stays false.

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

  /// True when this item is owned media (local file or the user's cloud URL).
  ///
  /// Karaoke may use stored word clocks. YouTube stays false.

  CanTrustWordTimesProvider call(String mediaId) =>
      CanTrustWordTimesProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'canTrustWordTimesProvider';
}

/// Unresolved trust (provider still loading) is treated as owned so
/// cloud-library nested-but-incomplete tracks keep the enrich tile and
/// owned copy. YouTube flips to false once the row resolves. Karaoke stays
/// off until trust is known and [hasTimedWords] is true.

@ProviderFor(transcriptDisplayReadinessForMedia)
final transcriptDisplayReadinessForMediaProvider =
    TranscriptDisplayReadinessForMediaFamily._();

/// Unresolved trust (provider still loading) is treated as owned so
/// cloud-library nested-but-incomplete tracks keep the enrich tile and
/// owned copy. YouTube flips to false once the row resolves. Karaoke stays
/// off until trust is known and [hasTimedWords] is true.

final class TranscriptDisplayReadinessForMediaProvider
    extends
        $FunctionalProvider<
          TranscriptDisplayReadiness,
          TranscriptDisplayReadiness,
          TranscriptDisplayReadiness
        >
    with $Provider<TranscriptDisplayReadiness> {
  /// Unresolved trust (provider still loading) is treated as owned so
  /// cloud-library nested-but-incomplete tracks keep the enrich tile and
  /// owned copy. YouTube flips to false once the row resolves. Karaoke stays
  /// off until trust is known and [hasTimedWords] is true.
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
    r'25f22b1016b096967e88f881e4175e09d2bbd3b7';

/// Unresolved trust (provider still loading) is treated as owned so
/// cloud-library nested-but-incomplete tracks keep the enrich tile and
/// owned copy. YouTube flips to false once the row resolves. Karaoke stays
/// off until trust is known and [hasTimedWords] is true.

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

  /// Unresolved trust (provider still loading) is treated as owned so
  /// cloud-library nested-but-incomplete tracks keep the enrich tile and
  /// owned copy. YouTube flips to false once the row resolves. Karaoke stays
  /// off until trust is known and [hasTimedWords] is true.

  TranscriptDisplayReadinessForMediaProvider call(String mediaId) =>
      TranscriptDisplayReadinessForMediaProvider._(
        argument: mediaId,
        from: this,
      );

  @override
  String toString() => r'transcriptDisplayReadinessForMediaProvider';
}
