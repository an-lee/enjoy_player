// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_blur_mode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TranscriptBlurMode)
final transcriptBlurModeProvider = TranscriptBlurModeProvider._();

final class TranscriptBlurModeProvider
    extends $NotifierProvider<TranscriptBlurMode, bool> {
  TranscriptBlurModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transcriptBlurModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transcriptBlurModeHash();

  @$internal
  @override
  TranscriptBlurMode create() => TranscriptBlurMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$transcriptBlurModeHash() =>
    r'85be5f11da247c04b7ea8cedeee84e7c8ccf63f4';

abstract class _$TranscriptBlurMode extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
