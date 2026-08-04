import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/widgets/shadow_record_fab.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/widgets/shadow_reading_toolbar_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('takes actions stay hittable inside a phone-width half budget', (
    tester,
  ) async {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1144AA));
    final tok = EnjoyThemeTokens.build(scheme);
    var assessTaps = 0;

    // ~369dp phone content width after list padding (matches Xiaomi 15-class).
    await tester.binding.setSurfaceSize(const Size(345, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme, extensions: [tok]),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 345,
              child: ShadowReadingToolbarRow(
                tok: tok,
                scheme: scheme,
                pitchExpanded: false,
                pitchTooltip: 'pitch',
                hasMediaPath: true,
                onPitchTap: () {},
                takesActions: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          key: const Key('assess'),
                          onTap: () => assessTaps++,
                          child: const Icon(Icons.auto_awesome_rounded),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
                recordFab: const SizedBox(
                  width: ShadowRecordFab.ringOuterHitSize,
                  height: ShadowRecordFab.ringOuterHitSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assess')));
    await tester.pump();
    expect(assessTaps, 1);
  });

  testWidgets('leadingShare renders before the pitch toggle', (tester) async {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1144AA));
    final tok = EnjoyThemeTokens.build(scheme);

    await tester.binding.setSurfaceSize(const Size(800, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme, extensions: [tok]),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 800,
              child: ShadowReadingToolbarRow(
                tok: tok,
                scheme: scheme,
                pitchExpanded: false,
                pitchTooltip: 'pitch',
                hasMediaPath: true,
                onPitchTap: () {},
                leadingShare: const IconButton(
                  key: Key('share'),
                  onPressed: null,
                  icon: Icon(Icons.ios_share_rounded),
                ),
                takesActions: null,
                recordFab: const SizedBox(
                  width: ShadowRecordFab.ringOuterHitSize,
                  height: ShadowRecordFab.ringOuterHitSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('share')), findsOneWidget);
    final shareX = tester.getCenter(find.byKey(const Key('share'))).dx;
    final pitchX = tester.getCenter(find.byIcon(Icons.show_chart_rounded)).dx;
    expect(shareX, lessThan(pitchX));
  });

  testWidgets('no leadingShare keeps the original pitch-only layout', (
    tester,
  ) async {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1144AA));
    final tok = EnjoyThemeTokens.build(scheme);

    await tester.binding.setSurfaceSize(const Size(800, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme, extensions: [tok]),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 800,
              child: ShadowReadingToolbarRow(
                tok: tok,
                scheme: scheme,
                pitchExpanded: false,
                pitchTooltip: 'pitch',
                hasMediaPath: true,
                onPitchTap: () {},
                takesActions: null,
                recordFab: const SizedBox(
                  width: ShadowRecordFab.ringOuterHitSize,
                  height: ShadowRecordFab.ringOuterHitSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    expect(find.byIcon(Icons.show_chart_rounded), findsOneWidget);
  });
}
