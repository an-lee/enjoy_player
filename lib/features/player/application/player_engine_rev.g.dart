// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_engine_rev.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PlayerEngineRev)
final playerEngineRevProvider = PlayerEngineRevProvider._();

final class PlayerEngineRevProvider
    extends $NotifierProvider<PlayerEngineRev, int> {
  PlayerEngineRevProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerEngineRevProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerEngineRevHash();

  @$internal
  @override
  PlayerEngineRev create() => PlayerEngineRev();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$playerEngineRevHash() => r'55ead3c77a832afc567dd42344a3f0a5d5ff899a';

abstract class _$PlayerEngineRev extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
