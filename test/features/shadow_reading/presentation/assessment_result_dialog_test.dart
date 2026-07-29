// Widget-level coverage for
// lib/features/shadow_reading/presentation/assessment_result_dialog.dart.
//
// The dialog needs an [AzurePronunciationAssessmentResult]; we build it from
// JSON because the azure_speech classes don't expose a public constructor
// in tests (and would otherwise require a live service).
import 'dart:convert';

import 'package:azure_speech/azure_speech.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/assessment_result_dialog.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _kBaseJson = '''
{
  "RecognitionStatus": "Success",
  "Offset": 0,
  "Duration": 10000000,
  "DisplayText": "Hi there friend.",
  "NBest": [
    {
      "Confidence": 0.9,
      "Lexical": "hi there friend",
      "ITN": "hi there friend",
      "MaskedITN": "hi there friend",
      "Display": "Hi there friend.",
      "PronunciationAssessment": {
        "AccuracyScore": 90,
        "FluencyScore": 88,
        "CompletenessScore": 95,
        "PronScore": 91,
        "ProsodyScore": 80
      },
      "Words": [
        {
          "Word": "hi",
          "Offset": 0,
          "Duration": 10000000,
          "PronunciationAssessment": {
            "AccuracyScore": 92,
            "ErrorType": "None"
          }
        },
        {
          "Word": "there",
          "Offset": 10000000,
          "Duration": 10000000,
          "PronunciationAssessment": {
            "AccuracyScore": 88,
            "ErrorType": "Mispronunciation"
          }
        },
        {
          "Word": "friend",
          "Offset": 20000000,
          "Duration": 10000000,
          "PronunciationAssessment": {
            "AccuracyScore": 95,
            "ErrorType": "None"
          }
        }
      ]
    }
  ]
}''';

const _kNoWordsJson = '''
{
  "RecognitionStatus": "Success",
  "Offset": 0,
  "Duration": 10000000,
  "DisplayText": "",
  "NBest": [
    {
      "Confidence": 0.0,
      "Lexical": "",
      "ITN": "",
      "MaskedITN": "",
      "Display": "",
      "PronunciationAssessment": {
        "AccuracyScore": 0,
        "FluencyScore": 0,
        "CompletenessScore": 0,
        "PronScore": 0
      },
      "Words": []
    }
  ]
}''';

const _kEmptyJson = '''
{
  "RecognitionStatus": "Success",
  "Offset": 0,
  "Duration": 0,
  "DisplayText": "",
  "NBest": []
}''';

AzurePronunciationAssessmentResult _parse(String json) {
  return AzurePronunciationAssessmentResult.fromJson(
    jsonDecode(json) as Map<String, dynamic>,
  );
}

Widget _wrap(Widget child, {double width = 800}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: 600, child: child),
        ),
      ),
    ),
  );
}

AssessmentResultDialog _dialog(String json) =>
    AssessmentResultDialog(assessment: _parse(json), localeTag: 'en-US');

late final AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('AssessmentResultDialog renders title and overall score', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_dialog(_kBaseJson)));
    await tester.pumpAndSettle();

    expect(find.byType(AssessmentResultDialog), findsOneWidget);
    expect(find.text(l10n.assessmentTitle), findsOneWidget);
    // Score bars present.
    expect(find.text(l10n.assessmentAccuracy), findsOneWidget);
    expect(find.text(l10n.assessmentCompleteness), findsOneWidget);
    expect(find.text(l10n.assessmentFluency), findsOneWidget);
    expect(find.text(l10n.assessmentProsody), findsOneWidget);
    // Word tiles render.
    expect(find.text('hi'), findsWidgets);
    expect(find.text('there'), findsWidgets);
    expect(find.text('friend'), findsWidgets);
  });

  testWidgets(
    'AssessmentResultDialog tap on a word tile toggles selection state',
    (tester) async {
      await tester.pumpWidget(_wrap(_dialog(_kBaseJson)));
      await tester.pumpAndSettle();

      // Initially, no selected-word panel is shown. Only the chip "hi" is
      // rendered (the word chip in the Wrap).
      final initialHiCount = find.text('hi').evaluate().length;
      expect(initialHiCount, greaterThanOrEqualTo(1));

      // Tap the "hi" word chip — the word itself appears twice (chip +
      // selected-word panel header).
      await tester.tap(find.text('hi').first);
      await tester.pumpAndSettle();

      final selectedHiCount = find.text('hi').evaluate().length;
      expect(
        selectedHiCount,
        greaterThan(initialHiCount),
        reason: 'tapping a word chip should reveal the selected-word panel',
      );

      // The Accuracy score label should now be visible inside the panel.
      expect(find.text(l10n.assessmentAccuracyScore), findsOneWidget);

      // Tap again to deselect.
      await tester.tap(find.text('hi').first);
      await tester.pumpAndSettle();

      final deselectedHiCount = find.text('hi').evaluate().length;
      expect(
        deselectedHiCount,
        initialHiCount,
        reason: 'second tap should hide the selected-word panel',
      );
      expect(find.text(l10n.assessmentAccuracyScore), findsNothing);
    },
  );

  testWidgets(
    'AssessmentResultDialog shows the no-result fallback when nBest is empty',
    (tester) async {
      await tester.pumpWidget(_wrap(_dialog(_kEmptyJson)));
      await tester.pumpAndSettle();

      expect(find.text(l10n.assessmentNoResultSummary), findsOneWidget);
    },
  );

  testWidgets(
    'AssessmentResultDialog close button dismisses via Navigator.pop',
    (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navKey,
            theme: ThemeData(
              colorScheme: scheme,
              extensions: [EnjoyThemeTokens.build(scheme)],
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (ctx) =>
                  Scaffold(body: Center(child: _dialog(_kBaseJson))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the close icon.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      // The dialog should be gone (Navigator popped).
      expect(find.byType(AssessmentResultDialog), findsNothing);
    },
  );

  testWidgets('AssessmentResultDialog handles a result with empty word list', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_dialog(_kNoWordsJson)));
    await tester.pumpAndSettle();

    // Should still render the score bars and title.
    expect(find.text(l10n.assessmentTitle), findsOneWidget);
    expect(find.text(l10n.assessmentAccuracy), findsOneWidget);
  });
}
