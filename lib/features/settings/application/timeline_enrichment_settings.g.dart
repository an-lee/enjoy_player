// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_enrichment_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TimelineEnrichmentSettings)
final timelineEnrichmentSettingsProvider =
    TimelineEnrichmentSettingsProvider._();

final class TimelineEnrichmentSettingsProvider
    extends $AsyncNotifierProvider<TimelineEnrichmentSettings, bool> {
  TimelineEnrichmentSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timelineEnrichmentSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timelineEnrichmentSettingsHash();

  @$internal
  @override
  TimelineEnrichmentSettings create() => TimelineEnrichmentSettings();
}

String _$timelineEnrichmentSettingsHash() =>
    r'848b9a534f8f717ee8cbfb85b1adde6ce0bd9e80';

abstract class _$TimelineEnrichmentSettings extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
