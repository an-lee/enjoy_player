// Coverage for
// lib/features/shadow_reading/presentation/widgets/shadow_takes_toolbar_actions.dart.
//
// The widget composes a play/pause IconButton with the preview-player stream,
// an assessment button (driven by RecordingAssessmentButton), and a popup menu
// that lists takes with optional score badges plus Re-assess / Delete entries.
// `confirmShadowDeleteTake` is the dialog helper extracted alongside the widget.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:enjoy_player/core/audio/recording_preview_player.dart';
import 'package:enjoy_player/core/audio/recording_preview_player_provider.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/widgets/shadow_takes_toolbar_actions.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

const _kScoredJson = '''
{
  "NBest": [
    {
      "PronunciationAssessment": {
        "PronScore": 92
      }
    }
  ]
}
''';

const _kScoredJsonHigh = '''
{
  "NBest": [
    {
      "PronunciationAssessment": {
        "PronScore": 95
      }
    }
  ]
}
''';

RecordingRow _row({
  required String id,
  String? localPath,
  String? assessmentJson,
  int? pronunciationScore,
  int duration = 1500,
  String language = 'en',
}) {
  final now = DateTime.utc(2026, 1, 1);
  return RecordingRow(
    id: id,
    targetType: 'Audio',
    targetId: 'm1',
    referenceStart: 0,
    referenceDuration: 5000,
    referenceText: 'Hi',
    language: language,
    duration: duration,
    md5: null,
    audioUrl: null,
    pronunciationScore: pronunciationScore,
    assessmentJson: assessmentJson,
    localPath: localPath,
    syncStatus: 'local',
    serverUpdatedAt: null,
    createdAt: now,
    updatedAt: now,
  );
}

class _RecordingPreviewStub implements RecordingPreviewPlayback {
  _RecordingPreviewStub();

  String? _loaded;
  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();

  void setLoadedPath(String? p) => _loaded = p;

  @override
  String? get loadedPath => _loaded;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration> get duration => _duration.stream;

  void emitPlaying(bool v) => _playing.add(v);

