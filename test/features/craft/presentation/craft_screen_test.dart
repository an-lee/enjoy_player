import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/theme/app_theme.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/craft/application/craft_controller.dart';
import 'package:enjoy_player/features/craft/domain/craft_synthesizer.dart';
import 'package:enjoy_player/features/craft/domain/craft_transcriber.dart';
import 'package:enjoy_player/features/craft/domain/craft_translator.dart';
import 'package:enjoy_player/features/craft/domain/translation_style.dart';
import 'package:enjoy_player/features/craft/presentation/advanced_tools.dart';
import 'package:enjoy_player/features/craft/presentation/craft_screen.dart';
import 'package:enjoy_player/features/craft/presentation/express_flow.dart';
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

Widget _harness({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CraftScreen(),
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
  testWidgets('CraftScreen shows ExpressFlow by default (Express mode)', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(overrides: _baseOverrides()));
    await tester.pumpAndSettle();

    expect(find.byType(ExpressFlow), findsOneWidget);
    expect(find.byType(AdvancedTools), findsNothing);
    expect(find.text('Express'), findsWidgets);
  });

  testWidgets('CraftScreen switches to Advanced mode on tap', (tester) async {
    await tester.pumpWidget(_harness(overrides: _baseOverrides()));
    await tester.pumpAndSettle();

    expect(find.byType(ExpressFlow), findsOneWidget);

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    expect(find.byType(AdvancedTools), findsOneWidget);
    expect(find.byType(ExpressFlow), findsNothing);
  });

  testWidgets('CraftScreen shows both Express and Advanced segmented options', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(overrides: _baseOverrides()));
    await tester.pumpAndSettle();

    // Both mode labels should be visible.
    expect(find.text('Express'), findsWidgets);
    expect(find.text('Advanced'), findsWidgets);

    // Icons for each mode.
    expect(find.byIcon(Icons.mic_rounded), findsWidgets);
    expect(find.byIcon(Icons.edit_note_rounded), findsWidgets);
  });

  testWidgets(
    'CraftScreen asks before switching mode with an unsaved audio preview',
    (tester) async {
      await tester.pumpWidget(_harness(overrides: _baseOverrides()));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CraftScreen)),
      );
      await container.read(authCtrlProvider.future);
      await container.read(appPreferencesCtrlProvider.future);
      await container
          .read(craftControllerProvider.notifier)
          .useTextInput('I had a wonderful day today.');
      await tester.pumpAndSettle();
      await container.read(craftControllerProvider.notifier).generateAudio();
      await tester.pumpAndSettle();

      expect(container.read(craftControllerProvider).hasUnsavedPreview, isTrue);

      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();

      expect(find.text('Discard this audio?'), findsOneWidget);

      // Cancel keeps Express + the unsaved preview.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(ExpressFlow), findsOneWidget);
      expect(container.read(craftControllerProvider).hasUnsavedPreview, isTrue);
    },
  );
}
