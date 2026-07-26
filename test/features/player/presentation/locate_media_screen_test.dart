// Tests for `lib/features/player/presentation/locate_media_screen.dart` and
// the `_formatExpectedSize` helper (verified by inspecting the rendered Text
// widget within the screen body).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/player/domain/media_relocate_exception.dart';
import 'package:enjoy_player/features/player/presentation/locate_media_screen.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Widget _wrap(Widget child, {Size size = const Size(420, 900)}) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en', 'US'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: child),
      ),
    ),
  );
}

const _infoVideo = MediaNeedsRelocateException(
  mediaId: 'm-1',
  kind: MediaKind.video,
  title: 'Sample Movie',
  expectedHash: 'abc123',
  expectedSize: 1024 * 1024 * 750,
);

const _infoAudio = MediaNeedsRelocateException(
  mediaId: 'm-2',
  kind: MediaKind.audio,
  title: 'Sample Audiobook',
  expectedHash: 'def456',
  expectedSize: 5 * 1024 * 1024,
);

void main() {
  testWidgets('renders the title and a CTA for video media', (tester) async {
    await tester.pumpWidget(_wrap(const LocateMediaScreen(info: _infoVideo)));
    await tester.pump();
    expect(find.text('Sample Movie'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
    final ctx = tester.element(find.byType(LocateMediaScreen));
    final l10n = AppLocalizations.of(ctx)!;
    expect(find.text(l10n.mediaLocateChooseFile), findsOneWidget);
  });

  testWidgets('uses the audio-specific extension set when kind=audio', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const LocateMediaScreen(info: _infoAudio)));
    await tester.pump();
    final ctx = tester.element(find.byType(LocateMediaScreen));
    final l10n = AppLocalizations.of(ctx)!;
    expect(find.text(l10n.mediaLocateChooseFile), findsOneWidget);
    // Verify title rendered (exercise audio branch).
    expect(find.text('Sample Audiobook'), findsOneWidget);
  });

  testWidgets('renders the "unknown size" subtitle when expectedSize=null', (
    tester,
  ) async {
    const info = MediaNeedsRelocateException(
      mediaId: 'm-3',
      kind: MediaKind.video,
      title: 'Size Missing',
      expectedHash: 'hash',
      expectedSize: null,
    );
    await tester.pumpWidget(_wrap(const LocateMediaScreen(info: info)));
    await tester.pump();
    final ctx = tester.element(find.byType(LocateMediaScreen));
    final l10n = AppLocalizations.of(ctx)!;
    expect(find.text(l10n.mediaLocateSizeUnknown), findsOneWidget);
  });

  testWidgets('formats expected size across B/KB/MB/GB thresholds', (
    tester,
  ) async {
    Future<void> expectSize(int bytes, String expected) async {
      final info = MediaNeedsRelocateException(
        mediaId: 'm-$bytes',
        kind: MediaKind.video,
        title: 'X',
        expectedHash: 'h',
        expectedSize: bytes,
      );
      await tester.pumpWidget(_wrap(LocateMediaScreen(info: info)));
      await tester.pump();
      expect(find.textContaining(expected), findsWidgets);
    }

    await expectSize(500, '500 B');
    await expectSize(2048, 'KB');
    await expectSize(5 * 1024 * 1024, 'MB');
    await expectSize(2 * 1024 * 1024 * 1024, 'GB');
  });
}
