import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/transcript/application/karaoke_position_provider.dart';
import 'package:enjoy_player/features/transcript/application/karaoke_word_index_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_display_readiness_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_playback_highlight_provider.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  const line = TranscriptLine(
    text: 'Hello world',
    startMs: 1000,
    durationMs: 2000,
    timeline: [
      TranscriptWord(text: 'Hello', startMs: 0, durationMs: 800),
      TranscriptWord(text: 'world', startMs: 800, durationMs: 800),
    ],
  );

  test('persisted true is not treated as off after settings resolve', () async {
    await db.settingsDao.setValue(
      SettingsKeys.transcriptKaraokeHighlight,
      'true',
    );
    final container = ProviderContainer(
      overrides: [
        deviceGlobalAppDatabaseProvider.overrideWithValue(db),
        transcriptLinesForMediaProvider(
          'm1',
        ).overrideWith((ref) => Stream.value(const [line])),
        transcriptPlaybackHighlightProvider('m1').overrideWith((ref) => 0),
        karaokePositionProvider.overrideWith(
          (ref) => Stream.value(const Duration(milliseconds: 1100)),
        ),
        canTrustWordTimesProvider('m1').overrideWith((ref) async => true),
      ],
    );
    addTearDown(container.dispose);

    final subs = [
      container.listen(karaokeHighlightSettingsProvider, (_, _) {}),
      container.listen(karaokePositionProvider, (_, _) {}),
      container.listen(transcriptLinesForMediaProvider('m1'), (_, _) {}),
      container.listen(transcriptPlaybackHighlightProvider('m1'), (_, _) {}),
      container.listen(canTrustWordTimesProvider('m1'), (_, _) {}),
      container.listen(karaokeWordIndexProvider('m1'), (_, _) {}),
    ];
    addTearDown(() {
      for (final sub in subs) {
        sub.close();
      }
    });

    expect(container.read(karaokeWordIndexProvider('m1')), isNull);
    expect(
      await container.read(karaokeHighlightSettingsProvider.future),
      isTrue,
    );
    expect(
      await container.read(canTrustWordTimesProvider('m1').future),
      isTrue,
    );
    expect(container.read(karaokeHighlightSettingsProvider).value, isTrue);
    expect(container.read(transcriptPlaybackHighlightProvider('m1')), 0);
    expect(
      (container.read(transcriptLinesForMediaProvider('m1')).value ?? const [])
          .length,
      1,
    );
    expect(
      container.read(karaokePositionProvider).value,
      const Duration(milliseconds: 1100),
    );
    expect(container.read(karaokeWordIndexProvider('m1')), 0);
  });
}
