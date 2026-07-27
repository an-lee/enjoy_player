// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_ui_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PlayerUi)
final playerUiProvider = PlayerUiProvider._();

final class PlayerUiProvider
    extends $NotifierProvider<PlayerUi, PlayerUiState> {
  PlayerUiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerUiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerUiHash();

  @$internal
  @override
  PlayerUi create() => PlayerUi();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerUiState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerUiState>(value),
    );
  }
}

String _$playerUiHash() => r'f67760388c6da2afa513793e912c7f9c5661bbd8';

abstract class _$PlayerUi extends $Notifier<PlayerUiState> {
  PlayerUiState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlayerUiState, PlayerUiState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlayerUiState, PlayerUiState>,
              PlayerUiState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
