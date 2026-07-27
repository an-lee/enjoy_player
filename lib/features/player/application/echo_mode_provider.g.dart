// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'echo_mode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EchoMode)
final echoModeProvider = EchoModeProvider._();

final class EchoModeProvider extends $NotifierProvider<EchoMode, EchoState> {
  EchoModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'echoModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$echoModeHash();

  @$internal
  @override
  EchoMode create() => EchoMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EchoState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EchoState>(value),
    );
  }
}

String _$echoModeHash() => r'ec062e1ba5b5e71353ea1590a01804473a36435c';

abstract class _$EchoMode extends $Notifier<EchoState> {
  EchoState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<EchoState, EchoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EchoState, EchoState>,
              EchoState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
