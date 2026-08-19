import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/application/transcript_display_readiness_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('cloud-library audio URL is trusted for word times', () async {
    final now = DateTime.utc(2026, 8, 19);
    await db.audioDao.insertRow(
      AudioRow(
        id: 'cloud-audio',
        aid: 'cloud-audio',
        provider: 'user',
        title: 'Cloud',
        durationSeconds: 30,
        language: 'en',
        mediaUrl: 'https://cdn.example/owned.mp3',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(canTrustWordTimesProvider('cloud-audio').future),
      isTrue,
    );
  });

  test('YouTube playback is not trusted for word times', () async {
    final now = DateTime.utc(2026, 8, 19);
    await db.videoDao.insertRow(
      VideoRow(
        id: 'yt',
        vid: 'dQw4w9WgXcQ',
        provider: 'youtube',
        title: 'YouTube',
        durationSeconds: 60,
        language: 'en',
        mediaUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(canTrustWordTimesProvider('yt').future),
      isFalse,
    );
  });

  test(
    'unresolved trust is treated as owned so cloud enrich stays visible',
    () async {
      const timedNoPhones = [
        TranscriptLine(
          text: 'Hello',
          startMs: 0,
          durationMs: 1000,
          timeline: [
            TranscriptWord(text: 'Hello', startMs: 0, durationMs: 800),
          ],
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          canTrustWordTimesProvider(
            'pending',
          ).overrideWith((ref) => Completer<bool>().future),
          transcriptLinesForMediaProvider(
            'pending',
          ).overrideWith((ref) => Stream.value(timedNoPhones)),
        ],
      );
      addTearDown(container.dispose);

      container.listen(transcriptLinesForMediaProvider('pending'), (_, _) {});
      await container.read(transcriptLinesForMediaProvider('pending').future);
      final readiness = container.read(
        transcriptDisplayReadinessForMediaProvider('pending'),
      );
      expect(readiness.canTrustWordTimes, isTrue);
      expect(readiness.showEnrich, isTrue);
      expect(readiness.karaokeSwitchEnabled, isFalse);
    },
  );
}
