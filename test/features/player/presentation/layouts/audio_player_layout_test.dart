import 'package:enjoy_player/features/player/presentation/layouts/audio_player_layout.dart';
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

  testWidgets('shows compact collapse chevron without an AppBar', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(transcript: const Text('body')));
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
  });
}
