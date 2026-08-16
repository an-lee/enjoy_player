// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'karaoke_position_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(karaokePosition)
final karaokePositionProvider = KaraokePositionProvider._();

final class KaraokePositionProvider
    extends
        $FunctionalProvider<AsyncValue<Duration>, Duration, Stream<Duration>>
    with $FutureModifier<Duration>, $StreamProvider<Duration> {
  KaraokePositionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'karaokePositionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$karaokePositionHash();

  @$internal
  @override
  $StreamProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Duration> create(Ref ref) {
    return karaokePosition(ref);
  }
}

String _$karaokePositionHash() => r'f3fd05977a0711e148637bf7da6944c7efe098a0';
