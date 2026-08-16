// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_practice_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WordPracticeSettings)
final wordPracticeSettingsProvider = WordPracticeSettingsProvider._();

final class WordPracticeSettingsProvider
    extends $AsyncNotifierProvider<WordPracticeSettings, bool> {
  WordPracticeSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wordPracticeSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wordPracticeSettingsHash();

  @$internal
  @override
  WordPracticeSettings create() => WordPracticeSettings();
}

String _$wordPracticeSettingsHash() =>
    r'cfe00ae0a77bad2c1670357f2e289da9a9f1528f';

abstract class _$WordPracticeSettings extends $AsyncNotifier<bool> {
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
