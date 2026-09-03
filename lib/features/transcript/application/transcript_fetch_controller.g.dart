// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_fetch_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TranscriptFetchCtrl)
final transcriptFetchCtrlProvider = TranscriptFetchCtrlFamily._();

final class TranscriptFetchCtrlProvider
    extends $NotifierProvider<TranscriptFetchCtrl, TranscriptFetchUiState> {
  TranscriptFetchCtrlProvider._({
    required TranscriptFetchCtrlFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transcriptFetchCtrlProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transcriptFetchCtrlHash();

  @override
  String toString() {
    return r'transcriptFetchCtrlProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TranscriptFetchCtrl create() => TranscriptFetchCtrl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptFetchUiState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptFetchUiState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptFetchCtrlProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transcriptFetchCtrlHash() =>
    r'e1ae9e27ec4ead4ee54557f91dee06c17cb3fd48';

final class TranscriptFetchCtrlFamily extends $Family
    with
        $ClassFamilyOverride<
          TranscriptFetchCtrl,
          TranscriptFetchUiState,
          TranscriptFetchUiState,
          TranscriptFetchUiState,
          String
        > {
  TranscriptFetchCtrlFamily._()
    : super(
        retry: null,
        name: r'transcriptFetchCtrlProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  TranscriptFetchCtrlProvider call(String mediaId) =>
      TranscriptFetchCtrlProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'transcriptFetchCtrlProvider';
}

abstract class _$TranscriptFetchCtrl extends $Notifier<TranscriptFetchUiState> {
  late final _$args = ref.$arg as String;
  String get mediaId => _$args;

  TranscriptFetchUiState build(String mediaId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<TranscriptFetchUiState, TranscriptFetchUiState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TranscriptFetchUiState, TranscriptFetchUiState>,
              TranscriptFetchUiState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Read-only alias for widgets that only need fetch status.

@ProviderFor(transcriptFetchStatus)
final transcriptFetchStatusProvider = TranscriptFetchStatusFamily._();

/// Read-only alias for widgets that only need fetch status.

final class TranscriptFetchStatusProvider
    extends
        $FunctionalProvider<
          TranscriptFetchUiState,
          TranscriptFetchUiState,
          TranscriptFetchUiState
        >
    with $Provider<TranscriptFetchUiState> {
  /// Read-only alias for widgets that only need fetch status.
  TranscriptFetchStatusProvider._({
    required TranscriptFetchStatusFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transcriptFetchStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transcriptFetchStatusHash();

  @override
  String toString() {
    return r'transcriptFetchStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TranscriptFetchUiState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TranscriptFetchUiState create(Ref ref) {
    final argument = this.argument as String;
    return transcriptFetchStatus(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptFetchUiState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptFetchUiState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptFetchStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transcriptFetchStatusHash() =>
    r'71cb44d2b90c1ab8b5689eea0b14a6c362c01a53';

/// Read-only alias for widgets that only need fetch status.

final class TranscriptFetchStatusFamily extends $Family
    with $FunctionalFamilyOverride<TranscriptFetchUiState, String> {
  TranscriptFetchStatusFamily._()
    : super(
        retry: null,
        name: r'transcriptFetchStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Read-only alias for widgets that only need fetch status.

  TranscriptFetchStatusProvider call(String mediaId) =>
      TranscriptFetchStatusProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'transcriptFetchStatusProvider';
}
