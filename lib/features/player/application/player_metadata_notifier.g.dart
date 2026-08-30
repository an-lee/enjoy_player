// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_metadata_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Applies the lazy YouTube metadata patch to the open session.
///
/// A state-less service (issue #668): it holds no state of its own, so it is
/// exposed by a plain keepAlive [Provider] rather than a `void build()`
/// notifier wearing dummy state.

@ProviderFor(playerMetadata)
final playerMetadataProvider = PlayerMetadataProvider._();

/// Applies the lazy YouTube metadata patch to the open session.
///
/// A state-less service (issue #668): it holds no state of its own, so it is
/// exposed by a plain keepAlive [Provider] rather than a `void build()`
/// notifier wearing dummy state.

final class PlayerMetadataProvider
    extends
        $FunctionalProvider<
          PlayerMetadataService,
          PlayerMetadataService,
          PlayerMetadataService
        >
    with $Provider<PlayerMetadataService> {
  /// Applies the lazy YouTube metadata patch to the open session.
  ///
  /// A state-less service (issue #668): it holds no state of its own, so it is
  /// exposed by a plain keepAlive [Provider] rather than a `void build()`
  /// notifier wearing dummy state.
  PlayerMetadataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerMetadataProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerMetadataHash();

  @$internal
  @override
  $ProviderElement<PlayerMetadataService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlayerMetadataService create(Ref ref) {
    return playerMetadata(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerMetadataService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerMetadataService>(value),
    );
  }
}

String _$playerMetadataHash() => r'dd2d0e814bb0a818f8087d6a2b854780f28a78f3';
