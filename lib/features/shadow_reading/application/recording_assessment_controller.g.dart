// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_assessment_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RecordingAssessmentController)
final recordingAssessmentControllerProvider =
    RecordingAssessmentControllerFamily._();

final class RecordingAssessmentControllerProvider
    extends
        $NotifierProvider<
          RecordingAssessmentController,
          RecordingAssessmentUiState
        > {
  RecordingAssessmentControllerProvider._({
    required RecordingAssessmentControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recordingAssessmentControllerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recordingAssessmentControllerHash();

  @override
  String toString() {
    return r'recordingAssessmentControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RecordingAssessmentController create() => RecordingAssessmentController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecordingAssessmentUiState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecordingAssessmentUiState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RecordingAssessmentControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recordingAssessmentControllerHash() =>
    r'a7673c5f390df77aef760fef66942f09a9ff54c3';

final class RecordingAssessmentControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          RecordingAssessmentController,
          RecordingAssessmentUiState,
          RecordingAssessmentUiState,
          RecordingAssessmentUiState,
          String
        > {
  RecordingAssessmentControllerFamily._()
    : super(
        retry: null,
        name: r'recordingAssessmentControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  RecordingAssessmentControllerProvider call(String recordingId) =>
      RecordingAssessmentControllerProvider._(
        argument: recordingId,
        from: this,
      );

  @override
  String toString() => r'recordingAssessmentControllerProvider';
}

abstract class _$RecordingAssessmentController
    extends $Notifier<RecordingAssessmentUiState> {
  late final _$args = ref.$arg as String;
  String get recordingId => _$args;

  RecordingAssessmentUiState build(String recordingId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<RecordingAssessmentUiState, RecordingAssessmentUiState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                RecordingAssessmentUiState,
                RecordingAssessmentUiState
              >,
              RecordingAssessmentUiState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
