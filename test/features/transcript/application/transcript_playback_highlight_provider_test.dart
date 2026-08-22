import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/application/display_position_provider.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/transcript/application/karaoke_position_provider.dart';
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

  ProviderContainer containerWith({required bool canTrust}) {
    return ProviderContainer(
      overrides: [
        deviceGlobalAppDatabaseProvider.overrideWithValue(db),
        transcriptLinesForMediaProvider(
          'm1',
        ).overrideWith((ref) => Stream.value(const [line])),
        displayPositionProvider.overrideWith(
          (ref) => Stream.value(const Duration(milliseconds: 1100)),
        ),
        karaokePositionProvider.overrideWith(
          (ref) => Stream.value(const Duration(milliseconds: 1100)),
        ),
        canTrustWordTimesProvider('m1').overrideWith((ref) async => canTrust),
      ],
    );
  }

  test('persisted true is not treated as off after settings resolve', () async {
    await db.settingsDao.setValue(
      SettingsKeys.transcriptKaraokeHighlight,
      'true',
    );
    final container = containerWith(canTrust: true);
    addTearDown(container.dispose);

    final subs = [
      container.listen(karaokeHighlightSettingsProvider, (_, _) {}),
      container.listen(karaokePositionProvider, (_, _) {}),
      container.listen(transcriptLinesForMediaProvider('m1'), (_, _) {}),
      container.listen(displayPositionProvider, (_, _) {}),
      container.listen(transcriptPlaybackHighlightProvider('m1'), (_, _) {}),
      container.listen(canTrustWordTimesProvider('m1'), (_, _) {}),
    ];
    addTearDown(() {
      for (final sub in subs) {
        sub.close();
      }
    });

    // Until the persisted setting resolves, the cue is known but the karaoke
    // word stays gated off.
    expect(
      container.read(transcriptPlaybackHighlightProvider('m1')).wordIndex,
      isNull,
    );
    expect(
      await container.read(karaokeHighlightSettingsProvider.future),
      isTrue,
    );
    expect(
      await container.read(canTrustWordTimesProvider('m1').future),
      isTrue,
    );
    expect(container.read(karaokeHighlightSettingsProvider).value, isTrue);
    expect(container.read(transcriptPlaybackHighlightProvider('m1')), (
      cueIndex: 0,
      wordIndex: 0,
    ));
  });

  test('karaoke off returns the cue with a null word index', () async {
    final container = containerWith(canTrust: true);
    addTearDown(container.dispose);

    final subs = [
      container.listen(transcriptLinesForMediaProvider('m1'), (_, _) {}),
      container.listen(transcriptPlaybackHighlightProvider('m1'), (_, _) {}),
    ];
    addTearDown(() {
      for (final sub in subs) {
        sub.close();
      }
    });

    expect(
      await container.read(karaokeHighlightSettingsProvider.future),
      isFalse,
    );
    await container.read(transcriptLinesForMediaProvider('m1').future);
    await container.read(displayPositionProvider.future);

    expect(container.read(transcriptPlaybackHighlightProvider('m1')), (
      cueIndex: 0,
      wordIndex: null,
    ));
  });

  test('untrusted word times keep karaoke gated off', () async {
    await db.settingsDao.setValue(
      SettingsKeys.transcriptKaraokeHighlight,
      'true',
    );
    final container = containerWith(canTrust: false);
    addTearDown(container.dispose);

    final subs = [
      container.listen(transcriptLinesForMediaProvider('m1'), (_, _) {}),
      container.listen(transcriptPlaybackHighlightProvider('m1'), (_, _) {}),
    ];
    addTearDown(() {
      for (final sub in subs) {
        sub.close();
      }
    });

    expect(
      await container.read(karaokeHighlightSettingsProvider.future),
      isTrue,
    );
    await container.read(transcriptLinesForMediaProvider('m1').future);
    await container.read(displayPositionProvider.future);

    expect(container.read(transcriptPlaybackHighlightProvider('m1')), (
      cueIndex: 0,
      wordIndex: null,
    ));
  });
}
