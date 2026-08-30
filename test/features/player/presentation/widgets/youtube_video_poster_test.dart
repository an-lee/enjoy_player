import 'package:enjoy_player/features/player/presentation/widgets/youtube_video_poster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YoutubeVideoPoster', () {
    testWidgets('renders SizedBox.shrink when primaryUrl is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: YoutubeVideoPoster(primaryUrl: null)),
        ),
      );

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('renders SizedBox.shrink when primaryUrl is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: YoutubeVideoPoster(primaryUrl: '')),
        ),
      );

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('fades out over 220ms before leaving the tree', (tester) async {
      // Issue #662: `visible: false` used to return SizedBox.shrink()
      // directly, so the AnimatedOpacity was replaced before it could animate
      // to 0 — the fade-out was dead code.
      var visible = true;
      late StateSetter setVisible;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setVisible = setState;
                return YoutubeVideoPoster(
                  primaryUrl: 'https://example.com/thumb.jpg',
                  visible: visible,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AnimatedOpacity), findsOneWidget);

      setVisible(() => visible = false);
      await tester.pump();

      // Mid-fade: still mounted, on its way to transparent.
      final opacity = tester
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .opacity;
      expect(opacity, 0, reason: 'the fade target is fully transparent');
      expect(find.byType(Image), findsOneWidget);

      // After the fade the poster leaves the tree instead of painting an
      // invisible image forever.
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
    });

    testWidgets(
      'attempts to load the network image when visible and non-empty',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 200,
                child: YoutubeVideoPoster(
                  primaryUrl: 'https://example.com/thumb.jpg',
                ),
              ),
            ),
          ),
        );

        // AnimatedOpacity + Image.network with a fake URL: image will fail to
        // resolve, but the Image widget should still be present.
        expect(find.byType(Image), findsOneWidget);
      },
    );

    testWidgets('switches activeUrl when primaryUrl prop changes', (
      tester,
    ) async {
      var url = 'https://example.com/first.jpg';
      late StateSetter setUrl;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setUrl = setState;
                return SizedBox(
                  width: 320,
                  height: 200,
                  child: YoutubeVideoPoster(primaryUrl: url),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);

      setUrl(() {
        url = 'https://example.com/second.jpg';
      });
      await tester.pump();

      // The Image widget is rebuilt with the new URL; the AnimatedOpacity
      // is still in the tree.
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });
  });
}
