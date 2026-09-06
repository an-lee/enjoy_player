// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Deterministic end-of-media completion loop (ADR-0044).
///
/// Mirrors the generation-counter + single-flight pattern from
/// [SingleFlightGate]: the transport drives itself off
/// `await`ed completion futures instead of polling the position stream, and
/// every in-flight await captures a generation id so a stale completion from a
/// previous media (or a duplicate `completed` event from mpv) is a no-op.

@ProviderFor(PlayerController)
final playerControllerProvider = PlayerControllerProvider._();

/// Deterministic end-of-media completion loop (ADR-0044).
///
/// Mirrors the generation-counter + single-flight pattern from
/// [SingleFlightGate]: the transport drives itself off
/// `await`ed completion futures instead of polling the position stream, and
/// every in-flight await captures a generation id so a stale completion from a
/// previous media (or a duplicate `completed` event from mpv) is a no-op.
final class PlayerControllerProvider
    extends $NotifierProvider<PlayerController, PlaybackSession?> {
  /// Deterministic end-of-media completion loop (ADR-0044).
  ///
  /// Mirrors the generation-counter + single-flight pattern from
  /// [SingleFlightGate]: the transport drives itself off
  /// `await`ed completion futures instead of polling the position stream, and
  /// every in-flight await captures a generation id so a stale completion from a
  /// previous media (or a duplicate `completed` event from mpv) is a no-op.
  PlayerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerControllerHash();

  @$internal
  @override
  PlayerController create() => PlayerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackSession? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackSession?>(value),
    );
  }
}

String _$playerControllerHash() => r'3972ed1babe218402c24c29153c165f4e02496bf';

/// Deterministic end-of-media completion loop (ADR-0044).
///
/// Mirrors the generation-counter + single-flight pattern from
/// [SingleFlightGate]: the transport drives itself off
/// `await`ed completion futures instead of polling the position stream, and
/// every in-flight await captures a generation id so a stale completion from a
/// previous media (or a duplicate `completed` event from mpv) is a no-op.

abstract class _$PlayerController extends $Notifier<PlaybackSession?> {
  PlaybackSession? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlaybackSession?, PlaybackSession?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlaybackSession?, PlaybackSession?>,
              PlaybackSession?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
