// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auto_translate_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AutoTranslateCtrl)
final autoTranslateCtrlProvider = AutoTranslateCtrlFamily._();

final class AutoTranslateCtrlProvider
    extends $NotifierProvider<AutoTranslateCtrl, AutoTranslateUiState> {
  AutoTranslateCtrlProvider._({
    required AutoTranslateCtrlFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'autoTranslateCtrlProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$autoTranslateCtrlHash();

  @override
  String toString() {
    return r'autoTranslateCtrlProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AutoTranslateCtrl create() => AutoTranslateCtrl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutoTranslateUiState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AutoTranslateUiState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AutoTranslateCtrlProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$autoTranslateCtrlHash() => r'298ebe40fb50c5205c7183883fcfe16aad4cafc4';

final class AutoTranslateCtrlFamily extends $Family
    with
        $ClassFamilyOverride<
          AutoTranslateCtrl,
          AutoTranslateUiState,
          AutoTranslateUiState,
          AutoTranslateUiState,
          String
        > {
  AutoTranslateCtrlFamily._()
    : super(
        retry: null,
        name: r'autoTranslateCtrlProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  AutoTranslateCtrlProvider call(String mediaId) =>
      AutoTranslateCtrlProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'autoTranslateCtrlProvider';
}

abstract class _$AutoTranslateCtrl extends $Notifier<AutoTranslateUiState> {
  late final _$args = ref.$arg as String;
  String get mediaId => _$args;

  AutoTranslateUiState build(String mediaId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AutoTranslateUiState, AutoTranslateUiState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AutoTranslateUiState, AutoTranslateUiState>,
              AutoTranslateUiState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Whether [secondaryId] is the auto-translate AI track for [mediaId].

@ProviderFor(isAutoTranslateSecondary)
final isAutoTranslateSecondaryProvider = IsAutoTranslateSecondaryFamily._();

/// Whether [secondaryId] is the auto-translate AI track for [mediaId].

final class IsAutoTranslateSecondaryProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether [secondaryId] is the auto-translate AI track for [mediaId].
  IsAutoTranslateSecondaryProvider._({
    required IsAutoTranslateSecondaryFamily super.from,
    required (String, String?) super.argument,
  }) : super(
         retry: null,
         name: r'isAutoTranslateSecondaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isAutoTranslateSecondaryHash();

  @override
  String toString() {
    return r'isAutoTranslateSecondaryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as (String, String?);
    return isAutoTranslateSecondary(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is IsAutoTranslateSecondaryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isAutoTranslateSecondaryHash() =>
    r'b30ac8a0be47960d06c5b4ff1b767e7f1bf64038';

/// Whether [secondaryId] is the auto-translate AI track for [mediaId].

final class IsAutoTranslateSecondaryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, (String, String?)> {
  IsAutoTranslateSecondaryFamily._()
    : super(
        retry: null,
        name: r'isAutoTranslateSecondaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether [secondaryId] is the auto-translate AI track for [mediaId].

  IsAutoTranslateSecondaryProvider call(String mediaId, String? secondaryId) =>
      IsAutoTranslateSecondaryProvider._(
        argument: (mediaId, secondaryId),
        from: this,
      );

  @override
  String toString() => r'isAutoTranslateSecondaryProvider';
}

/// Predicted AI track id for picker radio value (may not exist in DB yet).

@ProviderFor(autoTranslateSelectionId)
final autoTranslateSelectionIdProvider = AutoTranslateSelectionIdFamily._();

/// Predicted AI track id for picker radio value (may not exist in DB yet).

final class AutoTranslateSelectionIdProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Predicted AI track id for picker radio value (may not exist in DB yet).
  AutoTranslateSelectionIdProvider._({
    required AutoTranslateSelectionIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'autoTranslateSelectionIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$autoTranslateSelectionIdHash();

  @override
  String toString() {
    return r'autoTranslateSelectionIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return autoTranslateSelectionId(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AutoTranslateSelectionIdProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$autoTranslateSelectionIdHash() =>
    r'02d72757d828d04a8b4d9e234e384e115765f169';

/// Predicted AI track id for picker radio value (may not exist in DB yet).

final class AutoTranslateSelectionIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  AutoTranslateSelectionIdFamily._()
    : super(
        retry: null,
        name: r'autoTranslateSelectionIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Predicted AI track id for picker radio value (may not exist in DB yet).

  AutoTranslateSelectionIdProvider call(String mediaId) =>
      AutoTranslateSelectionIdProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'autoTranslateSelectionIdProvider';
}
