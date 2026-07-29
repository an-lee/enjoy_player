// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pronounce_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pronounceService)
final pronounceServiceProvider = PronounceServiceProvider._();

final class PronounceServiceProvider
    extends
        $FunctionalProvider<
          PronounceService,
          PronounceService,
          PronounceService
        >
    with $Provider<PronounceService> {
  PronounceServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pronounceServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pronounceServiceHash();

  @$internal
  @override
  $ProviderElement<PronounceService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PronounceService create(Ref ref) {
    return pronounceService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PronounceService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PronounceService>(value),
    );
  }
}

String _$pronounceServiceHash() => r'3489b168f3fdcd26b7ac1672a9b4144787259db7';
