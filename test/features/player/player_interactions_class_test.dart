// ignore_for_file: avoid_redundant_argument_values, cascade_invocations
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_interactions.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_player_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mediaId = 'm1';
  const transcriptId = 't1';
  const altMediaId = 'm2';

  final lines = <TranscriptLine>[
    const TranscriptLine(text: 'line 1', startMs: 0, durationMs: 2000),
    const TranscriptLine(text: 'line 2', startMs: 2000, durationMs: 2000),
    const TranscriptLine(text: 'line 3', startMs: 4000, durationMs: 2000),
    const TranscriptLine(text: 'line 4', startMs: 6000, durationMs: 2000),
  ];

  final timelineJson = jsonEncode(
    lines
        .map(
          (l) => {'text': l.text, 'start': l.startMs, 'duration': l.durationMs},
        )
        .toList(),
  );

  late AppDatabase db;
  late FakePlayerEngine fake;
  late ProviderContainer container;

  PlaybackSession sessionFor(String id, {double currentTime = 0.5}) {
    final now = DateTime(2026, 7, 25);
    return PlaybackSession(
      mediaId: id,
      dexieTargetType: 'Audio',
      mediaType: 'audio',
      mediaTitle: 't',
      durationSeconds: 30,
      currentTimeSeconds: currentTime,
      currentSegmentIndex: 0,
      language: 'en',
      startedAt: now,
      lastActiveAt: now,
    );
  }

  Future<void> insertAudioRow(String id) async {
    final now = DateTime.now();
    await db.audioDao.insertRow(
      AudioRow(
        id: id,
        aid: 'a-$id',
        provider: 'user',
        title: 't',
        description: null,
        thumbnailUrl: null,
        durationSeconds: 30,
        language: 'en',
        translationKey: null,
        sourceText: null,
        voice: null,
        source: null,
        localUri: null,
        md5: null,
        size: 0,
        mediaUrl: null,
        syncStatus: null,
        serverUpdatedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> seedTranscript({String forMedia = mediaId}) async {
    await db.transcriptDao.upsert(
      TranscriptRow(
        id: transcriptId,
        targetType: 'Audio',
        targetId: forMedia,
        language: 'en',
        source: 'official',
        timelineJson: timelineJson,
        referenceId: null,
        label: '',
        trackIndex: null,
        syncStatus: null,
        serverUpdatedAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final now = DateTime.now();
    await db.echoSessionDao.updatePrimaryTranscriptForTarget(
      'Audio',
      forMedia,
      transcriptId,
    );
    // ensure lastActiveAt is current
    final existing = await db.echoSessionDao.getLatestForTarget(
      'Audio',
      forMedia,
    );
    await db.echoSessionDao.upsert(
      existing!.copyWith(lastActiveAt: now, updatedAt: now),
    );
  }

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    fake = FakePlayerEngine();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        playerEngineTestDoubleProvider.overrideWithValue(fake),
        transcriptRepositoryProvider.overrideWithValue(
          TranscriptRepository(db),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await fake.dispose();
  });

  setUpSession({String forMedia = mediaId, double currentTime = 0.5}) {
    container.read(playerControllerProvider.notifier).session = sessionFor(
      forMedia,
      currentTime: currentTime,
    );
  }

  test('prevLine bails out when there is no session', () async {
    final n = container.read(playerInteractionsProvider.notifier);
    await n.prevLine();
    expect(fake.seekCalls, isEmpty);
    expect(fake.playCallCount, 0);
  });

  test('prevLine bails out when there is no transcript', () async {
    setUpSession();
    final n = container.read(playerInteractionsProvider.notifier);
    await n.prevLine();
    expect(fake.seekCalls, isEmpty);
    expect(fake.playCallCount, 0);
  });

  test('nextLine bails out when there are no transcript lines', () async {
    setUpSession();
    final n = container.read(playerInteractionsProvider.notifier);
    await n.nextLine();
    expect(fake.seekCalls, isEmpty);
    expect(fake.playCallCount, 0);
  });

  test('nextLine seeks to next line start and plays (no echo)', () async {
    await insertAudioRow(mediaId);
    await seedTranscript();
    setUpSession(currentTime: 2.5); // inside line 2

    final n = container.read(playerInteractionsProvider.notifier);
    await n.nextLine();
    expect(fake.seekCalls, [const Duration(seconds: 4)]);
    expect(fake.playCallCount, 1);
  });

  test('nextLine clamps at last line', () async {
    await insertAudioRow(mediaId);
    await seedTranscript();
    setUpSession(currentTime: 8.0); // past last line

    final n = container.read(playerInteractionsProvider.notifier);
    await n.nextLine();
    expect(fake.seekCalls, [const Duration(seconds: 6)]);
    expect(fake.playCallCount, 1);
  });

  test('prevLine seeks to previous line start and plays (no echo)', () async {
    await insertAudioRow(mediaId);
    await seedTranscript();
    setUpSession(currentTime: 4.5); // inside line 3

    final n = container.read(playerInteractionsProvider.notifier);
    await n.prevLine();
    expect(fake.seekCalls, [const Duration(seconds: 2)]);
    expect(fake.playCallCount, 1);
  });

  test('prevLine clamps at first line', () async {
    await insertAudioRow(mediaId);
    await seedTranscript();
    setUpSession(currentTime: 0.5);

    final n = container.read(playerInteractionsProvider.notifier);
    await n.prevLine();
    expect(fake.seekCalls, [const Duration(seconds: 0)]);
    expect(fake.playCallCount, 1);
  });

  test('nextLine uses echo.endLineIndex when echo is active', () async {
    await insertAudioRow(mediaId);
    await seedTranscript();
    setUpSession(currentTime: 4.0); // past echo region
    container
        .read(echoModeProvider.notifier)
        .activate(
          startLineIndex: 1,
          endLineIndex: 1,
          startTimeSeconds: 2,
          endTimeSeconds: 4,
        );

    final n = container.read(playerInteractionsProvider.notifier);
    await n.nextLine();
    // next = endLineIndex + 1 = 2 -> startSeconds=4
    expect(fake.seekCalls, [const Duration(seconds: 4)]);
    expect(fake.playCallCount, 1);
  });

  test('prevLine uses echo.startLineIndex when echo is active', () async {
    await insertAudioRow(mediaId);
    await seedTranscript();
    setUpSession(currentTime: 5.0); // past echo region
    container
        .read(echoModeProvider.notifier)
        .activate(
          startLineIndex: 1,
          endLineIndex: 2,
          startTimeSeconds: 2,
          endTimeSeconds: 6,
        );

    final n = container.read(playerInteractionsProvider.notifier);
    await n.prevLine();
    expect(fake.seekCalls, [const Duration(seconds: 0)]);
    expect(fake.playCallCount, 1);
  });

  test('replayLine seeks to active line start and plays (no echo)', () async {
    await insertAudioRow(mediaId);
    await seedTranscript();
    setUpSession(currentTime: 4.5);

    final n = container.read(playerInteractionsProvider.notifier);
    await n.replayLine();
    expect(fake.seekCalls, [const Duration(seconds: 4)]);
    expect(fake.playCallCount, 1);
  });

  test(
    'replayLine seeks to echo.startTimeSeconds when echo is active',
    () async {
      await insertAudioRow(mediaId);
      await seedTranscript();
      setUpSession(currentTime: 4.5);
      container
          .read(echoModeProvider.notifier)
          .activate(
            startLineIndex: 1,
            endLineIndex: 1,
            startTimeSeconds: 2,
            endTimeSeconds: 4,
          );

      final n = container.read(playerInteractionsProvider.notifier);
      await n.replayLine();
      expect(fake.seekCalls, [const Duration(seconds: 2)]);
      expect(fake.playCallCount, 1);
    },
  );

  test('toggleEcho activates echo when off', () async {
    await insertAudioRow(mediaId);
    await seedTranscript();
    setUpSession(currentTime: 4.5);

    final n = container.read(playerInteractionsProvider.notifier);
    await n.toggleEcho();
    final echo = container.read(echoModeProvider);
    expect(echo.active, isTrue);
    expect(echo.startLineIndex, 2);
    expect(echo.endLineIndex, 2);
  });

  test('toggleEcho deactivates echo when on', () async {
    await insertAudioRow(mediaId);
    await seedTranscript();
    setUpSession(currentTime: 4.5);
    container
        .read(echoModeProvider.notifier)
        .activate(
          startLineIndex: 1,
          endLineIndex: 1,
          startTimeSeconds: 2,
          endTimeSeconds: 4,
        );

    final n = container.read(playerInteractionsProvider.notifier);
    await n.toggleEcho();
    expect(container.read(echoModeProvider).active, isFalse);
  });

  test('toggleEcho bails out when currentTime is not in any line', () async {
    await insertAudioRow(mediaId);
    // Override the seeded transcript with lines that all start after the
    // session's currentTime, so indexOfActiveLine returns -1.
    final futureLines = <TranscriptLine>[
      const TranscriptLine(text: 'a', startMs: 20000, durationMs: 2000),
      const TranscriptLine(text: 'b', startMs: 22000, durationMs: 2000),
    ];
    await db.transcriptDao.upsert(
      TranscriptRow(
        id: 't-future',
        targetType: 'Audio',
        targetId: mediaId,
        language: 'en',
        source: 'official',
        timelineJson: jsonEncode(
          futureLines
              .map(
                (l) => {
                  'text': l.text,
                  'start': l.startMs,
                  'duration': l.durationMs,
                },
              )
              .toList(),
        ),
        referenceId: null,
        label: '',
        trackIndex: null,
        syncStatus: null,
        serverUpdatedAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await db.echoSessionDao.updatePrimaryTranscriptForTarget(
      'Audio',
      mediaId,
      't-future',
    );
    setUpSession(currentTime: 1.0); // before any future line

    final n = container.read(playerInteractionsProvider.notifier);
    await n.toggleEcho();
    expect(container.read(echoModeProvider).active, isFalse);
  });

  test('toggleBlur activates when there are lines', () async {
    await insertAudioRow(mediaId);
    await seedTranscript();
    setUpSession();

    final n = container.read(playerInteractionsProvider.notifier);
    await n.toggleBlur();
    expect(container.read(transcriptBlurModeProvider), isTrue);

    // Should have written the session (echo session row exists)
    final row = await db.echoSessionDao.getLatestForTarget('Audio', mediaId);
    expect(row, isNotNull);
  });

  test('toggleBlur deactivates even when there are no lines', () async {
    await insertAudioRow(mediaId);
    // No transcript — but blur can still turn off.
    setUpSession();
    container.read(transcriptBlurModeProvider.notifier).activate();

    final n = container.read(playerInteractionsProvider.notifier);
    await n.toggleBlur();
    expect(container.read(transcriptBlurModeProvider), isFalse);
  });

  test('toggleBlur does not activate when there are no lines', () async {
    await insertAudioRow(mediaId);
    setUpSession();

    final n = container.read(playerInteractionsProvider.notifier);
    await n.toggleBlur();
    expect(container.read(transcriptBlurModeProvider), isFalse);
  });

  test('toggleBlur bails out when there is no session', () async {
    final n = container.read(playerInteractionsProvider.notifier);
    await n.toggleBlur();
    expect(container.read(transcriptBlurModeProvider), isFalse);
  });

  test(
    'expandEchoBackward / expandEchoForward / shrink variants require echo on',
    () async {
      await insertAudioRow(mediaId);
      await seedTranscript();
      setUpSession(currentTime: 4.5);

      final n = container.read(playerInteractionsProvider.notifier);
      // echo is off — all four should be no-ops
      await n.expandEchoBackward();
      await n.expandEchoForward();
      await n.shrinkEchoBackward();
      await n.shrinkEchoForward();
      expect(container.read(echoModeProvider).active, isFalse);

      // Now turn echo on with a multi-line region so we can exercise each.
      container
          .read(echoModeProvider.notifier)
          .activate(
            startLineIndex: 1,
            endLineIndex: 2,
            startTimeSeconds: 2,
            endTimeSeconds: 6,
          );
      await n.expandEchoBackward();
      expect(container.read(echoModeProvider).startLineIndex, 0);
      await n.expandEchoForward();
      expect(container.read(echoModeProvider).endLineIndex, 3);
      await n.shrinkEchoBackward();
      expect(container.read(echoModeProvider).startLineIndex, 1);
      await n.shrinkEchoForward();
      expect(container.read(echoModeProvider).endLineIndex, 2);
    },
  );

  test('expand/shrink bail out when there are no lines', () async {
    await insertAudioRow(mediaId);
    setUpSession(currentTime: 4.5);
    container
        .read(echoModeProvider.notifier)
        .activate(
          startLineIndex: 1,
          endLineIndex: 2,
          startTimeSeconds: 2,
          endTimeSeconds: 6,
        );

    final n = container.read(playerInteractionsProvider.notifier);
    // No transcript — echo state should be unchanged.
    await n.expandEchoBackward();
    await n.expandEchoForward();
    await n.shrinkEchoBackward();
    await n.shrinkEchoForward();
    final echo = container.read(echoModeProvider);
    expect(echo.startLineIndex, 1);
    expect(echo.endLineIndex, 2);
  });

  test('seekToProgressFraction clamps fraction and seeks', () async {
    await insertAudioRow(mediaId);
    setUpSession();

    final n = container.read(playerInteractionsProvider.notifier);
    await n.seekToProgressFraction(0.5);
    expect(fake.seekCalls, [const Duration(seconds: 15)]); // 30 * 0.5

    await n.seekToProgressFraction(1.5); // over 1 → clamped to 1
    expect(fake.seekCalls.last, const Duration(seconds: 30));

    await n.seekToProgressFraction(-1.0); // under 0 → clamped to 0
    expect(fake.seekCalls.last, Duration.zero);
  });

  test('seekToProgressFraction bails out when duration <= 0', () async {
    await insertAudioRow(mediaId);
    container.read(playerControllerProvider.notifier).session = sessionFor(
      mediaId,
    ).copyWith(durationSeconds: 0);

    final n = container.read(playerInteractionsProvider.notifier);
    await n.seekToProgressFraction(0.5);
    expect(fake.seekCalls, isEmpty);
  });

  test('seekToProgressFraction bails out when no session', () async {
    final n = container.read(playerInteractionsProvider.notifier);
    await n.seekToProgressFraction(0.5);
    expect(fake.seekCalls, isEmpty);
  });

  test('seekToLine delegates to _seekLine (no echo)', () async {
    await insertAudioRow(mediaId);
    await seedTranscript();
    setUpSession(currentTime: 2.5);

    final n = container.read(playerInteractionsProvider.notifier);
    await n.seekToLine(lines[2], 2);
    expect(fake.seekCalls, [const Duration(seconds: 4)]);
    expect(fake.playCallCount, 1);
  });

  test(
    'seekToLine activates echo and seeks with window when echo is on',
    () async {
      await insertAudioRow(mediaId);
      await seedTranscript();
      setUpSession(currentTime: 4.5);
      container
          .read(echoModeProvider.notifier)
          .activate(
            startLineIndex: 0,
            endLineIndex: 0,
            startTimeSeconds: 0,
            endTimeSeconds: 2,
          );

      final n = container.read(playerInteractionsProvider.notifier);
      await n.seekToLine(lines[2], 2);
      final echo = container.read(echoModeProvider);
      expect(echo.startLineIndex, 2);
      expect(echo.endLineIndex, 2);
      expect(fake.seekCalls, [const Duration(seconds: 4)]);
      expect(fake.playCallCount, 1);
    },
  );

  test('line cache reuses cached lines when media is unchanged', () async {
    await insertAudioRow(mediaId);
    await seedTranscript();
    setUpSession(currentTime: 0.5);

    final n = container.read(playerInteractionsProvider.notifier);
    await n.nextLine(); // populates cache via primaryTranscriptRowForMedia
    expect(fake.seekCalls, hasLength(1));

    // Second call should reuse cached lines (no new DB row fetch needed).
    await n.nextLine();
    expect(fake.seekCalls, hasLength(2));
  });

  test(
    'line cache resets when media changes (different transcript fetched)',
    () async {
      await insertAudioRow(mediaId);
      await seedTranscript();
      await insertAudioRow(altMediaId);
      // No transcript seeded for alt — should clear cache to empty.

      setUpSession(forMedia: mediaId, currentTime: 0.5);
      final n = container.read(playerInteractionsProvider.notifier);
      await n.nextLine();
      expect(fake.seekCalls, hasLength(1));

      container.read(playerControllerProvider.notifier).session = sessionFor(
        altMediaId,
        currentTime: 0.5,
      );
      await n.nextLine();
      // No transcript for altMedia — _lines() returns [], method is no-op.
      expect(fake.seekCalls, hasLength(1));
    },
  );

  test(
    'previous-no-session path: replayLine bails out when session null',
    () async {
      await insertAudioRow(mediaId);
      await seedTranscript();
      final n = container.read(playerInteractionsProvider.notifier);
      await n.replayLine();
      expect(fake.seekCalls, isEmpty);
    },
  );

  test('replayLine bails out when there are no lines', () async {
    setUpSession();
    final n = container.read(playerInteractionsProvider.notifier);
    await n.replayLine();
    expect(fake.seekCalls, isEmpty);
  });

  test('EchoState.inactive static is reused across operations', () {
    const e = EchoState.inactive;
    expect(e.active, isFalse);
    expect(e.startLineIndex, -1);
    expect(e.endLineIndex, -1);
    expect(e.startTimeSeconds, -1);
    expect(e.endTimeSeconds, -1);
    expect(
      e,
      const EchoState(
        active: false,
        startLineIndex: -1,
        endLineIndex: -1,
        startTimeSeconds: -1,
        endTimeSeconds: -1,
      ),
    );
  });
}
