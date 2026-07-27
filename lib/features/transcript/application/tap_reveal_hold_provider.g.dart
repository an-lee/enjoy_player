// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tap_reveal_hold_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TapRevealHoldCtrl)
final tapRevealHoldCtrlProvider = TapRevealHoldCtrlFamily._();

final class TapRevealHoldCtrlProvider
    extends $NotifierProvider<TapRevealHoldCtrl, TapRevealHold?> {
  TapRevealHoldCtrlProvider._({
    required TapRevealHoldCtrlFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tapRevealHoldCtrlProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tapRevealHoldCtrlHash();

  @override
  String toString() {
    return r'tapRevealHoldCtrlProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TapRevealHoldCtrl create() => TapRevealHoldCtrl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TapRevealHold? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TapRevealHold?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TapRevealHoldCtrlProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tapRevealHoldCtrlHash() => r'078eb53cd0ac6455faeab06c9a3762fff6293dde';

final class TapRevealHoldCtrlFamily extends $Family
    with
        $ClassFamilyOverride<
          TapRevealHoldCtrl,
          TapRevealHold?,
          TapRevealHold?,
          TapRevealHold?,
          String
        > {
  TapRevealHoldCtrlFamily._()
    : super(
        retry: null,
        name: r'tapRevealHoldCtrlProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TapRevealHoldCtrlProvider call(String mediaId) =>
      TapRevealHoldCtrlProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'tapRevealHoldCtrlProvider';
}

abstract class _$TapRevealHoldCtrl extends $Notifier<TapRevealHold?> {
  late final _$args = ref.$arg as String;
  String get mediaId => _$args;

  TapRevealHold? build(String mediaId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TapRevealHold?, TapRevealHold?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TapRevealHold?, TapRevealHold?>,
              TapRevealHold?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Read-only projection of the current hold. Widgets use this; the
/// notifier is reserved for the tile's tap handler.

@ProviderFor(tapRevealHold)
final tapRevealHoldProvider = TapRevealHoldFamily._();

/// Read-only projection of the current hold. Widgets use this; the
/// notifier is reserved for the tile's tap handler.

final class TapRevealHoldProvider
    extends $FunctionalProvider<TapRevealHold?, TapRevealHold?, TapRevealHold?>
    with $Provider<TapRevealHold?> {
  /// Read-only projection of the current hold. Widgets use this; the
  /// notifier is reserved for the tile's tap handler.
  TapRevealHoldProvider._({
    required TapRevealHoldFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tapRevealHoldProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tapRevealHoldHash();

  @override
  String toString() {
    return r'tapRevealHoldProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TapRevealHold?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TapRevealHold? create(Ref ref) {
    final argument = this.argument as String;
    return tapRevealHold(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TapRevealHold? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TapRevealHold?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TapRevealHoldProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tapRevealHoldHash() => r'6b180b6fcf5a23fe24592aa36b1d81e712ebc97f';

/// Read-only projection of the current hold. Widgets use this; the
/// notifier is reserved for the tile's tap handler.

final class TapRevealHoldFamily extends $Family
    with $FunctionalFamilyOverride<TapRevealHold?, String> {
  TapRevealHoldFamily._()
    : super(
        retry: null,
        name: r'tapRevealHoldProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Read-only projection of the current hold. Widgets use this; the
  /// notifier is reserved for the tile's tap handler.

  TapRevealHoldProvider call(String mediaId) =>
      TapRevealHoldProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'tapRevealHoldProvider';
}
