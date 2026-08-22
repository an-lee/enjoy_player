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
import 'package:enjoy_player/features/craft/domain/craft_translator.dart';
import 'package:enjoy_player/features/craft/domain/translation_style.dart';
import 'package:enjoy_player/features/craft/presentation/advanced_tools.dart';
import 'package:enjoy_player/features/craft/presentation/synthesize_tool.dart';
import 'package:enjoy_player/features/craft/presentation/translate_tool.dart';
import 'package:enjoy_player/features/craft/application/craft_library_repository_provider.dart';
import 'package:enjoy_player/features/craft/data/craft_library_repository.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

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

class _FakeLibraryRepository implements CraftLibraryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _harness({required List<Override> overrides, required Widget child}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
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
  testWidgets('AdvancedTools shows both TranslateTool and SynthesizeTool', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const AdvancedTools()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TranslateTool), findsOneWidget);
    expect(find.byType(SynthesizeTool), findsOneWidget);
  });

  testWidgets('AdvancedTools stacks Translate above Synthesize', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(overrides: _baseOverrides(), child: const AdvancedTools()),
    );
    await tester.pumpAndSettle();

    final translateCenter = tester.getCenter(find.byType(TranslateTool));
    final synthCenter = tester.getCenter(find.byType(SynthesizeTool));
    expect(synthCenter.dy > translateCenter.dy, isTrue);
  });
}