  @override
  Future<void> play(String path) async {
    _loaded = path;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> playClip(String path, Duration start, Duration end) async {
    _loaded = path;
  }

  @override
  Future<void> playOrPauseTake(String path) async {
    if (_loaded == path) {
      // toggle
    } else {
      _loaded = path;
    }
  }

  @override
  Future<void> stop() async {
    _loaded = null;
  }

  @override
  Future<void> dispose() async {
    await _playing.close();
    await _position.close();
    await _duration.close();
  }
}

Future<
  ({
    AppLocalizations l10n,
    TextTheme tt,
    ColorScheme scheme,
    EnjoyThemeTokens tok,
  })
>
_buildEnv(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  late TextTheme tt;
  late ColorScheme scheme;
  late EnjoyThemeTokens tok;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          tt = Theme.of(context).textTheme;
          scheme = Theme.of(context).colorScheme;
          tok = EnjoyThemeTokens.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return (l10n: l10n, tt: tt, scheme: scheme, tok: tok);
}

Widget _wrap({
  required AppLocalizations l10n,
  required TextTheme tt,
  required ColorScheme scheme,
  required EnjoyThemeTokens tok,
  required RecordingRow row,
  required List<RecordingRow> list,
  required bool echoActive,
  required AppDatabase db,
  required _RecordingPreviewStub preview,
  VoidCallback? onPlayOrPause,
  VoidCallback? onDeleteCurrent,
  Future<void> Function(String id)? onChooseTake,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingPreviewPlayerProvider.overrideWithValue(preview),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        textTheme: tt,
        extensions: [tok],
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
          child: ShadowTakesToolbarActions(
            row: row,
            list: list,
            echoActive: echoActive,
            scheme: scheme,
            tok: tok,
            l10n: l10n,
            onPlayOrPause: onPlayOrPause ?? () {},
            onDeleteCurrent: onDeleteCurrent ?? () {},
            onChooseTake: onChooseTake ?? (_) async {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    MediaKit.ensureInitialized();
  } on Object catch (e) {
    test('(skipped) media_kit native library not available', () {}, skip: '$e');
    return;
  }

  group('ShadowTakesToolbarActions', () {
    testWidgets(
      'renders enabled play IconButton when echo is active and localPath present',
      (tester) async {
        final env = await _buildEnv(tester);
        final db = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(db.close);
        final preview = _RecordingPreviewStub();
        addTearDown(preview.dispose);
        final row = _row(id: 'a', localPath: '/tmp/a.wav');

        await tester.pumpWidget(
          _wrap(
            l10n: env.l10n,
            tt: env.tt,
            scheme: env.scheme,
            tok: env.tok,
            row: row,
            list: [row],
            echoActive: true,
            db: db,
            preview: preview,
          ),
        );
        await tester.pumpAndSettle();

        final playButtons = find.byIcon(Icons.play_arrow_rounded);
        expect(playButtons, findsWidgets);
        final iconButton = tester
            .widgetList<IconButton>(find.byType(IconButton))
            .firstWhere((b) => b.onPressed != null);
        expect(iconButton.onPressed, isNotNull);
      },
    );

    testWidgets('play IconButton is disabled when localPath is null', (
      tester,
    ) async {
      final env = await _buildEnv(tester);
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      final preview = _RecordingPreviewStub();
      addTearDown(preview.dispose);
      final row = _row(id: 'b');

      await tester.pumpWidget(
        _wrap(
          l10n: env.l10n,
          tt: env.tt,
          scheme: env.scheme,
          tok: env.tok,
          row: row,
          list: [row],
          echoActive: true,
          db: db,
          preview: preview,
        ),
      );
      await tester.pumpAndSettle();

      final disabled = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .where((b) => b.onPressed == null);
      expect(disabled, isNotEmpty);
    });

    testWidgets(
      'play IconButton is disabled when echoActive is false even with localPath',
      (tester) async {
        final env = await _buildEnv(tester);
        final db = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(db.close);
        final preview = _RecordingPreviewStub();
        addTearDown(preview.dispose);
        final row = _row(id: 'c', localPath: '/tmp/c.wav');

        await tester.pumpWidget(
          _wrap(
            l10n: env.l10n,
            tt: env.tt,
            scheme: env.scheme,
            tok: env.tok,
            row: row,
            list: [row],
            echoActive: false,
            db: db,
            preview: preview,
          ),
        );
        await tester.pumpAndSettle();

        final disabled = tester
            .widgetList<IconButton>(find.byType(IconButton))
            .where((b) => b.onPressed == null);
        expect(disabled, isNotEmpty);
      },
    );

    testWidgets('tapping the play button invokes onPlayOrPause when enabled', (
      tester,
    ) async {
      final env = await _buildEnv(tester);
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      final preview = _RecordingPreviewStub();
      addTearDown(preview.dispose);
      final row = _row(id: 'd', localPath: '/tmp/d.wav');
      var playTaps = 0;
      await tester.pumpWidget(
        _wrap(
          l10n: env.l10n,
          tt: env.tt,
          scheme: env.scheme,
          tok: env.tok,
          row: row,
          list: [row],
          echoActive: true,
          db: db,
          preview: preview,
          onPlayOrPause: () => playTaps++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
      await tester.pump();

      expect(playTaps, 1);
    });

    testWidgets(
      'preview stream emits true + loadedPath matches -> pause icon shown',
      (tester) async {
        final env = await _buildEnv(tester);
        final db = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(db.close);
        final preview = _RecordingPreviewStub();
        addTearDown(preview.dispose);
        final row = _row(id: 'e', localPath: '/tmp/e.wav');
        preview.setLoadedPath('/tmp/e.wav');

        await tester.pumpWidget(
          _wrap(
            l10n: env.l10n,
            tt: env.tt,
            scheme: env.scheme,
            tok: env.tok,
            row: row,
            list: [row],
            echoActive: true,
            db: db,
            preview: preview,
          ),
        );
        await tester.pumpAndSettle();
        preview.emitPlaying(true);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'popup menu opens, lists takes numbered descending, current take gets check',
      (tester) async {
        final env = await _buildEnv(tester);
        final db = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(db.close);
        final preview = _RecordingPreviewStub();
        addTearDown(preview.dispose);
        final r1 = _row(id: 'r1', localPath: '/tmp/r1.wav', duration: 1000);
        final r2 = _row(id: 'r2', localPath: '/tmp/r2.wav', duration: 2000);
        final r3 = _row(id: 'r3', localPath: '/tmp/r3.wav', duration: 3000);

        await tester.pumpWidget(
          _wrap(
            l10n: env.l10n,
            tt: env.tt,
            scheme: env.scheme,
            tok: env.tok,
            row: r2, // current is r2 -> take #2 (middle of 3)
            list: [r1, r2, r3],
            echoActive: true,
            db: db,
            preview: preview,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Highest take number (length - 0) shown first when iterating from i=0.
        expect(find.text('Take 3 · 1.0 s'), findsOneWidget);
        expect(find.text('Take 2 · 2.0 s'), findsOneWidget);
        expect(find.text('Take 1 · 3.0 s'), findsOneWidget);
        // Current take gets the check icon.
        expect(find.byIcon(Icons.check), findsOneWidget);
      },
    );

    testWidgets(
      'menu shows the score badge from pronunciationScore on the take',
      (tester) async {
        final env = await _buildEnv(tester);
        final db = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(db.close);
        final preview = _RecordingPreviewStub();
        addTearDown(preview.dispose);
        final row = _row(
          id: 'r1',
          localPath: '/tmp/r1.wav',
          pronunciationScore: 92,
          duration: 1500,
        );

        await tester.pumpWidget(
          _wrap(
            l10n: env.l10n,
            tt: env.tt,
            scheme: env.scheme,
            tok: env.tok,
            row: row,
            list: [row],
            echoActive: true,
            db: db,
            preview: preview,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('92'), findsWidgets);
      },
    );

    testWidgets(
      'menu shows the score badge parsed from assessmentJson when score null',
      (tester) async {
        final env = await _buildEnv(tester);
        final db = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(db.close);
        final preview = _RecordingPreviewStub();
        addTearDown(preview.dispose);
        final row = _row(
          id: 'r1',
          localPath: '/tmp/r1.wav',
          assessmentJson: _kScoredJsonHigh,
          duration: 1500,
        );

        await tester.pumpWidget(
          _wrap(
            l10n: env.l10n,
            tt: env.tt,
            scheme: env.scheme,
            tok: env.tok,
            row: row,
            list: [row],
            echoActive: true,
            db: db,
            preview: preview,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('95'), findsWidgets);
      },
    );

    testWidgets(
      're-assess menu item is disabled when assessmentJson is empty',
      (tester) async {
        final env = await _buildEnv(tester);
        final db = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(db.close);
        final preview = _RecordingPreviewStub();
        addTearDown(preview.dispose);
        final row = _row(id: 'r1', localPath: '/tmp/r1.wav');

        await tester.pumpWidget(
          _wrap(
            l10n: env.l10n,
            tt: env.tt,
            scheme: env.scheme,
            tok: env.tok,
            row: row,
            list: [row],
            echoActive: true,
            db: db,
            preview: preview,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        final reassessItem = tester
            .widgetList<PopupMenuItem<String>>(
              find.byType(PopupMenuItem<String>),
            )
            .firstWhere((it) => it.value == kShadowReassessTakeToken);
        expect(reassessItem.enabled, isFalse);
      },
    );

    testWidgets(
      're-assess menu item is enabled when assessmentJson non-empty',
      (tester) async {
        final env = await _buildEnv(tester);
        final db = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(db.close);
        final preview = _RecordingPreviewStub();
        addTearDown(preview.dispose);
        final row = _row(
          id: 'r1',
          localPath: '/tmp/r1.wav',
          assessmentJson: _kScoredJson,
        );

        await tester.pumpWidget(
          _wrap(
            l10n: env.l10n,
            tt: env.tt,
            scheme: env.scheme,
            tok: env.tok,
            row: row,
            list: [row],
            echoActive: true,
            db: db,
            preview: preview,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        final reassessItem = tester
            .widgetList<PopupMenuItem<String>>(
              find.byType(PopupMenuItem<String>),
            )
            .firstWhere((it) => it.value == kShadowReassessTakeToken);
        expect(reassessItem.enabled, isTrue);
      },
    );

    testWidgets(
      'menu selects an existing take -> onChooseTake called with id',
      (tester) async {
        final env = await _buildEnv(tester);
        final db = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(db.close);
        final preview = _RecordingPreviewStub();
        addTearDown(preview.dispose);
        final r1 = _row(id: 'r1', localPath: '/tmp/r1.wav', duration: 1000);
        final r2 = _row(id: 'r2', localPath: '/tmp/r2.wav', duration: 2000);
        String? chosenId;

        await tester.pumpWidget(
          _wrap(
            l10n: env.l10n,
            tt: env.tt,
            scheme: env.scheme,
            tok: env.tok,
            row: r2,
            list: [r1, r2],
            echoActive: true,
            db: db,
            preview: preview,
            onChooseTake: (id) async => chosenId = id,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        // r1 is at list index 0, so it shows as "Take 2 · 1.0 s".
        await tester.tap(find.text('Take 2 · 1.0 s'));
        await tester.pump();

        expect(chosenId, 'r1');
      },
    );

    testWidgets(
      'menu selects delete -> confirm dialog appears with cancel & confirm',
      (tester) async {
        final env = await _buildEnv(tester);
        final db = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(db.close);
        final preview = _RecordingPreviewStub();
        addTearDown(preview.dispose);
        final row = _row(id: 'r1', localPath: '/tmp/r1.wav', duration: 1500);

        await tester.pumpWidget(
          _wrap(
            l10n: env.l10n,
            tt: env.tt,
            scheme: env.scheme,
            tok: env.tok,
            row: row,
            list: [row],
            echoActive: true,
            db: db,
            preview: preview,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Delete this take?'), findsOneWidget);
        // AlertDialog has exactly one TextButton (cancel) + one FilledButton (delete).
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextButton),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('menu selects delete -> confirm tap invokes onDeleteCurrent', (
      tester,
    ) async {
      final env = await _buildEnv(tester);
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      final preview = _RecordingPreviewStub();
      addTearDown(preview.dispose);
      final row = _row(id: 'r1', localPath: '/tmp/r1.wav', duration: 1500);
      var deleteTaps = 0;

      await tester.pumpWidget(
        _wrap(
          l10n: env.l10n,
          tt: env.tt,
          scheme: env.scheme,
          tok: env.tok,
          row: row,
          list: [row],
          echoActive: true,
          db: db,
          preview: preview,
          onDeleteCurrent: () => deleteTaps++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      // Tap the dialog's confirm FilledButton labeled "Delete".
      final confirmButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Delete'),
      );
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(deleteTaps, 1);
    });

    testWidgets(
      'menu cancels delete dialog -> onDeleteCurrent is NOT invoked',
      (tester) async {
        final env = await _buildEnv(tester);
        final db = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(db.close);
        final preview = _RecordingPreviewStub();
        addTearDown(preview.dispose);
        final row = _row(id: 'r1', localPath: '/tmp/r1.wav', duration: 1500);
        var deleteTaps = 0;

        await tester.pumpWidget(
          _wrap(
            l10n: env.l10n,
            tt: env.tt,
            scheme: env.scheme,
            tok: env.tok,
            row: row,
            list: [row],
            echoActive: true,
            db: db,
            preview: preview,
            onDeleteCurrent: () => deleteTaps++,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        // Tap the cancel TextButton.
        await tester.tap(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextButton),
              )
              .first,
        );
        await tester.pumpAndSettle();

        expect(deleteTaps, 0);
      },
    );

    testWidgets('delete menu item is disabled when echoActive is false', (
      tester,
    ) async {
      final env = await _buildEnv(tester);
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      final preview = _RecordingPreviewStub();
      addTearDown(preview.dispose);
      final row = _row(id: 'r1', localPath: '/tmp/r1.wav');

      await tester.pumpWidget(
        _wrap(
          l10n: env.l10n,
          tt: env.tt,
          scheme: env.scheme,
          tok: env.tok,
          row: row,
          list: [row],
          echoActive: false,
          db: db,
          preview: preview,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      final deleteItem = tester
          .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
          .firstWhere((it) => it.value == kShadowDeleteTakeToken);
      expect(deleteItem.enabled, isFalse);
    });

    testWidgets('_takeNumber fallback returns list.length when id not found', (
      tester,
    ) async {
      final env = await _buildEnv(tester);
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      final preview = _RecordingPreviewStub();
      addTearDown(preview.dispose);
      final orphan = _row(id: 'orphan', localPath: '/tmp/orphan.wav');
      final r1 = _row(id: 'r1', localPath: '/tmp/r1.wav');
      final r2 = _row(id: 'r2', localPath: '/tmp/r2.wav');

      await tester.pumpWidget(
        _wrap(
          l10n: env.l10n,
          tt: env.tt,
          scheme: env.scheme,
          tok: env.tok,
          row: orphan, // not in list
          list: [r1, r2],
          echoActive: true,
          db: db,
          preview: preview,
        ),
      );
      await tester.pumpAndSettle();

      // Take summary on the play button tooltip uses list.length (2)
      // when the row isn't found in list; orphan default duration=1500ms.
      expect(find.byTooltip('Take 2 · 1.5 s'), findsOneWidget);
    });

    testWidgets(
      'pronunciationScoreFromRecording parses json when pronunciationScore null',
      (tester) async {
        final env = await _buildEnv(tester);
        final db = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(db.close);
        final preview = _RecordingPreviewStub();
        addTearDown(preview.dispose);
        final r1 = _row(id: 'r1', assessmentJson: _kScoredJson);
        final r2 = _row(id: 'r2'); // no score, no json
        await tester.pumpWidget(
          _wrap(
            l10n: env.l10n,
            tt: env.tt,
            scheme: env.scheme,
            tok: env.tok,
            row: r1,
            list: [r1, r2],
            echoActive: true,
            db: db,
            preview: preview,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // r1 -> 92 (parsed from JSON), r2 -> no score badge.
        expect(find.text('92'), findsWidgets);
      },
    );
  });
}
