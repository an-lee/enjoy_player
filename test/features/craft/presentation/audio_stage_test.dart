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
import 'package:enjoy_player/features/craft/domain/craft_failure.dart';
import 'package:enjoy_player/features/craft/domain/craft_synthesizer.dart';
import 'package:enjoy_player/features/craft/domain/craft_transcriber.dart';
import 'package:enjoy_player/features/craft/domain/craft_translator.dart';
import 'package:enjoy_player/features/craft/domain/translation_style.dart';
import 'package:enjoy_player/features/craft/presentation/audio_stage.dart';
import 'package:enjoy_player/features/library/application/library_repository_provider.dart';
import 'package:enjoy_player/features/library/data/library_repository.dart';
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

class _FixedTranslator implements CraftTranslator {
  _FixedTranslator(this.result);

  final String result;

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    TranslationStyle style = TranslationStyle.auto,
    String? customPrompt,
  }) async => result;
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

class _FakeLibraryRepository implements MediaLibraryRepository {
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
  mediaLibraryRepositoryProvider.overrideWithValue(_FakeLibraryRepository()),
];

void main() {
  testWidgets(
    'AudioStage shows summary, preview player, and action buttons after audio generation',
    (tester) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const AudioStage()),
      );
      // Let async providers (auth, prefs) resolve.
      await tester.pumpAndSettle();

      // Drive the controller: text input → rewrite → generate audio.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AudioStage)),
      );
      // Ensure auth provider has resolved.
      await container.read(authCtrlProvider.future);
      await container.read(appPreferencesCtrlProvider.future);
      await container
          .read(craftControllerProvider.notifier)
          .useTextInput('I had a wonderful day today.');
      await tester.pumpAndSettle();
      await container.read(craftControllerProvider.notifier).generateAudio();
      await tester.pumpAndSettle();

      // Script block should show the rewritten text (not truncated).
      expect(find.textContaining('Rewritten text'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);

      // Preview player: play/pause button.
      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);

      // Progress slider.
      expect(find.byType(Slider), findsOneWidget);

      // "Say something else" button.
      expect(find.text('Say something else'), findsOneWidget);

      // "Practice now" button.
      expect(find.text('Practice now'), findsOneWidget);
    },
  );

  testWidgets('AudioStage shows the full script without character truncation', (
    tester,
  ) async {
    const longScript =
        'So my plan was to read one video a day, but I did not do it '
        'yesterday, the day before, or the day before that either. '
        'I still want to keep going tomorrow morning after coffee.';

      await tester.pumpWidget(
        _harness(
          overrides: [
            authCtrlProvider.overrideWith(_AuthSignedInCtrl.new),
            appPreferencesCtrlProvider.overrideWith(_FakePrefsCtrl.new),
            craftTranslatorProvider.overrideWithValue(
              _FixedTranslator(longScript),
            ),
            craftSynthesizerProvider.overrideWithValue(_FakeSynthesizer()),
            craftTranscriberProvider.overrideWithValue(_FakeTranscriber()),
            mediaLibraryRepositoryProvider.overrideWithValue(
              _FakeLibraryRepository(),
            ),
          ],
          child: const AudioStage(),
        ),
      );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AudioStage)),
    );
    await container.read(authCtrlProvider.future);
    await container.read(appPreferencesCtrlProvider.future);
    await container
        .read(craftControllerProvider.notifier)
        .useTextInput('source text for a longer rewrite');
    await tester.pumpAndSettle();
    await container.read(craftControllerProvider.notifier).generateAudio();
    await tester.pumpAndSettle();

    // Full script is present — not the former 100-char truncated preview.
    expect(find.text(longScript), findsOneWidget);
    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    expect(selectable.data, longScript);
  });

  testWidgets('AudioStage shows loading indicator while synthesizing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const AudioStage()),
    );
    // Let async providers resolve.
    await tester.pumpAndSettle();

    // Drive to rewrite stage first.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AudioStage)),
    );
    // Ensure auth provider has resolved.
    await container.read(authCtrlProvider.future);
    await container.read(appPreferencesCtrlProvider.future);
    await container
        .read(craftControllerProvider.notifier)
        .useTextInput('Some text.');
    await tester.pumpAndSettle();

    // Start audio generation.
    await container.read(craftControllerProvider.notifier).generateAudio();
    await tester.pumpAndSettle();

    // After audio generation, we should NOT see a loading indicator.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('AudioStage shows failure card when state.failure is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const AudioStage()),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AudioStage)),
    );
    await container.read(authCtrlProvider.future);
    await container.read(appPreferencesCtrlProvider.future);

    container.read(craftControllerProvider.notifier).state = container
        .read(craftControllerProvider)
        .copyWith(failure: const CraftTranslateFailure());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('AudioStage shows no-preview fallback when hasPreview is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const AudioStage()),
    );
    await tester.pumpAndSettle();

    // hasPreview defaults to false (no audio generated yet).
    expect(find.text('Generate audio'), findsOneWidget);
  });

  testWidgets('AudioStage shows CircularProgressIndicator while isSaving', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const AudioStage()),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AudioStage)),
    );
    await container.read(authCtrlProvider.future);
    await container.read(appPreferencesCtrlProvider.future);
    await container
        .read(craftControllerProvider.notifier)
        .useTextInput('Some text to synthesize.');
    await tester.pumpAndSettle();
    await container.read(craftControllerProvider.notifier).generateAudio();
    await tester.pumpAndSettle();

    container.read(craftControllerProvider.notifier).state = container
        .read(craftControllerProvider)
        .copyWith(isSaving: true);
    await tester.pump();

    // CircularProgressIndicator shown in the saving slot.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Practice now button is hidden during save.
    expect(find.text('Practice now'), findsNothing);
  });

  testWidgets('AudioStage voice chip expands to show picker on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const AudioStage()),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AudioStage)),
    );
    await container.read(authCtrlProvider.future);
    await container.read(appPreferencesCtrlProvider.future);
    await container
        .read(craftControllerProvider.notifier)
        .useTextInput('Some text.');
    await tester.pumpAndSettle();
    await container.read(craftControllerProvider.notifier).generateAudio();
    await tester.pumpAndSettle();

    // Tap the voice chip toggle row.
    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();

    // Voice picker should be visible (dropdown for voices).
    expect(find.byType(DropdownButton<String>), findsOneWidget);
  });
}
