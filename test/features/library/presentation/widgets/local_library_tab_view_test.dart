// Tests for the two tab bodies in `local_library_tab_view.dart`:
// `LocalAudioLibraryBody` and `LocalVideoLibraryBody`.
//
// The bodies branch on `(items.isEmpty, searchQuery.isNotEmpty,
// totalInLibraryOfKind > 0)` to choose one of three views:
//   * Empty + no filter → library-empty title/hint
//   * Empty + filter active → search-no-matches title/hint (with Clear action)
//   * Non-empty → ListView (audio) / GridView (video) of `LocalAudioRow` /
//     `LocalVideoTile` (we don't exercise the row/tile internals here; that
//     requires a ProviderScope + repository/auth overrides).
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/library/presentation/widgets/local_library_tab_view.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _ts = DateTime.utc(2024, 1, 1);

final _audioSample = Media(
  id: 'audio-1',
  kind: MediaKind.audio,
  title: 'Track',
  sourceUri: 'file:///track.mp3',
  durationMs: 60_000,
  language: 'en',
  contentHash: 'h',
  fileSize: 1024,
  createdAt: _ts,
  updatedAt: _ts,
);

final _videoSample = Media(
  id: 'video-1',
  kind: MediaKind.video,
  title: 'Clip',
  sourceUri: 'file:///clip.mp4',
  durationMs: 120_000,
  language: 'ja',
  contentHash: 'h',
  fileSize: 2048,
  createdAt: _ts,
  updatedAt: _ts,
);

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: child),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalAudioLibraryBody', () {
    testWidgets('empty items show the empty-audio placeholder', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const LocalAudioLibraryBody(
            items: <Media>[],
            searchQuery: '',
            totalInLibraryOfKind: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(LocalAudioLibraryBody));
      final loc = AppLocalizations.of(ctx)!;
      expect(find.text(loc.libraryEmptyAudioTitle), findsOneWidget);
      expect(find.text(loc.libraryEmptyAudioHint), findsOneWidget);
    });

    testWidgets(
      'empty items + active search + library has audio → search empty CTA',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const LocalAudioLibraryBody(
              items: <Media>[],
              searchQuery: 'hello',
              totalInLibraryOfKind: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final ctx = tester.element(find.byType(LocalAudioLibraryBody));
        final loc = AppLocalizations.of(ctx)!;
        expect(find.text(loc.librarySearchNoMatchesTitle), findsOneWidget);
        expect(find.text(loc.librarySearchNoMatchesHint), findsOneWidget);
        expect(find.text(loc.librarySearchClear), findsOneWidget);
      },
    );

    testWidgets('non-empty items render a listview of MediaCardRow rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LocalAudioLibraryBody(
            items: [_audioSample],
            searchQuery: '',
            totalInLibraryOfKind: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The row title is rendered by MediaCardRow.
      expect(find.text('Track'), findsOneWidget);
    });
  });

  group('LocalVideoLibraryBody', () {
    testWidgets('empty items show the empty-video placeholder', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const LocalVideoLibraryBody(
            items: <Media>[],
            searchQuery: '',
            totalInLibraryOfKind: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(LocalVideoLibraryBody));
      final loc = AppLocalizations.of(ctx)!;
      expect(find.text(loc.libraryEmptyVideoTitle), findsOneWidget);
      expect(find.text(loc.libraryEmptyVideoHint), findsOneWidget);
    });

    testWidgets(
      'empty items + active search + library has video → search empty CTA',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const LocalVideoLibraryBody(
              items: <Media>[],
              searchQuery: 'xyz',
              totalInLibraryOfKind: 7,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final ctx = tester.element(find.byType(LocalVideoLibraryBody));
        final loc = AppLocalizations.of(ctx)!;
        expect(find.text(loc.librarySearchNoMatchesTitle), findsOneWidget);
        expect(find.text(loc.librarySearchClear), findsOneWidget);
      },
    );

    testWidgets('non-empty items render a gridview of MediaCardTile tiles', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LocalVideoLibraryBody(
            items: [_videoSample],
            searchQuery: '',
            totalInLibraryOfKind: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title text reaches the MediaCardTile subtree.
      expect(find.text('Clip'), findsOneWidget);
    });
  });
}
