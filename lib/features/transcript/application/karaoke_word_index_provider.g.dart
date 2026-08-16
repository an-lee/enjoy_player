// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'karaoke_word_index_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Word index into the current cue's `timeline`, or null when karaoke is off
/// / still loading, the cue is line-only, or position is in a gap.
///
/// Watches [karaokeHighlightSettingsProvider] so a persisted `'true'` is not
/// frozen as off: loading is `null` (no paint yet), then this provider
/// rebuilds when the keep-alive notifier resolves. Inactive tiles must not
/// watch this provider.

@ProviderFor(karaokeWordIndex)
final karaokeWordIndexProvider = KaraokeWordIndexFamily._();

/// Word index into the current cue's `timeline`, or null when karaoke is off
/// / still loading, the cue is line-only, or position is in a gap.
///
/// Watches [karaokeHighlightSettingsProvider] so a persisted `'true'` is not
/// frozen as off: loading is `null` (no paint yet), then this provider
/// rebuilds when the keep-alive notifier resolves. Inactive tiles must not
/// watch this provider.

final class KaraokeWordIndexProvider
    extends $FunctionalProvider<int?, int?, int?>
    with $Provider<int?> {
  /// Word index into the current cue's `timeline`, or null when karaoke is off
  /// / still loading, the cue is line-only, or position is in a gap.
  ///
  /// Watches [karaokeHighlightSettingsProvider] so a persisted `'true'` is not
  /// frozen as off: loading is `null` (no paint yet), then this provider
  /// rebuilds when the keep-alive notifier resolves. Inactive tiles must not
  /// watch this provider.
  KaraokeWordIndexProvider._({
    required KaraokeWordIndexFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'karaokeWordIndexProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$karaokeWordIndexHash();

  @override
  String toString() {
    return r'karaokeWordIndexProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int? create(Ref ref) {
    final argument = this.argument as String;
    return karaokeWordIndex(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KaraokeWordIndexProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$karaokeWordIndexHash() => r'50744bb23b86d7d04a6f7dcc995dd80e72fb9ebd';

/// Word index into the current cue's `timeline`, or null when karaoke is off
/// / still loading, the cue is line-only, or position is in a gap.
///
/// Watches [karaokeHighlightSettingsProvider] so a persisted `'true'` is not
/// frozen as off: loading is `null` (no paint yet), then this provider
/// rebuilds when the keep-alive notifier resolves. Inactive tiles must not
/// watch this provider.

final class KaraokeWordIndexFamily extends $Family
    with $FunctionalFamilyOverride<int?, String> {
  KaraokeWordIndexFamily._()
    : super(
        retry: null,
        name: r'karaokeWordIndexProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Word index into the current cue's `timeline`, or null when karaoke is off
  /// / still loading, the cue is line-only, or position is in a gap.
  ///
  /// Watches [karaokeHighlightSettingsProvider] so a persisted `'true'` is not
  /// frozen as off: loading is `null` (no paint yet), then this provider
  /// rebuilds when the keep-alive notifier resolves. Inactive tiles must not
  /// watch this provider.

  KaraokeWordIndexProvider call(String mediaId) =>
      KaraokeWordIndexProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'karaokeWordIndexProvider';
}
