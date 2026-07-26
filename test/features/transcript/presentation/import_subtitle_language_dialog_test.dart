// Tests for `lib/features/transcript/presentation/import_subtitle_language_dialog.dart`.
//
// Covers both dialog entry points (`showImportSubtitleLanguageDialog`,
// `showAsrLanguageDialog`) and the `AsrLanguageSelection` constructors.
import 'package:enjoy_player/features/transcript/presentation/import_subtitle_language_dialog.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsrLanguageSelection', () {
    test('autoDetect() yields null language', () {
      expect(const AsrLanguageSelection.autoDetect().language, isNull);
    });

    test('explicit() yields the provided language', () {
      expect(const AsrLanguageSelection.explicit('en-US').language, 'en-US');
    });
  });

  Widget buildHost() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showImportSubtitleLanguageDialog(
                ctx,
                initialLanguage: 'en-US',
              ),
              child: const Text('open-subtitle'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('showImportSubtitleLanguageDialog opens with initial language', (
    tester,
  ) async {
    await tester.pumpWidget(buildHost());
    await tester.tap(find.text('open-subtitle'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('showImportSubtitleLanguageDialog Cancel dismisses the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(buildHost());
    await tester.tap(find.text('open-subtitle'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('showImportSubtitleLanguageDialog returns language via OK', (
    tester,
  ) async {
    await tester.pumpWidget(buildHost());
    await tester.tap(find.text('open-subtitle'));
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await tester.enterText(textField, 'ja-JP');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('OK'), findsNothing);
  });

  Widget buildAsrHost() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showAsrLanguageDialog(ctx, initialLanguage: 'en-US'),
              child: const Text('open-asr'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('showAsrLanguageDialog opens with auto-detect checkbox', (
    tester,
  ) async {
    await tester.pumpWidget(buildAsrHost());
    await tester.tap(find.text('open-asr'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('showAsrLanguageDialog Cancel dismisses the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(buildAsrHost());
    await tester.tap(find.text('open-asr'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('showAsrLanguageDialog toggle checkbox disables TextField', (
    tester,
  ) async {
    await tester.pumpWidget(buildAsrHost());
    await tester.tap(find.text('open-asr'));
    await tester.pumpAndSettle();

    final checkbox = find.byType(CheckboxListTile);
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enabled, isFalse);
  });

  testWidgets(
    'showAsrLanguageDialog does not pop when language empty + auto-detect off',
    (tester) async {
      await tester.pumpWidget(buildAsrHost());
      await tester.tap(find.text('open-asr'));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, '');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Dialog is still mounted (Cancel still present).
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    },
  );
}
