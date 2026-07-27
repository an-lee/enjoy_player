// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_search_focus_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(librarySearchFocusNode)
final librarySearchFocusNodeProvider = LibrarySearchFocusNodeProvider._();

final class LibrarySearchFocusNodeProvider
    extends $FunctionalProvider<FocusNode, FocusNode, FocusNode>
    with $Provider<FocusNode> {
  LibrarySearchFocusNodeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySearchFocusNodeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySearchFocusNodeHash();

  @$internal
  @override
  $ProviderElement<FocusNode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FocusNode create(Ref ref) {
    return librarySearchFocusNode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FocusNode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FocusNode>(value),
    );
  }
}

String _$librarySearchFocusNodeHash() =>
    r'cedebc56634790652972cead06b89fd52e374140';

@ProviderFor(libraryCompactSearchFocusNode)
final libraryCompactSearchFocusNodeProvider =
    LibraryCompactSearchFocusNodeProvider._();

final class LibraryCompactSearchFocusNodeProvider
    extends $FunctionalProvider<FocusNode, FocusNode, FocusNode>
    with $Provider<FocusNode> {
  LibraryCompactSearchFocusNodeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryCompactSearchFocusNodeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryCompactSearchFocusNodeHash();

  @$internal
  @override
  $ProviderElement<FocusNode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FocusNode create(Ref ref) {
    return libraryCompactSearchFocusNode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FocusNode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FocusNode>(value),
    );
  }
}

String _$libraryCompactSearchFocusNodeHash() =>
    r'08b844858e4c4c6afa42af03020f3d83fb8afda8';

@ProviderFor(LibrarySearchFocusRequest)
final librarySearchFocusRequestProvider = LibrarySearchFocusRequestProvider._();

final class LibrarySearchFocusRequestProvider
    extends $NotifierProvider<LibrarySearchFocusRequest, int> {
  LibrarySearchFocusRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySearchFocusRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySearchFocusRequestHash();

  @$internal
  @override
  LibrarySearchFocusRequest create() => LibrarySearchFocusRequest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$librarySearchFocusRequestHash() =>
    r'20c74eee443bd566b427905702f4627ea28e4c1f';

abstract class _$LibrarySearchFocusRequest extends $Notifier<int> {
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
