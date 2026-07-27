// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_metadata_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PlayerMetadataNotifier)
final playerMetadataProvider = PlayerMetadataNotifierProvider._();

final class PlayerMetadataNotifierProvider
    extends $NotifierProvider<PlayerMetadataNotifier, void> {
  PlayerMetadataNotifierProvider._()
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
  String debugGetCreateSourceHash() => _$playerMetadataNotifierHash();

  @$internal
  @override
  PlayerMetadataNotifier create() => PlayerMetadataNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$playerMetadataNotifierHash() =>
    r'a803fb6b0d3daf39469ec97860ec838e5dee1e8a';

abstract class _$PlayerMetadataNotifier extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
