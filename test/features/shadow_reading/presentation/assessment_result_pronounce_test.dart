import 'dart:convert';

import 'package:azure_speech/azure_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';
import 'package:enjoy_player/features/pronounce/presentation/pronounce_icon_button.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/assessment_result_dialog.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

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
        }
      ]
    }
  ]
}''';

AzurePronunciationAssessmentResult _parse(String json) {
  return AzurePronunciationAssessmentResult.fromJson(
    jsonDecode(json) as Map<String, dynamic>,
  );
}

class _TrackingPlaybackController extends PronouncePlaybackController {
  int stopCount = 0;

  @override
  PronouncePlaybackState build() => const PronouncePlaybackState.idle();

  @override
  Future<void> stop() async {
    stopCount++;
    state = const PronouncePlaybackState.idle();
  }
}

Widget _wrap(Widget child, {_TrackingPlaybackController? playback}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
  return ProviderScope(
    overrides: [
      if (playback != null)
        pronouncePlaybackControllerProvider.overrideWith(() => playback),
    ],
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
        body: Center(child: SizedBox(width: 800, height: 600, child: child)),
      ),
    ),
  );
}

void main() {
  late AppLocalizations l10n;
  late _TrackingPlaybackController playback;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    playback = _TrackingPlaybackController();
  });

  testWidgets('selected-word panel shows pronounce only when selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AssessmentResultDialog(
          assessment: _parse(_kBaseJson),
          localeTag: 'en-US',
        ),
        playback: playback,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PronounceIconButton), findsNothing);

    await tester.tap(find.text('hi').first);
    await tester.pumpAndSettle();

    expect(find.byType(PronounceIconButton), findsOneWidget);
    expect(find.text(l10n.assessmentAccuracyScore), findsOneWidget);
  });

  testWidgets('chip change stops playback', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AssessmentResultDialog(
          assessment: _parse(_kBaseJson),
          localeTag: 'en-US',
        ),
        playback: playback,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('hi').first);
    await tester.pumpAndSettle();
    final afterSelect = playback.stopCount;

    await tester.tap(find.text('there').first);
    await tester.pumpAndSettle();

    expect(playback.stopCount, greaterThan(afterSelect));
    expect(find.byType(PronounceIconButton), findsOneWidget);
  });
}
