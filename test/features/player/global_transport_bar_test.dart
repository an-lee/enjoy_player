import 'dart:convert';

import 'package:drift/native.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_state_providers.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/presentation/widgets/global_transport_bar.dart';
import 'package:enjoy_player/features/transcript/application/all_transcripts_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_fetch_controller.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_fetch_status.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_track.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_player_engine.dart';

const _kMediaId = 'transport-bar-test';

PlaybackSession _testSession() {
  final now = DateTime(2026, 1, 1);
  return PlaybackSession(
    mediaId: _kMediaId,
    dexieTargetType: 'Audio',
    mediaType: 'audio',
    mediaTitle: 'Transport test',
    durationSeconds: 120,
    currentTimeSeconds: 0,
    currentSegmentIndex: 0,
    language: 'en',
    startedAt: now,
    lastActiveAt: now,
  );
}

class _SessionPlayerController extends PlayerController {
  _SessionPlayerController(this._session);

  final PlaybackSession _session;

  @override
  PlaybackSession? build() => _session;
}

class _BlurMode extends TranscriptBlurMode {
  _BlurMode(this._initial);
  final bool _initial;

  @override
  bool build() => _initial;
}

Future<void> _seedTranscript(AppDatabase db) async {
  final now = DateTime(2026, 1, 1);
  const transcriptId = 'tr-transport';
  await db.audioDao.insertRow(
    AudioRow(
      id: _kMediaId,
      aid: 'f',
      provider: 'user',
      title: 't',
      description: null,
      thumbnailUrl: null,
      durationSeconds: 120,
      language: 'en',
      translationKey: null,
      sourceText: null,
      voice: null,
      source: null,
      localUri: 'file:///a.mp3',
      md5: null,
      size: 1,
      mediaUrl: null,
      syncStatus: null,
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.transcriptDao.upsert(
    TranscriptRow(
      id: transcriptId,
      targetType: 'Audio',
      targetId: _kMediaId,
      language: 'en',
      source: 'user',
      timelineJson: jsonEncode([
        const TranscriptLine(
          text: 'hello',
          startMs: 0,
          durationMs: 1000,
        ).toJson(),
      ]),
      referenceId: null,
      label: 'en',
      trackIndex: null,
      syncStatus: null,
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.echoSessionDao.upsert(
    EchoSessionRow(
      id: 'echo-transport',
      targetType: 'Audio',
      targetId: _kMediaId,
      language: 'und',
      currentTimeMs: 0,
      playbackRate: 1,
      volume: 1,
      echoStartMs: null,
      echoEndMs: null,
      transcriptId: transcriptId,
      secondaryTranscriptId: null,
      recordingsCount: 0,
      recordingsDurationMs: 0,
      lastRecordingAt: null,
      currentSegmentIndex: -1,
      echoActive: false,
      echoStartLine: -1,
      echoEndLine: -1,
      blurActive: false,
      startedAt: now,
      lastActiveAt: now,
      completedAt: null,
      syncStatus: null,
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

List<Override> _transportOverrides({
  required FakePlayerEngine fake,
  required AppDatabase db,
  bool hasLines = true,
  bool blurActive = false,
}) {
  return [
    appDatabaseProvider.overrideWithValue(db),
    playerEngineTestDoubleProvider.overrideWithValue(fake),
    playerControllerProvider.overrideWith(
      () => _SessionPlayerController(_testSession()),
    ),
    transcriptHasLinesForMediaProvider(
      _kMediaId,
    ).overrideWith((ref) => Stream.value(hasLines)),
    playerIsPlayingProvider.overrideWith((ref) => Stream.value(false)),
    playerIsBufferingProvider.overrideWith((ref) => Stream.value(false)),
    allTranscriptsForMediaProvider(
      _kMediaId,
    ).overrideWith((ref) => Stream.value(const <TranscriptTrack>[])),
    transcriptFetchCtrlProvider(_kMediaId).overrideWithValue(
      const TranscriptFetchUiState(status: TranscriptFetchStatus.idle),
    ),
    transcriptBlurModeProvider.overrideWith(() => _BlurMode(blurActive)),
  ];
}

Widget _transportHarness({
  required GoRouter router,
  required List<Override> overrides,
  required double width,
}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: ThemeData(
        colorScheme: scheme,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(size: Size(width, 800)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );
}

GoRouter _playerRouter() {
  return GoRouter(
    initialLocation: '/player/$_kMediaId',
    routes: [
      GoRoute(
        path: '/player/:mediaId',
        builder: (_, _) => const Scaffold(
          bottomNavigationBar: GlobalTransportBar(),
          body: SizedBox.shrink(),
        ),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePlayerEngine fake;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    fake = FakePlayerEngine();
  });

  tearDown(() async {
    await db.close();
    await fake.dispose();
  });

  Future<void> pumpTransport(
    WidgetTester tester, {
    required GoRouter router,
    required double width,
    bool hasLines = true,
    bool blurActive = false,
    bool seedTranscript = false,
  }) async {
    if (seedTranscript) {
      await _seedTranscript(db);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(router.dispose);
    await tester.pumpWidget(
      _transportHarness(
        router: router,
        overrides: _transportOverrides(
          fake: fake,
          db: db,
          hasLines: hasLines,
          blurActive: blurActive,
        ),
        width: width,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  // The always-on four controls (play, echo, subtitle/cc, speed) must
  // be visible at the narrowest width on both routes — never clipped.
  // Blur/hide lives in the CC sheet on narrow layouts.
  const alwaysOnIcons = <IconData>[
    Icons.play_arrow_rounded, // play (not playing by default)
    Icons.mic_none_rounded, // echo
    Icons.closed_caption_outlined, // subtitle/cc
    Icons.speed_rounded, // speed
  ];

  group('GlobalTransportBar narrow always-on controls (US1)', () {
    testWidgets('player at 320px renders all four always-on controls', (
      tester,
    ) async {
      await pumpTransport(tester, router: _playerRouter(), width: 320);

      for (final icon in alwaysOnIcons) {
        expect(find.byIcon(icon), findsOneWidget, reason: '$icon visible');
      }
      expect(find.byIcon(Icons.replay_rounded), findsNothing);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });
  });

  group('GlobalTransportBar narrow drop sequence (US2)', () {
    testWidgets('player at 320px drops previous, keeps next and volume', (
      tester,
    ) async {
      await pumpTransport(tester, router: _playerRouter(), width: 320);

      expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('player at 375px keeps previous and next', (tester) async {
      await pumpTransport(tester, router: _playerRouter(), width: 375);

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('player at 430px keeps previous and next', (tester) async {
      await pumpTransport(tester, router: _playerRouter(), width: 430);

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });
  });

  group('GlobalTransportBar wide player chrome', () {
    testWidgets('wide player renders line nav and practice controls', (
      tester,
    ) async {
      await pumpTransport(tester, router: _playerRouter(), width: 800);

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full_rounded), findsNothing);
      expect(find.text('Transport test'), findsOneWidget);
    });
  });

  group('GlobalTransportBar blur toggle', () {
    testWidgets('renders the blur toggle in off state', (tester) async {
      await pumpTransport(tester, router: _playerRouter(), width: 800);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('reflects on state with visibility_off icon', (tester) async {
      await pumpTransport(
        tester,
        router: _playerRouter(),
        width: 800,
        blurActive: true,
      );
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('disabled when there are no transcript lines', (tester) async {
      await pumpTransport(
        tester,
        router: _playerRouter(),
        width: 800,
        hasLines: false,
      );
      final blurButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.visibility_outlined),
          matching: find.byType(IconButton),
        ),
      );
      expect(blurButton.onPressed, isNull);
    });

    testWidgets('tap flips the blur enabled state', (tester) async {
      await pumpTransport(
        tester,
        router: _playerRouter(),
        width: 800,
        seedTranscript: true,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GlobalTransportBar)),
      );
      expect(container.read(transcriptBlurModeProvider), isFalse);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(container.read(transcriptBlurModeProvider), isTrue);
    });
  });
}
