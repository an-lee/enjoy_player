import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/settings/application/word_practice_settings.dart';
import 'package:enjoy_player/features/transcript/application/active_cue_word_index_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/application/word_practice_session.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_tile.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import '../../helpers/transcript_settings_overrides.dart';

class _KaraokeOff extends KaraokeHighlightSettings {
  @override
  Future<bool> build() async => false;
}

class _BlurMode extends TranscriptBlurMode {
  _BlurMode(this._initial);
  final bool _initial;

  @override
  bool build() => _initial;
}

const _withPhones = TranscriptLine(
  text: 'Hello world',
  startMs: 0,
  durationMs: 2000,
  timeline: [
    TranscriptWord(
      text: 'Hello',
      startMs: 0,
      durationMs: 800,
      phones: [
        TranscriptPhone(
          phone: 'hɛˈloʊ',
          text: 'hɛˈloʊ',
          startTime: 0,
          endTime: 0.4,
        ),
      ],
    ),
    TranscriptWord(text: 'world', startMs: 800, durationMs: 800),
  ],
);

const _noPhones = TranscriptLine(
  text: 'Hello world',
  startMs: 0,
  durationMs: 2000,
  timeline: [
    TranscriptWord(text: 'Hello', startMs: 0, durationMs: 800),
    TranscriptWord(text: 'world', startMs: 800, durationMs: 800),
  ],
);

void main() {
  testWidgets('practice on shows loop and inspect on selectable current word', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transcriptBlurModeProvider.overrideWith(() => _BlurMode(false)),
          karaokeHighlightSettingsProvider.overrideWith(_KaraokeOff.new),
          ...transcriptWordPracticeOnOverrides(),
          activeCueWordIndexProvider('test').overrideWithValue(0),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TranscriptLineTile(
              line: _withPhones,
              mediaId: 'test',
              secondaryText: null,
              isActive: true,
              inEcho: false,
              selectable: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(l10n.transcriptWordLoopTooltip), findsOneWidget);
    expect(find.byTooltip(l10n.transcriptWordInspectTooltip), findsOneWidget);
  });

  testWidgets('inspect icon is omitted when the current word has no phones', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transcriptBlurModeProvider.overrideWith(() => _BlurMode(false)),
          karaokeHighlightSettingsProvider.overrideWith(_KaraokeOff.new),
          ...transcriptWordPracticeOnOverrides(),
          activeCueWordIndexProvider('test').overrideWithValue(0),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TranscriptLineTile(
              line: _noPhones,
              mediaId: 'test',
              secondaryText: null,
              isActive: true,
              inEcho: false,
              selectable: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(l10n.transcriptWordLoopTooltip), findsOneWidget);
    expect(find.byTooltip(l10n.transcriptWordInspectTooltip), findsNothing);
  });

  testWidgets(
    'non-active echo row does not show loop/inspect for the active cue word',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transcriptBlurModeProvider.overrideWith(() => _BlurMode(false)),
            karaokeHighlightSettingsProvider.overrideWith(_KaraokeOff.new),
            ...transcriptWordPracticeOnOverrides(),
            activeCueWordIndexProvider('test').overrideWithValue(0),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TranscriptLineTile(
                line: _withPhones,
                lineIndex: 1,
                mediaId: 'test',
                secondaryText: null,
                isActive: false,
                inEcho: true,
                groupedInEcho: true,
                selectable: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.transcriptWordLoopTooltip), findsNothing);
      expect(find.byTooltip(l10n.transcriptWordInspectTooltip), findsNothing);
    },
  );

  testWidgets('active echo cue still shows loop and inspect', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transcriptBlurModeProvider.overrideWith(() => _BlurMode(false)),
          karaokeHighlightSettingsProvider.overrideWith(_KaraokeOff.new),
          ...transcriptWordPracticeOnOverrides(),
          activeCueWordIndexProvider('test').overrideWithValue(0),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TranscriptLineTile(
              line: _withPhones,
              lineIndex: 0,
              mediaId: 'test',
              secondaryText: null,
              isActive: true,
              inEcho: true,
              groupedInEcho: true,
              selectable: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(l10n.transcriptWordLoopTooltip), findsOneWidget);
    expect(find.byTooltip(l10n.transcriptWordInspectTooltip), findsOneWidget);
  });

  test('startLoop does not rewrite echo start or end', () {
    final container = ProviderContainer(
      overrides: transcriptWordPracticeOnOverrides(),
    );
    addTearDown(container.dispose);

    container
        .read(echoModeProvider.notifier)
        .activate(
          startLineIndex: 0,
          endLineIndex: 2,
          startTimeSeconds: 1,
          endTimeSeconds: 8,
        );
    container
        .read(wordPracticeSessionProvider('m1').notifier)
        .startLoop(lineIndex: 1, wordIndex: 0, startMs: 1500, endMs: 2000);

    final echo = container.read(echoModeProvider);
    expect(echo.startLineIndex, 0);
    expect(echo.endLineIndex, 2);
    expect(echo.startTimeSeconds, 1);
    expect(echo.endTimeSeconds, 8);
    expect(container.read(wordPracticeSessionProvider('m1')).isLooping, isTrue);
  });

  test('practice off clears the ephemeral loop', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container
        .read(wordPracticeSettingsProvider.notifier)
        .setEnabled(true);
    container.listen(wordPracticeSessionProvider('m1'), (_, _) {});
    container
        .read(wordPracticeSessionProvider('m1').notifier)
        .startLoop(lineIndex: 0, wordIndex: 0, startMs: 0, endMs: 400);
    expect(container.read(wordPracticeSessionProvider('m1')).isLooping, isTrue);

    await container
        .read(wordPracticeSettingsProvider.notifier)
        .setEnabled(false);
    expect(
      container.read(wordPracticeSessionProvider('m1')).isLooping,
      isFalse,
    );
  });
}
