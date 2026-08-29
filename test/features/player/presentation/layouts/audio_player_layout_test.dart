import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/player/presentation/layouts/audio_player_layout.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_frosted_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({required Widget transcript}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: AudioPlayerLayout(transcript: transcript)),
    ),
  );
}

/// The Padding that wraps the transcript column (closest ancestor).
Padding _transcriptPadding(WidgetTester tester, String text) {
  return tester.widget<Padding>(
    find.ancestor(of: find.text(text), matching: find.byType(Padding)).first,
  );
}

void main() {
  testWidgets('renders transcript widget centered with max-width constraint', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(transcript: const Text('transcript body')));
    await tester.pump();

    expect(find.text('transcript body'), findsOneWidget);
    // The transcript is wrapped in a ConstrainedBox(maxWidth: contentMaxWidth).
    final constrainedBoxes = find
        .byWidgetPredicate((w) => w is ConstrainedBox)
        .evaluate();
    expect(constrainedBoxes, isNotEmpty);
  });

  testWidgets('shows floating frosted collapse control without an AppBar', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(transcript: const Text('body')));
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(PlayerFrostedBackButton), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
    // No reserved toolbar strip: the only fixed-height boxes belong to the
    // 38x38 frosted control itself.
    expect(
      find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == kToolbarHeight,
      ),
      findsNothing,
    );
  });

  testWidgets('desktop adds a roomier top inset for optical balance', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(transcript: const Text('body')));
    await tester.pump();

    final t = EnjoyThemeTokens.build(
      ThemeData(brightness: Brightness.light).colorScheme,
    );
    expect(
      _transcriptPadding(tester, 'body').padding,
      EdgeInsets.fromLTRB(t.space12, t.space32, t.space12, t.space16),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('mobile keeps compact top inset under the status-bar area', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(transcript: const Text('body')));
    await tester.pump();

    final t = EnjoyThemeTokens.build(
      ThemeData(brightness: Brightness.light).colorScheme,
    );
    expect(
      _transcriptPadding(tester, 'body').padding,
      EdgeInsets.fromLTRB(t.space12, t.space16, t.space12, t.space16),
    );
  });
}
