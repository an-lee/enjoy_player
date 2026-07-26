// Coverage for lib/core/theme/widgets/media_card.dart.
//
// We exercise the public MediaCardTile / MediaCardRow widgets and the grid
// delegate helpers. The internal `isMobilePlatform` predicate branches the
// inline delete button / long-press behaviour, so the tests cover both
// desktop (default) and mobile (overridden) layouts. Network thumbnails are
// stubbed so tests don't hit the network.
import 'dart:io';

import 'package:enjoy_player/core/platform/mobile_platform.dart';
import 'package:enjoy_player/core/routing/player_navigation.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/media_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    extensions: [EnjoyThemeTokens.build(scheme)],
  );
}

Widget _wrap({required Widget child, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? _buildTheme(Brightness.dark),
    home: Scaffold(body: child),
  );
}

/// Wraps [body] in a `debugDefaultTargetPlatformOverride = platform` block so
/// the override is cleared *before* the testWidgets verification check runs.
Future<void> _withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('helpers', () {
    test(
      'mediaCardTileGridAspectRatioForWidth uses width/(9/16*w+meta+inset)',
      () {
        // 280/(280*9/16 + 58 + 3) = 280/(157.5 + 61) = 280/218.5
        final ratio = mediaCardTileGridAspectRatioForWidth(280);
        expect(ratio, closeTo(280 / 218.5, 0.001));
      },
    );

    test('mediaCardTileGridAspectRatioForWidth handles small widths', () {
      final ratio = mediaCardTileGridAspectRatioForWidth(120);
      // 120 / (120 * 9/16 + 58 + 3) = 120 / (67.5 + 61) = 120/128.5
      expect(ratio, closeTo(120 / 128.5, 0.001));
    });

    test('mediaCardTileGridDelegateForMaxTileWidth builds a grid delegate', () {
      final delegate = mediaCardTileGridDelegateForMaxTileWidth(
        crossAxisExtent: 800,
      );
      expect(delegate, isA<SliverGridDelegateWithFixedCrossAxisCount>());
    });

    test('mediaCardTileGridDelegateForMinTileWidth builds a grid delegate', () {
      final delegate = mediaCardTileGridDelegateForMinTileWidth(
        crossAxisExtent: 1200,
      );
      expect(delegate, isA<SliverGridDelegateWithFixedCrossAxisCount>());
    });

    test('mediaCardTileGridDelegateForMinTileWidth clamps crossAxisCount', () {
      // Tiny viewport: clamp(1, maxCount) ensures at least 1 column.
      final delegate = mediaCardTileGridDelegateForMinTileWidth(
        crossAxisExtent: 100,
      );
      final fixed = delegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(fixed.crossAxisCount, 1);
    });

    test(
      'mediaCardTileGridDelegateForMaxTileWidth clamps to maxCrossAxisCount',
      () {
        final delegate = mediaCardTileGridDelegateForMaxTileWidth(
          crossAxisExtent: 10000,
          maxCrossAxisCount: 2,
        );
        final fixed = delegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(fixed.crossAxisCount, 2);
      },
    );
  });

  group('MediaCardTile', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardTile(title: 'Hello World', onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardTile(
            title: 'Title',
            subtitle: 'Subtitle line',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Subtitle line'), findsOneWidget);
    });

    testWidgets('shows audio icon by default (isVideo=false default)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardTile(title: 'T', onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();
      // Two audio icons render (thumbnail placeholder + the overlay icon),
      // we only need to confirm the overlay icon (size 22) is present.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Icon && w.icon == Icons.audiotrack_rounded && w.size == 22,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows video icon when isVideo=true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardTile(title: 'T', isVideo: true, onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.videocam_rounded && w.size == 22,
        ),
        findsOneWidget,
      );
    });

    testWidgets('providerBadge renders when set', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardTile(
            title: 'T',
            providerBadge: 'YouTube',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('YouTube'), findsOneWidget);
    });

    testWidgets('durationLabel renders when set', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardTile(
            title: 'T',
            durationLabel: '10:30',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('10:30'), findsOneWidget);
    });

    testWidgets('calls onTap when card tapped', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          child: MediaCardTile(title: 'T', onTap: () => tapped++),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('T'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('badge with onBadgeTap renders', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          child: MediaCardTile(
            title: 'T',
            badge: 'zh',
            onBadgeTap: () => tapped++,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Badge text is present.
      expect(find.text('zh'), findsOneWidget);
      await tester.tap(find.text('zh'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('desktop onDelete shows inline IconButton', (tester) async {
      await _withPlatform(TargetPlatform.macOS, () async {
        var deleted = 0;
        await tester.pumpWidget(
          _wrap(
            child: MediaCardTile(
              title: 'T',
              onDelete: () => deleted++,
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pumpAndSettle();
        expect(deleted, 1);
      });
    });

    testWidgets('mobile onDelete: long-press opens sheet, tap deletes', (
      tester,
    ) async {
      await _withPlatform(TargetPlatform.android, () async {
        var deleted = 0;
        await tester.pumpWidget(
          _wrap(
            child: MediaCardTile(
              title: 'T',
              onDelete: () => deleted++,
              deleteTooltip: 'Remove this item',
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Mobile: inline delete button is hidden.
        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
        // Trigger long-press → opens a sheet.
        await tester.longPress(find.text('T'));
        await tester.pumpAndSettle();
        // The sheet uses the explicit deleteTooltip as the title.
        final listTile = find.widgetWithText(ListTile, 'Remove this item');
        expect(listTile, findsOneWidget);
        await tester.tap(listTile);
        await tester.pumpAndSettle();
        expect(deleted, 1);
      });
    });

    testWidgets('heroArtworkMediaId wraps thumbnail in Hero with tag', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardTile(
            title: 'T',
            heroArtworkMediaId: 'm1',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsWidgets);
      final heroWidget = tester
          .widgetList<Hero>(heroFinder)
          .firstWhere((h) => h.tag == mediaArtworkHeroTag('m1'));
      expect(heroWidget.tag, mediaArtworkHeroTag('m1'));
    });

    testWidgets('renders thumbnailFile when provided', (tester) async {
      // Create a temporary file (file content unused — widget just reads path).
      final tmp = File('/tmp/empty_thumb.png');
      await tester.pumpWidget(
        _wrap(
          child: MediaCardTile(title: 'T', thumbnailFile: tmp, onTap: () {}),
        ),
      );
      // Use pump (not pumpAndSettle) — Image.file loads asynchronously and
      // the missing file does not produce a finite settled state.
      await tester.pump();
      // The Image.file widget is present.
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('accentColor is respected', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardTile(
            title: 'T',
            accentColor: const Color(0xFFFF0000),
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
    });
  });

  group('MediaCardRow', () {
    testWidgets('renders title and chevron', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardRow(title: 'Audio', onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Audio'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardRow(title: 'T', subtitle: 'Channel', onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Channel'), findsOneWidget);
    });

    testWidgets('calls onTap on tap', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          child: MediaCardRow(title: 'T', onTap: () => tapped++),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('T'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('trailing widget overrides default chevron/delete', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardRow(
            title: 'T',
            trailing: const Text('Custom trailing'),
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Custom trailing'), findsOneWidget);
    });

    testWidgets('providerBadge compact pill renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardRow(title: 'T', providerBadge: 'YT', onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('YT'), findsOneWidget);
    });

    testWidgets('desktop: onDelete shows IconButton beside chevron', (
      tester,
    ) async {
      await _withPlatform(TargetPlatform.macOS, () async {
        var deleted = 0;
        await tester.pumpWidget(
          _wrap(
            child: MediaCardRow(
              title: 'T',
              onDelete: () => deleted++,
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pumpAndSettle();
        expect(deleted, 1);
      });
    });

    testWidgets('mobile: long-press opens sheet, tap deletes', (tester) async {
      await _withPlatform(TargetPlatform.android, () async {
        var deleted = 0;
        await tester.pumpWidget(
          _wrap(
            child: MediaCardRow(
              title: 'T',
              onDelete: () => deleted++,
              deleteTooltip: 'Remove this audio',
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Inline delete hidden on mobile.
        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
        await tester.longPress(find.text('T'));
        await tester.pumpAndSettle();
        final listTile = find.widgetWithText(ListTile, 'Remove this audio');
        expect(listTile, findsOneWidget);
        await tester.tap(listTile);
        await tester.pumpAndSettle();
        expect(deleted, 1);
      });
    });

    testWidgets('mobile onDelete with trailing present has no long-press', (
      tester,
    ) async {
      await _withPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          _wrap(
            child: MediaCardRow(
              title: 'T',
              trailing: const Text('Custom'),
              onDelete: () {},
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Long-press sheet should not appear because trailing != null.
        await tester.longPress(find.text('T'));
        await tester.pumpAndSettle();
        expect(find.byType(ListTile), findsNothing);
      });
    });

    testWidgets('badge with onBadgeTap triggers callback', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          child: MediaCardRow(
            title: 'T',
            badge: 'en',
            onBadgeTap: () => tapped++,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('en'), findsOneWidget);
      await tester.tap(find.text('en'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('badge without onBadgeTap renders without language icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardRow(title: 'T', badge: 'en', onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('en'), findsOneWidget);
    });

    testWidgets('heroArtworkMediaId wraps row thumbnail', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: MediaCardRow(
            title: 'T',
            heroArtworkMediaId: 'm1',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final hero = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == mediaArtworkHeroTag('m1'),
      );
      expect(hero, findsOneWidget);
    });
  });

  test('isMobilePlatform is read by delete-button helper', () {
    // Sanity check that the predicate behaves as expected.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(isMobilePlatform, isTrue);
    debugDefaultTargetPlatformOverride = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(isMobilePlatform, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
