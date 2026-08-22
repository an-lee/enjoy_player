import 'package:drift/native.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_state_providers.dart';
import 'package:enjoy_player/features/transcript/application/transcript_line_recording_counts_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_playback_highlight_provider.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_scrollable_list.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

const _mediaId = 'media-scroll-test';

late AppDatabase _scrollTestDb;

List<Override> _scrollTestDbOverrides() => [
  deviceGlobalAppDatabaseProvider.overrideWithValue(_scrollTestDb),
  appDatabaseProvider.overrideWithValue(_scrollTestDb),
];

class _TestHighlightIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
}

/// Drives [transcriptPlaybackHighlightProvider] in widget tests.
final _testHighlightIndexProvider =
    NotifierProvider<_TestHighlightIndexNotifier, int>(
      _TestHighlightIndexNotifier.new,
    );

List<TranscriptLine> _sampleLines(int count) => List.generate(
  count,
  (i) => TranscriptLine(
    text: 'Transcript line $i',
    startMs: i * 1000,
    durationMs: 1000,
  ),
);

Future<void> _disposeHarness(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

List<Override> _scrollTestOverrides({
  int highlightIndex = 0,
  Map<int, int>? recordingCounts,
  bool echoLinkedRecordingCounts = false,
  List<TranscriptLine>? lines,
}) {
  final lineList = lines ?? const <TranscriptLine>[];
  return [
    ..._scrollTestDbOverrides(),
    playerIsPlayingProvider.overrideWith((ref) => Stream.value(true)),
    transcriptLinesForMediaProvider(
      _mediaId,
    ).overrideWith((ref) => Stream.value(lineList)),
    secondaryTranscriptLinesForMediaProvider(
      _mediaId,
    ).overrideWith((ref) => Stream.value(const <TranscriptLine>[])),
    if (echoLinkedRecordingCounts)
      transcriptLineRecordingCountsProvider(_mediaId).overrideWith((ref) {
        final idx = ref.watch(echoModeProvider.select((e) => e.startLineIndex));
        if (idx < 0) return const {};
        return {idx: idx + 1};
      })
    else
      transcriptLineRecordingCountsProvider(
        _mediaId,
      ).overrideWithValue(recordingCounts ?? const {}),
    transcriptPlaybackHighlightProvider(
      _mediaId,
    ).overrideWith((ref) => (cueIndex: highlightIndex, wordIndex: null)),
  ];
}

List<Override> _scrollTestOverridesWithMutableHighlight({
  required List<TranscriptLine> lines,
}) {
  return [
    ..._scrollTestDbOverrides(),
    playerIsPlayingProvider.overrideWith((ref) => Stream.value(true)),
    transcriptLinesForMediaProvider(
      _mediaId,
    ).overrideWith((ref) => Stream.value(lines)),
    secondaryTranscriptLinesForMediaProvider(
      _mediaId,
    ).overrideWith((ref) => Stream.value(const <TranscriptLine>[])),
    transcriptLineRecordingCountsProvider(_mediaId).overrideWithValue(const {}),
    transcriptPlaybackHighlightProvider(_mediaId).overrideWith(
      (ref) =>
          (cueIndex: ref.watch(_testHighlightIndexProvider), wordIndex: null),
    ),
  ];
}

Widget _harness({required Widget child, required List<Override> overrides}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF003366));
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// Rapidly advances echo one line at a time to exercise list rebuild + scroll.
class _EchoLineAdvanceHarness extends ConsumerStatefulWidget {
  const _EchoLineAdvanceHarness({required this.lines});

  final List<TranscriptLine> lines;

  @override
  ConsumerState<_EchoLineAdvanceHarness> createState() =>
      _EchoLineAdvanceHarnessState();
}

class _EchoLineAdvanceHarnessState
    extends ConsumerState<_EchoLineAdvanceHarness> {
  var _step = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_advanceEchoLine);
  }

  void _advanceEchoLine(_) {
    if (!mounted || _step >= widget.lines.length) return;

    final i = _step++;
    final line = widget.lines[i];
    ref
        .read(echoModeProvider.notifier)
        .activate(
          startLineIndex: i,
          endLineIndex: i,
          startTimeSeconds: line.startSeconds,
          endTimeSeconds: line.endSeconds,
        );

    WidgetsBinding.instance.addPostFrameCallback(_advanceEchoLine);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: TranscriptScrollableList(mediaId: _mediaId, lines: widget.lines),
    );
  }
}

