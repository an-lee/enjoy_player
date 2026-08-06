import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:azure_speech/azure_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/audio/recording_preview_player.dart';
import 'package:enjoy_player/core/audio/recording_preview_player_provider.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/assessment_result_dialog.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

const _kBaseJson = '''
{
  "RecognitionStatus": "Success",
  "Offset": 0,
  "Duration": 20000000,
  "DisplayText": "Hi there.",
  "NBest": [
    {
      "Confidence": 0.9,
      "Lexical": "hi there",
      "ITN": "hi there",
      "MaskedITN": "hi there",
      "Display": "Hi there.",
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

class _TrackingPronounce extends PronouncePlaybackController {
  int stopCount = 0;

  @override
  PronouncePlaybackState build() => const PronouncePlaybackState.idle();

  @override
  Future<void> stop() async {
    stopCount++;
    if (!ref.mounted) return;
    state = const PronouncePlaybackState.idle();
  }
}

class _PreviewStub implements RecordingPreviewPlayback {
  int playCount = 0;
  int stopCount = 0;
  String? lastPlayPath;
  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();

  @override
  String? loadedPath;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Future<void> play(String path) async {
    playCount++;
    lastPlayPath = path;
    loadedPath = path;
    _playing.add(true);
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> playClip(String path, Duration start, Duration end) async {
    loadedPath = path;
    _playing.add(true);
  }

  @override
  Future<void> playOrPauseTake(String path) async {
    await play(path);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    loadedPath = null;
    _playing.add(false);
  }

  @override
  Future<void> dispose() async {
    await _playing.close();
    await _position.close();
    await _duration.close();
  }
}

Widget _wrap(
  Widget child, {
  required _PreviewStub preview,
  _TrackingPronounce? playback,
}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
  return ProviderScope(
    overrides: [
      recordingPreviewPlayerProvider.overrideWithValue(preview),
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
  late _PreviewStub preview;
  late _TrackingPronounce pronounce;
  late Directory tmpDir;
  late File takeFile;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    preview = _PreviewStub();
    pronounce = _TrackingPronounce();
    tmpDir = Directory.systemTemp.createTempSync('enjoy_assess_take_');
    takeFile = File('${tmpDir.path}/take.wav')..writeAsBytesSync(const [0]);
  });

  tearDown(() {
    if (tmpDir.existsSync()) {
      tmpDir.deleteSync(recursive: true);
    }
  });

  testWidgets('full-take control disabled without recordingPath', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AssessmentResultDialog(
          assessment: _parse(_kBaseJson),
          localeTag: 'en-US',
        ),
        preview: preview,
        playback: pronounce,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(l10n.assessmentRecordingUnavailable), findsOneWidget);
    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.play_arrow_rounded),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('play full take invokes preview and stops pronounce', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AssessmentResultDialog(
          assessment: _parse(_kBaseJson),
          localeTag: 'en-US',
          recordingPath: takeFile.path,
        ),
        preview: preview,
        playback: pronounce,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l10n.assessmentPlayMyRecording));
    await tester.pumpAndSettle();

    expect(preview.playCount, 1);
    expect(preview.lastPlayPath, takeFile.path);
    expect(pronounce.stopCount, greaterThan(0));
    expect(find.byTooltip(l10n.assessmentStopMyRecording), findsOneWidget);
  });

  testWidgets('dispose stops preview', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AssessmentResultDialog(
          assessment: _parse(_kBaseJson),
          localeTag: 'en-US',
          recordingPath: takeFile.path,
        ),
        preview: preview,
        playback: pronounce,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.assessmentPlayMyRecording));
    await tester.pumpAndSettle();
    expect(preview.playCount, 1);
    final afterPlay = preview.stopCount;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(preview.stopCount, greaterThan(afterPlay));
  });
}
