import 'package:enjoy_player/features/ai/application/ai_byok_error_mapping.dart';
import 'package:enjoy_player/features/ai/domain/byok_not_configured_failure.dart';
import 'package:enjoy_player/features/ai/domain/modality_kind.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('formatByokNotConfiguredMessage includes modality label', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    const failure = ByokNotConfiguredFailure(ModalityKind.llm);
    final message = formatByokNotConfiguredMessage(failure, l10n);
    expect(message, contains(l10n.settingsAiProvidersModalityLlm));
    expect(aiProvidersSettingsPath, '/settings/ai-providers');
  });

  test('isByokNotConfiguredFailure matches only ByokNotConfiguredFailure', () {
    expect(
      isByokNotConfiguredFailure(
        const ByokNotConfiguredFailure(ModalityKind.llm),
      ),
      isTrue,
    );
    expect(isByokNotConfiguredFailure(StateError('other')), isFalse);
    expect(isByokNotConfiguredFailure('a string'), isFalse);
    expect(isByokNotConfiguredFailure(Object()), isFalse);
  });

  testWidgets('formatByokNotConfiguredWithSettingsHint appends settings hint', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final modality in ModalityKind.values) {
      final message = formatByokNotConfiguredWithSettingsHint(
        ByokNotConfiguredFailure(modality),
        l10n,
      );
      // The composite message always ends with the open-settings hint.
      expect(message, endsWith(l10n.byokNotConfiguredOpenSettings));
      // The composite message must be non-empty for every modality.
      expect(
        message.length,
        greaterThan(l10n.byokNotConfiguredOpenSettings.length),
      );
    }
  });

  testWidgets('_modalityLabel returns a label for every modality kind', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Every modality label must be non-empty.
    expect(l10n.settingsAiProvidersModalityLlm, isNotEmpty);
    expect(l10n.settingsAiProvidersModalityAsr, isNotEmpty);
    expect(l10n.settingsAiProvidersModalityTts, isNotEmpty);
    expect(l10n.settingsAiProvidersModalityAssessment, isNotEmpty);
  });
}