void main() {
  setUp(() {
    _scrollTestDb = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await _scrollTestDb.close();
  });

  testWidgets('rapid echo line changes do not throw framework assertions', (
    tester,
  ) async {
    final lines = _sampleLines(6);

    await tester.pumpWidget(
      _harness(
        overrides: _scrollTestOverrides(lines: lines),
        child: _EchoLineAdvanceHarness(lines: lines),
      ),
    );

    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }

    expect(find.text('Transcript line 5'), findsOneWidget);
    await _disposeHarness(tester);
  });

  testWidgets('recording count updates during echo navigation stay stable', (
    tester,
  ) async {
    final lines = _sampleLines(4);
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: _scrollTestOverrides(
          echoLinkedRecordingCounts: true,
          lines: lines,
        ),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            final scheme = ColorScheme.fromSeed(
              seedColor: const Color(0xFF003366),
            );
            return MaterialApp(
              theme: ThemeData(
                colorScheme: scheme,
                extensions: [EnjoyThemeTokens.build(scheme)],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  height: 400,
                  child: TranscriptScrollableList(
                    mediaId: _mediaId,
                    lines: lines,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pump();

    for (var i = 0; i < lines.length; i++) {
      container
          .read(echoModeProvider.notifier)
          .activate(
            startLineIndex: i,
            endLineIndex: i,
            startTimeSeconds: lines[i].startSeconds,
            endTimeSeconds: lines[i].endSeconds,
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }

    expect(find.text('4'), findsOneWidget);
    await _disposeHarness(tester);
  });

  testWidgets(
    'unmount during echo scroll does not throw framework assertions',
    (tester) async {
      final lines = _sampleLines(8);
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: _scrollTestOverrides(highlightIndex: 2, lines: lines),
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              final scheme = ColorScheme.fromSeed(
                seedColor: const Color(0xFF003366),
              );
              return MaterialApp(
                theme: ThemeData(
                  colorScheme: scheme,
                  extensions: [EnjoyThemeTokens.build(scheme)],
                ),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: SizedBox(
                    height: 400,
                    child: TranscriptScrollableList(
                      mediaId: _mediaId,
                      lines: lines,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();

      container
          .read(echoModeProvider.notifier)
          .activate(
            startLineIndex: 3,
            endLineIndex: 3,
            startTimeSeconds: lines[3].startSeconds,
            endTimeSeconds: lines[3].endSeconds,
          );
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('active line scrolls into view with mid-viewport bias', (
    tester,
  ) async {
    const activeIndex = 15;
    final lines = _sampleLines(30);
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: _scrollTestOverridesWithMutableHighlight(lines: lines),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            final scheme = ColorScheme.fromSeed(
              seedColor: const Color(0xFF003366),
            );
            return MaterialApp(
              theme: ThemeData(
                colorScheme: scheme,
                extensions: [EnjoyThemeTokens.build(scheme)],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  height: 400,
                  width: 360,
                  child: TranscriptScrollableList(
                    mediaId: _mediaId,
                    lines: lines,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    container.read(_testHighlightIndexProvider.notifier).state = activeIndex;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final activeText = find.text('Transcript line $activeIndex');
    expect(activeText, findsOneWidget);

    final transcriptListView = find.descendant(
      of: find.byType(TranscriptScrollableList),
      matching: find.byType(ListView),
    );
    expect(transcriptListView, findsOneWidget);

    final viewportRect = tester.getRect(transcriptListView);
    final activeRect = tester.getRect(activeText);

    expect(viewportRect.overlaps(activeRect), isTrue);
    expect(activeRect.top, greaterThan(viewportRect.top + 24));
    expect(activeRect.bottom, lessThan(viewportRect.bottom));
    await _disposeHarness(tester);
  });
}
