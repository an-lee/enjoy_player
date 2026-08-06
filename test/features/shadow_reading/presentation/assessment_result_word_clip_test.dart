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
import 'package:enjoy_player/features/pronounce/presentation/pronounce_icon_button.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/assessment_result_dialog.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

const _kJson = '''
{
  "RecognitionStatus": "Success",
  "Offset": 0,
  "Duration": 30000000,
  "DisplayText": "Hi skip there.",
  "NBest": [
    {
      "Confidence": 0.9,
      "Lexical": "hi skip there",
      "ITN": "hi skip there",
      "MaskedITN": "hi skip there",
      "Display": "Hi skip there.",
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
          "Word": "skip",
          "Offset": 10000000,
          "Duration": 0,
          "PronunciationAssessment": {
            "AccuracyScore": 0,
            "ErrorType": "Omission"
          }
        },
        {
          "Word": "there",
          "Offset": 20000000,
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

class _TrackingPronounce extends PronouncePlaybackController {
  int stopCount = 0;
  int playCount = 0;

  @override
  PronouncePlaybackState build() => const PronouncePlaybackState.idle();

  @override
  Future<void> stop() async {
    stopCount++;
    if (!ref.mounted) return;
    state = const PronouncePlaybackState.idle();
  }

  @override
  Future<void> play(PronounceTarget target) async {
    playCount++;
    state = PronouncePlaybackState(
      phase: PronouncePlaybackPhase.playing,
      target: target,
    );
  }
}

class _PreviewStub implements RecordingPreviewPlayback {
  int playClipCount = 0;
  int stopCount = 0;
  Duration? lastStart;
  Duration? lastEnd;
  String? lastClipPath;
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
    loadedPath = path;
    _playing.add(true);
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> playClip(String path, Duration start, Duration end) async {
    playClipCount++;
    lastClipPath = path;
    lastStart = start;
    lastEnd = end;
    loadedPath = path;
    _playing.add(true);
  }

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
    tmpDir = Directory.systemTemp.createTempSync('enjoy_assess_clip_');
    takeFile = File('${tmpDir.path}/take.wav')..writeAsBytesSync(const [0]);
  });

  tearDown(() {
    if (tmpDir.existsSync()) {
      tmpDir.deleteSync(recursive: true);
    }
  });

  Widget wrap(Widget child) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
    return ProviderScope(
      overrides: [
        recordingPreviewPlayerProvider.overrideWithValue(preview),
        pronouncePlaybackControllerProvider.overrideWith(() => pronounce),
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

  testWidgets('my-clip plays timed bounds and stops pronounce', (tester) async {
    await tester.pumpWidget(
      wrap(
        AssessmentResultDialog(
          assessment: _parse(_kJson),
          localeTag: 'en-US',
          recordingPath: takeFile.path,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('hi').first);
    await tester.pumpAndSettle();

    expect(find.byType(PronounceIconButton), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.assessmentPlayMyClip));
    await tester.pumpAndSettle();

    expect(preview.playClipCount, 1);
    expect(preview.lastClipPath, takeFile.path);
    expect(preview.lastStart, Duration.zero);
    expect(preview.lastEnd, const Duration(milliseconds: 1000));
    expect(pronounce.stopCount, greaterThan(0));
  });

  testWidgets('omission disables my-clip', (tester) async {
    await tester.pumpWidget(
      wrap(
        AssessmentResultDialog(
          assessment: _parse(_kJson),
          localeTag: 'en-US',
          recordingPath: takeFile.path,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('skip').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip(l10n.assessmentClipUnavailable), findsOneWidget);
    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.record_voice_over_rounded),
    );
    expect(button.onPressed, isNull);
  });
}
