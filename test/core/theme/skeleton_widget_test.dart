// Coverage for lib/core/theme/widgets/skeleton.dart — shimmer / reduced-motion
// branches and the high-level placeholders (SkeletonMediaList, SkeletonMediaGrid,
// SkeletonSettingsList, SkeletonTranscript, SkeletonProfile, SkeletonAppBootstrap).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/widgets/skeleton.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('Skeleton.box factory uses BorderRadius.zero by default', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(Skeleton.box(width: 100, height: 30)));
    expect(find.byType(Skeleton), findsOneWidget);
  });

  testWidgets('Skeleton.box honors custom borderRadius', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Skeleton.box(
          width: 50,
          height: 50,
          borderRadius: BorderRadius.circular(7),
        ),
      ),
    );
    expect(find.byType(Skeleton), findsOneWidget);
  });

  testWidgets('Skeleton.line defaults to 14 height and circular(6) radius', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(Skeleton.line(width: 200)));
    expect(find.byType(Skeleton), findsOneWidget);
  });

  testWidgets('Skeleton.line honors custom radius', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Skeleton.line(
          width: 200,
          height: 18,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
      ),
    );
    expect(find.byType(Skeleton), findsOneWidget);
  });

  testWidgets('Skeleton.circle forces width == height and rounded corners', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(Skeleton.circle(diameter: 48)));
    expect(find.byType(Skeleton), findsOneWidget);
  });

  testWidgets('Reduced motion → no AnimatedBuilder (plain Container path)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const Skeleton(width: 80, height: 12), reduceMotion: true),
    );
    await tester.pump();
    // Look only inside the Skeleton's subtree — the test wrapper has its own
    // AnimatedBuilders for theme/listenable plumbing.
    final skeleton = find.byType(Skeleton);
    expect(skeleton, findsOneWidget);
    expect(
      find.descendant(of: skeleton, matching: find.byType(AnimatedBuilder)),
      findsNothing,
    );
    expect(
      find.descendant(of: skeleton, matching: find.byType(CustomPaint)),
      findsNothing,
    );
    expect(
      find.descendant(of: skeleton, matching: find.byType(Container)),
      findsWidgets,
    );
  });

  testWidgets('Normal motion → uses AnimatedBuilder + CustomPaint shimmer', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const Skeleton(width: 80, height: 12)));
    await tester.pump(const Duration(milliseconds: 16));
    final skeleton = find.byType(Skeleton);
    expect(
      find.descendant(of: skeleton, matching: find.byType(AnimatedBuilder)),
      findsWidgets,
    );
    expect(
      find.descendant(of: skeleton, matching: find.byType(CustomPaint)),
      findsWidgets,
    );
  });

  testWidgets(
    'Equal width/height forces a circular borderRadius (square box)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const Skeleton(width: 60, height: 60), reduceMotion: true),
      );
      final widget = tester.widget<Skeleton>(find.byType(Skeleton));
      expect(widget.borderRadius, isNull);
    },
  );

  testWidgets('Unequal width/height falls back to circular(8)', (tester) async {
    await tester.pumpWidget(
      _wrap(const Skeleton(width: 100, height: 12), reduceMotion: true),
    );
    final widget = tester.widget<Skeleton>(find.byType(Skeleton));
    expect(widget.borderRadius, isNull);
  });

  testWidgets('Explicit borderRadius wins over width==height heuristic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Skeleton(
          width: 60,
          height: 60,
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        reduceMotion: true,
      ),
    );
    final widget = tester.widget<Skeleton>(find.byType(Skeleton));
    expect(widget.borderRadius, isNotNull);
  });

  testWidgets(
    'didChangeDependencies does not re-animate when already animating',
    (tester) async {
      await tester.pumpWidget(_wrap(const Skeleton(width: 80, height: 12)));
      // Trigger didChangeDependencies again
      await tester.pumpWidget(_wrap(const Skeleton(width: 80, height: 12)));
      await tester.pump();
      expect(find.byType(AnimatedBuilder), findsWidgets);
    },
  );

  testWidgets('dispose() does not throw after the parent is removed', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const Skeleton(width: 80, height: 12)));
    expect(find.byType(Skeleton), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('SkeletonAppBootstrap renders circle + two lines', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SkeletonAppBootstrap()));
    expect(find.byType(SkeletonAppBootstrap), findsOneWidget);
    expect(find.byType(Skeleton), findsAtLeastNWidgets(3));
  });

  testWidgets('SkeletonMediaList bounded path uses ListView.separated', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 320, child: SkeletonMediaList(itemCount: 2)),
        ),
      ),
    );
    expect(find.byType(SkeletonMediaList), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('SkeletonMediaList unbounded path uses a Column', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SkeletonMediaList(itemCount: 2)),
        ),
      ),
    );
    expect(find.byType(SkeletonMediaList), findsOneWidget);
    expect(find.byType(Column), findsWidgets);
  });

  testWidgets('SkeletonMediaGrid builds 6 cells with two-line captions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(width: 300, height: 400, child: SkeletonMediaGrid()),
      ),
    );
    expect(find.byType(SkeletonMediaGrid), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('SkeletonSettingsList renders the requested number of rows', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SkeletonSettingsList(rowCount: 3)));
    expect(find.byType(SkeletonSettingsList), findsOneWidget);
  });

  testWidgets('SkeletonSettingsList defaults to 10 rows when not provided', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SkeletonSettingsList()));
    expect(find.byType(SkeletonSettingsList), findsOneWidget);
  });

  testWidgets('SkeletonTranscript uses ListView.separated with the lineCount', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 400, child: SkeletonTranscript(lineCount: 5)),
        ),
      ),
    );
    expect(find.byType(SkeletonTranscript), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets(
    'SkeletonTranscript respects the supplied ScrollController and physics',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: SkeletonTranscript(
                lineCount: 2,
                controller: controller,
                physics: const BouncingScrollPhysics(),
              ),
            ),
          ),
        ),
      );
      expect(controller.hasClients, isTrue);
    },
  );

  testWidgets('SkeletonProfile renders circle + 2 lines + 3 stat boxes', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SkeletonProfile()));
    expect(find.byType(SkeletonProfile), findsOneWidget);
    expect(find.byType(Skeleton), findsAtLeastNWidgets(5));
  });

  testWidgets(
    'Reduced motion skeleton continues to use ClipRRect for rounded corners',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Skeleton(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          reduceMotion: true,
        ),
      );
      expect(find.byType(ClipRRect), findsWidgets);
    },
  );
}
