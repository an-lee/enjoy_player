import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/craft/application/craft_controller.dart';
import 'package:enjoy_player/features/craft/domain/craft_synthesizer.dart';
import 'package:enjoy_player/features/craft/domain/craft_transcriber.dart';
import 'package:enjoy_player/features/craft/domain/craft_translator.dart';
import 'package:enjoy_player/features/craft/domain/translation_style.dart';
import 'package:enjoy_player/features/craft/presentation/rewrite_stage.dart';
import 'package:enjoy_player/features/craft/presentation/voice_picker.dart';
import 'package:enjoy_player/features/craft/application/craft_library_repository_provider.dart';
import 'package:enjoy_player/features/craft/data/craft_library_repository.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

// === Fakes ===

class _AuthSignedInCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'test-user', email: 't@example.com', name: 'Test'),
  );
}

class _FakePrefsCtrl extends AppPreferencesCtrl {
  @override
  Future<AppPreferencesState> build() async => const AppPreferencesState(
    locale: Locale('en'),
    learningLanguage: 'en-US',
    nativeLanguage: 'zh-CN',
  );
}

class _FakeTranslator implements CraftTranslator {
  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    TranslationStyle style = TranslationStyle.auto,
    String? customPrompt,
  }) async => 'Rewritten text in target language.';
}

class _FakeSynthesizer implements CraftSynthesizer {
  @override
  Future<CraftSynthesisResult> synthesize({
    required String text,
    required String language,
    String? voice,
  }) async => CraftSynthesisResult(
    audioBytes: Uint8List.fromList(const [1, 2, 3, 4]),
    format: 'wav',
    wordBoundaries: const [],
  );
}

class _FakeTranscriber implements CraftTranscriber {
  @override
  Future<String> transcribe({
    required Uint8List audioBytes,
    String? language,
  }) async => 'I had a great day today.';
}

class _FakeLibraryRepository implements CraftLibraryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// === Harness ===

Widget _harness({required List<Override> overrides, required Widget child}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

List<Override> _baseOverrides() => [
  authCtrlProvider.overrideWith(_AuthSignedInCtrl.new),
  appPreferencesCtrlProvider.overrideWith(_FakePrefsCtrl.new),
  craftTranslatorProvider.overrideWithValue(_FakeTranslator()),
  craftSynthesizerProvider.overrideWithValue(_FakeSynthesizer()),
  craftTranscriberProvider.overrideWithValue(_FakeTranscriber()),
  craftLibraryRepositoryProvider.overrideWithValue(_FakeLibraryRepository()),
];

void main() {
  testWidgets(
    'RewriteStage shows raw transcript and editable target text after rewrite',
    (tester) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const RewriteStage()),
      );

      // Drive the controller into the rewrite stage via text input.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RewriteStage)),
      );
      await container
          .read(craftControllerProvider.notifier)
          .useTextInput('I had a wonderful day today.');
      await tester.pumpAndSettle();

      // Native + target cards.
      expect(find.text('Your words'), findsOneWidget);
      expect(find.text('I had a wonderful day today.'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));

      // The rewritten text should appear.
      expect(find.text('Rewritten text in target language.'), findsOneWidget);

      // Style + voice options are always visible.
      expect(find.text('Style'), findsOneWidget);
      expect(find.byType(DropdownButton<TranslationStyle>), findsOneWidget);
    },
  );

  testWidgets('RewriteStage shows action buttons', (tester) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const RewriteStage()),
    );

    // Drive into rewrite stage.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RewriteStage)),
    );
    await container
        .read(craftControllerProvider.notifier)
        .useTextInput('Some text to rewrite.');
    await tester.pumpAndSettle();

    // Generate audio button.
    expect(find.text('Generate audio'), findsOneWidget);

    // Re-record button.
    expect(find.text('Re-record'), findsOneWidget);

    // Regenerate button.
    expect(find.text('Regenerate'), findsOneWidget);
  });

  testWidgets('RewriteStage shows voice picker before generate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const RewriteStage()),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RewriteStage)),
    );
    await container
        .read(craftControllerProvider.notifier)
        .useTextInput('Some text to rewrite.');
    await tester.pumpAndSettle();

    expect(find.byType(VoicePicker), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
    expect(container.read(craftControllerProvider).selectedVoice, isNotNull);
  });

  testWidgets('RewriteStage style and voice pickers are always visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const RewriteStage()),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RewriteStage)),
    );
    await container
        .read(craftControllerProvider.notifier)
        .useTextInput('Some text to rewrite.');
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<TranslationStyle>), findsOneWidget);
    expect(find.byType(VoicePicker), findsOneWidget);
  });

  testWidgets(
    'RewriteStage shows Re-translate after native edit and updates target',
    (tester) async {
      final translator = _CountingTranslator();
      await tester.pumpWidget(
        _harness(
          overrides: [
            authCtrlProvider.overrideWith(_AuthSignedInCtrl.new),
            appPreferencesCtrlProvider.overrideWith(_FakePrefsCtrl.new),
            craftTranslatorProvider.overrideWithValue(translator),
            craftSynthesizerProvider.overrideWithValue(_FakeSynthesizer()),
            craftTranscriberProvider.overrideWithValue(_FakeTranscriber()),
            craftLibraryRepositoryProvider.overrideWithValue(
              _FakeLibraryRepository(),
            ),
          ],
          child: const RewriteStage(),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(RewriteStage)),
      );
      await container
          .read(craftControllerProvider.notifier)
          .useTextInput('I had a wonderful day today.');
      await tester.pumpAndSettle();

      expect(find.text('Re-translate'), findsNothing);
      expect(translator.callCount, 1);

      // Edit the native STT field (first TextField).
      await tester.enterText(
        find.byType(TextField).first,
        'I had a wonderful day yesterday instead.',
      );
      await tester.pumpAndSettle();

      expect(find.text('Re-translate'), findsOneWidget);
      expect(
        container.read(craftControllerProvider).isRawTranscriptDirty,
        isTrue,
      );

      await tester.tap(find.text('Re-translate'));
      await tester.pumpAndSettle();

      expect(translator.callCount, 2);
      expect(translator.lastText, 'I had a wonderful day yesterday instead.');
      expect(
        container.read(craftControllerProvider).isRawTranscriptDirty,
        isFalse,
      );
      expect(find.text('Re-translate'), findsNothing);
      expect(find.textContaining('rewrite #2'), findsOneWidget);
    },
  );
}

class _CountingTranslator implements CraftTranslator {
  int callCount = 0;
  String? lastText;

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    TranslationStyle style = TranslationStyle.auto,
    String? customPrompt,
  }) async {
    callCount++;
    lastText = text;
    return 'Rewritten text in target language rewrite #$callCount.';
  }
}
