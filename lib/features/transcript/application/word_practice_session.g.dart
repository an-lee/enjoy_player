// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_practice_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WordPracticeSession)
final wordPracticeSessionProvider = WordPracticeSessionFamily._();

final class WordPracticeSessionProvider
    extends $NotifierProvider<WordPracticeSession, WordPracticeState> {
  WordPracticeSessionProvider._({
    required WordPracticeSessionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'wordPracticeSessionProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$wordPracticeSessionHash();

  @override
  String toString() {
    return r'wordPracticeSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WordPracticeSession create() => WordPracticeSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WordPracticeState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WordPracticeState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WordPracticeSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$wordPracticeSessionHash() =>
    r'98e532dd037e657d466514408c411089a230da77';

final class WordPracticeSessionFamily extends $Family
    with
        $ClassFamilyOverride<
          WordPracticeSession,
          WordPracticeState,
          WordPracticeState,
          WordPracticeState,
          String
        > {
  WordPracticeSessionFamily._()
    : super(
        retry: null,
        name: r'wordPracticeSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  WordPracticeSessionProvider call(String mediaId) =>
      WordPracticeSessionProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'wordPracticeSessionProvider';
}

abstract class _$WordPracticeSession extends $Notifier<WordPracticeState> {
  late final _$args = ref.$arg as String;
  String get mediaId => _$args;

  WordPracticeState build(String mediaId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WordPracticeState, WordPracticeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WordPracticeState, WordPracticeState>,
              WordPracticeState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
