// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_interactions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Builds the line-control service.
///
/// A state-less service (issue #668): [PlayerInteractions] holds a lines cache
/// but exposes no provider state, so it is handed out by a plain keepAlive
/// [Provider] rather than a `build() => 0` notifier wearing dummy state.

@ProviderFor(playerInteractions)
final playerInteractionsProvider = PlayerInteractionsProvider._();

/// Builds the line-control service.
///
/// A state-less service (issue #668): [PlayerInteractions] holds a lines cache
/// but exposes no provider state, so it is handed out by a plain keepAlive
/// [Provider] rather than a `build() => 0` notifier wearing dummy state.

final class PlayerInteractionsProvider
    extends
        $FunctionalProvider<
          PlayerInteractions,
          PlayerInteractions,
          PlayerInteractions
        >
    with $Provider<PlayerInteractions> {
  /// Builds the line-control service.
  ///
  /// A state-less service (issue #668): [PlayerInteractions] holds a lines cache
  /// but exposes no provider state, so it is handed out by a plain keepAlive
  /// [Provider] rather than a `build() => 0` notifier wearing dummy state.
  PlayerInteractionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerInteractionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerInteractionsHash();

  @$internal
  @override
  $ProviderElement<PlayerInteractions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlayerInteractions create(Ref ref) {
    return playerInteractions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerInteractions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerInteractions>(value),
    );
  }
}

String _$playerInteractionsHash() =>
    r'0bea819a31968a45e81767b30aa1c8fec3446d98';
