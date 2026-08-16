// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_cue_word_index_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Word index into the current cue's `timeline`, or null.
///
/// Subscribes to the 50 ms karaoke position stream only when karaoke **or**
/// word-level practice is on. Inactive tiles must not watch this provider.

@ProviderFor(activeCueWordIndex)
final activeCueWordIndexProvider = ActiveCueWordIndexFamily._();

/// Word index into the current cue's `timeline`, or null.
///
/// Subscribes to the 50 ms karaoke position stream only when karaoke **or**
/// word-level practice is on. Inactive tiles must not watch this provider.

final class ActiveCueWordIndexProvider
    extends $FunctionalProvider<int?, int?, int?>
    with $Provider<int?> {
  /// Word index into the current cue's `timeline`, or null.
  ///
  /// Subscribes to the 50 ms karaoke position stream only when karaoke **or**
  /// word-level practice is on. Inactive tiles must not watch this provider.
  ActiveCueWordIndexProvider._({
    required ActiveCueWordIndexFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activeCueWordIndexProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activeCueWordIndexHash();

  @override
  String toString() {
    return r'activeCueWordIndexProvider'
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
    return activeCueWordIndex(ref, argument);
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
    return other is ActiveCueWordIndexProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activeCueWordIndexHash() =>
    r'3ad2d0503cec476f0e39e6487a286d88153407d3';

/// Word index into the current cue's `timeline`, or null.
///
/// Subscribes to the 50 ms karaoke position stream only when karaoke **or**
/// word-level practice is on. Inactive tiles must not watch this provider.

final class ActiveCueWordIndexFamily extends $Family
    with $FunctionalFamilyOverride<int?, String> {
  ActiveCueWordIndexFamily._()
    : super(
        retry: null,
        name: r'activeCueWordIndexProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Word index into the current cue's `timeline`, or null.
  ///
  /// Subscribes to the 50 ms karaoke position stream only when karaoke **or**
  /// word-level practice is on. Inactive tiles must not watch this provider.

  ActiveCueWordIndexProvider call(String mediaId) =>
      ActiveCueWordIndexProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'activeCueWordIndexProvider';
}
