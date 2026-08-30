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
import 'package:enjoy_player/features/craft/presentation/capture_stage.dart';
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
  craftTranscriberProvider.overrideWithValue(_FakeTranscriber()),
  craftLibraryRepositoryProvider.overrideWithValue(_FakeLibraryRepository()),
];

void main() {
  testWidgets(
    'CaptureStage idle state shows mic button, title, and type link',
    (tester) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const CaptureStage()),
      );
      await tester.pumpAndSettle();

      // Mic icon.
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Title.
      expect(find.text("Say what's on your mind"), findsOneWidget);

      // Type instead link.
      expect(find.text('Type instead'), findsOneWidget);
    },
  );

  testWidgets('CaptureStage shows language pair in idle state', (tester) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const CaptureStage()),
    );
    await tester.pumpAndSettle();

    // Language pair seeds from app prefs at build time (native 'zh-CN',
    // learning 'en-US') — the '—' placeholder never renders.
    expect(find.textContaining('EN'), findsWidgets);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('CaptureStage type instead toggles to text input', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const CaptureStage()),
    );
    await tester.pumpAndSettle();

    // Tap "type instead".
    await tester.tap(find.text('Type instead'));
    await tester.pumpAndSettle();

    // TextField should appear.
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
    'CaptureStage stuck isCapturing shows Cancel and Cancel clears flag',
    (tester) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const CaptureStage()),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CaptureStage)),
      );
      // Simulate reopen after ESC left isCapturing true without a live mic.
      container.read(craftControllerProvider.notifier).startCapture();
      await tester.pump();

      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(container.read(craftControllerProvider).isCapturing, isFalse);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    },
  );

  testWidgets('CaptureStage back from text fallback returns to mic idle view', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const CaptureStage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type instead'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    // Back button (label is craftCaptureTitle) returns to idle.
    await tester.tap(find.text("Say what's on your mind"));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });

  testWidgets(
    'CaptureStage text fallback submit calls useTextInput on controller',
    (tester) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const CaptureStage()),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CaptureStage)),
      );

      await tester.tap(find.text('Type instead'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hello world');
      await tester.tap(find.text('Generate audio'));
      await tester.pumpAndSettle();

      expect(
        container.read(craftControllerProvider).sourceText,
        equals('hello world'),
      );
    },
  );

  testWidgets('CaptureStage text fallback submit ignores empty text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const CaptureStage()),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CaptureStage)),
    );

    await tester.tap(find.text('Type instead'));
    await tester.pumpAndSettle();

    // Tap Generate audio without entering text.
    await tester.tap(find.text('Generate audio'));
    await tester.pumpAndSettle();

    expect(container.read(craftControllerProvider).sourceText, isEmpty);
  });

  testWidgets('CaptureStage shows failure card when state.failure is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const CaptureStage()),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CaptureStage)),
    );

    container.read(craftControllerProvider.notifier).state = container
        .read(craftControllerProvider)
        .copyWith(failure: const CraftTranslateFailure());
    await tester.pumpAndSettle();

    // Failure card icon.
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    // The retry button label is "Retry" for CraftFailureAction.retry.
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('CaptureStage failure card sign-in action shows sign-in button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const CaptureStage()),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CaptureStage)),
    );

    container.read(craftControllerProvider.notifier).state = container
        .read(craftControllerProvider)
        .copyWith(failure: const CraftSignInRequiredFailure());
    await tester.pumpAndSettle();

    expect(find.text('Sign in to use Craft'), findsWidgets);
  });

  testWidgets(
    'CaptureStage shows transcribing indicator when state.isTranscribing',
    (tester) async {
      await tester.pumpWidget(
        _harness(overrides: _baseOverrides(), child: const CaptureStage()),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CaptureStage)),
      );

      container.read(craftControllerProvider.notifier).state = container
          .read(craftControllerProvider)
          .copyWith(isTranscribing: true);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Transcribing label.
      expect(find.text('Transcribing…'), findsOneWidget);
    },
  );
}
