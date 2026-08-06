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
import 'package:enjoy_player/features/shadow_reading/domain/assessment_word_timing.dart';
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
        "PronScore": 91
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
            "ErrorType": "None"
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

class _PreviewStub implements RecordingPreviewPlayback {
  int playCount = 0;
  int stopCount = 0;
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

  void emitPosition(Duration d) => _position.add(d);

  @override
  Future<void> play(String path) async {
    playCount++;
    loadedPath = path;
    _playing.add(true);
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> playClip(String path, Duration start, Duration end) async {}

  @override
  Future<void> playOrPauseTake(String path) async => play(path);

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

class _SilentPronounce extends PronouncePlaybackController {
  @override
  PronouncePlaybackState build() => const PronouncePlaybackState.idle();

  @override
  Future<void> stop() async {
    if (!ref.mounted) return;
    state = const PronouncePlaybackState.idle();
  }
}

void main() {
  late AppLocalizations l10n;
  late _PreviewStub preview;
  late Directory tmpDir;
  late File takeFile;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    preview = _PreviewStub();
    tmpDir = Directory.systemTemp.createTempSync('enjoy_assess_karaoke_');
    takeFile = File('${tmpDir.path}/take.wav')..writeAsBytesSync(const [0]);
  });

  tearDown(() {
    if (tmpDir.existsSync()) {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('activeWordIndex advances with position (unit)', () {
    final words = _parse(_kBaseJson).nBest.first.words;
    expect(activeWordIndex(words, 0), 0);
    expect(activeWordIndex(words, 1000), 1);
    expect(activeWordIndex(words, 2000), isNull);
  });

  testWidgets('chip select during full take stops preview', (tester) async {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingPreviewPlayerProvider.overrideWithValue(preview),
          pronouncePlaybackControllerProvider.overrideWith(
            _SilentPronounce.new,
          ),
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
            body: Center(
              child: SizedBox(
                width: 800,
                height: 600,
                child: AssessmentResultDialog(
                  assessment: _parse(_kBaseJson),
                  localeTag: 'en-US',
                  recordingPath: takeFile.path,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l10n.assessmentPlayMyRecording));
    await tester.pumpAndSettle();
    expect(preview.playCount, 1);
    final afterPlay = preview.stopCount;

    await tester.tap(find.text('hi').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(preview.stopCount, greaterThan(afterPlay));
  });
}
