// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'karaoke_highlight_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(KaraokeHighlightSettings)
final karaokeHighlightSettingsProvider = KaraokeHighlightSettingsProvider._();

final class KaraokeHighlightSettingsProvider
    extends $AsyncNotifierProvider<KaraokeHighlightSettings, bool> {
  KaraokeHighlightSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'karaokeHighlightSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$karaokeHighlightSettingsHash();

  @$internal
  @override
  KaraokeHighlightSettings create() => KaraokeHighlightSettings();
}

String _$karaokeHighlightSettingsHash() =>
    r'4454bb1ae2bd406a48f43c52ff6899ee7bb4f518';

abstract class _$KaraokeHighlightSettings extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
