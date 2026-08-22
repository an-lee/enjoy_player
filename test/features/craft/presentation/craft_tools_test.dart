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
import 'package:enjoy_player/features/craft/domain/craft_translator.dart';
import 'package:enjoy_player/features/craft/domain/translation_style.dart';
import 'package:enjoy_player/features/craft/presentation/synthesize_tool.dart';
import 'package:enjoy_player/features/craft/presentation/translate_tool.dart';
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
    TranslationStyle style = TranslationStyle.natural,
    String? customPrompt,
  }) async => 'translated result';
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

/// Minimal fake that satisfies the provider type without a real DB.
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
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

List<Override> _baseOverrides() => [
  authCtrlProvider.overrideWith(_AuthSignedInCtrl.new),
  appPreferencesCtrlProvider.overrideWith(_FakePrefsCtrl.new),
  craftTranslatorProvider.overrideWithValue(_FakeTranslator()),
  craftSynthesizerProvider.overrideWithValue(_FakeSynthesizer()),
  craftLibraryRepositoryProvider.overrideWithValue(_FakeLibraryRepository()),
];

void main() {
  group('TranslateTool', () {
    testWidgets('renders title, language row, style picker, and input', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const TranslateTool()),
      );
      await tester.pumpAndSettle();

      // Title and button both say "Translate".
      expect(find.text('Translate'), findsNWidgets(2));

      // Language labels.
      expect(find.text('Source language'), findsOneWidget);
      expect(find.text('Learning language'), findsOneWidget);

      // Style picker label.
      expect(find.text('Style'), findsOneWidget);

      // Source text field label.
      expect(find.text('Source text'), findsOneWidget);

      // Swap button.
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);

      // Paste button in the source text field.
      expect(find.byIcon(Icons.paste_rounded), findsOneWidget);
    });

    testWidgets('translate button is disabled when source text is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const TranslateTool()),
      );
      await tester.pumpAndSettle();

      // Find the FilledButton with the translate icon.
      final button = find.widgetWithIcon(FilledButton, Icons.translate_rounded);
      expect(button, findsOneWidget);

      // The button should be disabled (onPressed is null).
      final filledButton = tester.widget<FilledButton>(button);
      expect(filledButton.onPressed, isNull);
    });

    testWidgets('entering text enables the translate button', (tester) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const TranslateTool()),
      );
      await tester.pumpAndSettle();

      // Enter text into the source field.
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Hello world, this is a test sentence');
      await tester.pumpAndSettle();

      // The translate button should now be enabled.
      final button = find.widgetWithIcon(FilledButton, Icons.translate_rounded);
      final filledButton = tester.widget<FilledButton>(button);
      expect(filledButton.onPressed, isNotNull);
    });

    testWidgets('shows translated text section after translation', (
      tester,
    ) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Consumer(
                  builder: (context, ref, _) {
                    container = ProviderScope.containerOf(context);
                    return const TranslateTool();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set languages directly to avoid same-language guard.
      final controller = container.read(craftControllerProvider.notifier);
      controller
        ..setSourceLanguage('zh-CN')
        ..setTargetLanguage('en-US')
        ..setSourceText('Hello world, this is a test sentence');
      await tester.pumpAndSettle();

      // Tap translate.
      final button = find.widgetWithIcon(FilledButton, Icons.translate_rounded);
      await tester.tap(button);
      await tester.pumpAndSettle();

      // Translated text section appears.
      expect(find.text('Translated text'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Use translated text'), findsOneWidget);

      // The result text is shown.
      expect(find.text('translated result'), findsOneWidget);
    });

    testWidgets('custom style shows custom prompt field', (tester) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const TranslateTool()),
      );
      await tester.pumpAndSettle();

      // Open the style dropdown and pick "Custom".
      final dropdown = find.byType(DropdownButton<TranslationStyle>);
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Select Custom style.
      await tester.tap(find.text('Custom').last);
      await tester.pumpAndSettle();

      // Custom prompt field should appear with its hint text.
      expect(
        find.text('Enter your custom translation prompt…'),
        findsOneWidget,
      );
    });

    testWidgets('language tiles show uppercase language codes', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Consumer(
                  builder: (context, ref, _) {
                    container = ProviderScope.containerOf(context);
                    return const TranslateTool();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set languages directly.
      final controller = container.read(craftControllerProvider.notifier);
      controller
        ..setSourceLanguage('zh-CN')
        ..setTargetLanguage('en-US');
      await tester.pumpAndSettle();

      expect(find.text('ZH-CN'), findsOneWidget);
      expect(find.text('EN-US'), findsOneWidget);
    });
  });

  group('SynthesizeTool', () {
    testWidgets('renders title, language tile, voice picker, and input', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const SynthesizeTool()),
      );
      await tester.pumpAndSettle();

      // Title and button both say "Synthesize".
      expect(find.text('Synthesize'), findsNWidgets(2));

      // Language tile label.
      expect(find.text('Learning language'), findsOneWidget);

      // Voice picker label.
      expect(find.text('Voice'), findsOneWidget);

      // Text input field label.
      expect(find.text('Text to synthesize'), findsOneWidget);

      // Paste button.
      expect(find.byIcon(Icons.paste_rounded), findsOneWidget);
    });

    testWidgets('synthesize button is disabled when text is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const SynthesizeTool()),
      );
      await tester.pumpAndSettle();

      final button = find.widgetWithIcon(
        FilledButton,
        Icons.record_voice_over_rounded,
      );
      final filledButton = tester.widget<FilledButton>(button);
      expect(filledButton.onPressed, isNull);
    });

    testWidgets('entering text enables the synthesize button', (tester) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const SynthesizeTool()),
      );
      await tester.pumpAndSettle();

      // Enter text.
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Hello world, this is a test sentence');
      await tester.pumpAndSettle();

      // The synthesize button should now be enabled.
      final button = find.widgetWithIcon(
        FilledButton,
        Icons.record_voice_over_rounded,
      );
      final filledButton = tester.widget<FilledButton>(button);
      expect(filledButton.onPressed, isNotNull);
    });

    testWidgets('shows preview and save button after synthesis', (
      tester,
    ) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Consumer(
                  builder: (context, ref, _) {
                    container = ProviderScope.containerOf(context);
                    return const SynthesizeTool();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set text and synthesize directly via the controller.
      final controller = container.read(craftControllerProvider.notifier);
      // Ensure auth is resolved before synthesize (it checks sign-in).
      await container.read(authCtrlProvider.future);
      controller.setSynthText('Hello world, this is a test sentence');
      await tester.pumpAndSettle();
      await controller.synthesize();
      await tester.pumpAndSettle();

      // Preview section appears.
      expect(find.text('Preview'), findsAtLeast(1));

      // Save to library button appears.
      expect(find.text('Save to library'), findsOneWidget);

      // Play button appears.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('shows language code in uppercase', (tester) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const SynthesizeTool()),
      );
      await tester.pumpAndSettle();

      // Default synth language is 'en' → displayed as 'EN'.
      expect(find.text('EN'), findsOneWidget);
    });
  });
}
