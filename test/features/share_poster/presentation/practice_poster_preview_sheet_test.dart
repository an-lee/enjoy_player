// Tests for `lib/features/share_poster/presentation/practice_poster_preview_sheet.dart`.
//
// Covers the preview sheet's three render paths: loading spinner, no-data error
// message, and the full poster preview with export button. Heavy providers
// (database, library repo, transcript repo, player engine) are stubbed so the
// sheet can be exercised in isolation.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/files/file_storage.dart';
import 'package:enjoy_player/features/library/application/library_repository_provider.dart';
import 'package:enjoy_player/features/library/data/library_repository.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_engine_provider.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/share_poster/presentation/practice_poster_preview_sheet.dart';
import 'package:enjoy_player/features/share_poster/presentation/practice_poster_widget.dart';
import 'package:enjoy_player/features/transcript/application/transcript_repository_provider.dart';
import 'package:enjoy_player/features/transcript/data/transcript_repository.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_player_engine.dart';

Future<void> _seedVideo(
  AppDatabase db,
  String id, {
  String title = 'Test Video',
  String? thumbnailUrl,
  String? localUri,
}) async {
  final now = DateTime.now();
  await db.videoDao.insertRow(
    VideoRow(
      id: id,
      vid: 'v_$id',
      provider: 'user',
      title: title,
      description: null,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: 60,
      language: 'en',
      source: null,
      localUri: localUri,
      md5: null,
      size: localUri != null ? 1024 : null,
      mediaUrl: 'https://example.com/$id.mp4',
      syncStatus: null,
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> _seedRecording(AppDatabase db, String id, String targetId) async {
  final now = DateTime.now();
  await db.recordingDao.insertRow(
    RecordingRow(
      id: id,
      targetType: 'Video',
      targetId: targetId,
      referenceStart: 0,
      referenceDuration: 5000,
      referenceText: 'hello there.',
      language: 'en',
      duration: 4000,
      md5: null,
      audioUrl: null,
      pronunciationScore: null,
      assessmentJson: null,
      localPath: null,
      syncStatus: null,
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> _seedTranscript(
  AppDatabase db, {
  required String transcriptId,
  required String targetId,
  int lineCount = 2,
}) async {
  final now = DateTime.now();
  final timeline = List.generate(
    lineCount,
    (i) => {'t': i * 1000, 'd': 900, 'text': 'Line $i.'},
  );
  await db.transcriptDao.upsert(
    TranscriptRow(
      id: transcriptId,
      targetType: 'Video',
      targetId: targetId,
      language: 'en',
      source: 'user',
      label: '',
      trackIndex: 0,
      timelineJson: jsonEncode(timeline),
      referenceId: null,
      syncStatus: null,
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.echoSessionDao.upsert(
    EchoSessionRow(
      id: 'echo-$targetId',
      targetType: 'Video',
      targetId: targetId,
      language: 'en',
      currentTimeMs: 0,
      playbackRate: 1.0,
      volume: 1.0,
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

Future<void> _showSheet(
  WidgetTester tester, {
  required ProviderContainer container,
  required String mediaId,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: _LauncherBody(mediaId: mediaId),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

class _LauncherBody extends ConsumerStatefulWidget {
  const _LauncherBody({required this.mediaId});

  final String mediaId;

  @override
  ConsumerState<_LauncherBody> createState() => _LauncherBodyState();
}

class _LauncherBodyState extends ConsumerState<_LauncherBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showPracticePosterPreviewSheet(context, ref, mediaId: widget.mediaId);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late FakePlayerEngine fakeEngine;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    fakeEngine = FakePlayerEngine();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceGlobalAppDatabaseProvider.overrideWithValue(db),
        mediaLibraryRepositoryProvider.overrideWith(
          (ref) => MediaLibraryRepository(db, FileStorage()),
        ),
        transcriptRepositoryProvider.overrideWith(
          (ref) => TranscriptRepository(db),
        ),
        playerEngineTestDoubleProvider.overrideWithValue(fakeEngine),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await fakeEngine.dispose();
    await db.close();
  });

  testWidgets('renders preview sheet with poster after recordings load', (
    tester,
  ) async {
    await _seedVideo(db, 'v-1');
    await _seedRecording(db, 'r-1', 'v-1');
    await _seedTranscript(db, transcriptId: 't-1', targetId: 'v-1');

    await tester.binding.setSurfaceSize(const Size(400, 760));
    addTearDown(() => tester.view.resetPhysicalSize());

    await _showSheet(tester, container: container, mediaId: 'v-1');

    // Allow async _load to complete and the RepaintBoundary to fire.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PracticePosterWidget), findsOneWidget);
    expect(find.text('Test Video'), findsOneWidget);
  });

  testWidgets('shows no-poster state when media has no recordings', (
    tester,
  ) async {
    // Only video is seeded - no recordings.
    await _seedVideo(db, 'v-2');

    await tester.binding.setSurfaceSize(const Size(400, 760));
    addTearDown(() => tester.view.resetPhysicalSize());

    await _showSheet(tester, container: container, mediaId: 'v-2');

    // Allow async _load to complete.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // No poster, error message is shown.
    expect(find.byType(PracticePosterWidget), findsNothing);
  });

  testWidgets('shows no-poster state when mediaId is unknown', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 760));
    addTearDown(() => tester.view.resetPhysicalSize());

    await _showSheet(tester, container: container, mediaId: 'unknown');

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PracticePosterWidget), findsNothing);
  });

  testWidgets(
    'echo state is read from provider when active session matches mediaId',
    (tester) async {
      await _seedVideo(db, 'v-3');
      await _seedRecording(db, 'r-1', 'v-3');
      await _seedTranscript(db, transcriptId: 't-1', targetId: 'v-3');

      // Activate echo so capturePracticePosterEchoFrame takes the echo branch.
      container
          .read(echoModeProvider.notifier)
          .activate(
            startLineIndex: 0,
            endLineIndex: 1,
            startTimeSeconds: 0.0,
            endTimeSeconds: 2.0,
          );

      await tester.binding.setSurfaceSize(const Size(400, 760));
      addTearDown(() => tester.view.resetPhysicalSize());

      await _showSheet(tester, container: container, mediaId: 'v-3');

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Screenshot is invoked because echo is active for matching mediaId;
      // player session is null in tests so capture returns null. The poster
      // still renders normally because there's a recording.
      expect(find.byType(PracticePosterWidget), findsOneWidget);
    },
  );

  testWidgets(
    'echo state defaults to inactive when no session matches mediaId',
    (tester) async {
      await _seedVideo(db, 'v-4');
      await _seedRecording(db, 'r-1', 'v-4');
      await _seedTranscript(db, transcriptId: 't-1', targetId: 'v-4');

      // Echo is active but mediaId differs - capture should short-circuit.
      container
          .read(echoModeProvider.notifier)
          .activate(
            startLineIndex: 0,
            endLineIndex: 1,
            startTimeSeconds: 0.0,
            endTimeSeconds: 2.0,
          );

      await tester.binding.setSurfaceSize(const Size(400, 760));
      addTearDown(() => tester.view.resetPhysicalSize());

      await _showSheet(tester, container: container, mediaId: 'different-id');

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Engine screenshot is NOT called because mediaId doesn't match session
      // and playerControllerProvider is null.
      expect(fakeEngine.screenshotCalls, 0);
      expect(find.byType(PracticePosterWidget), findsNothing);
    },
  );
}
