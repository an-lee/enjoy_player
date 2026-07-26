import 'package:enjoy_player/features/vocabulary/presentation/widgets/flashcard_soft_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the message text inside a DecoratedBox', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlashcardSoftError(message: 'Tap to reveal answer'),
        ),
      ),
    );

    expect(find.text('Tap to reveal answer'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
  });

  testWidgets('truncates long messages instead of overflowing', (tester) async {
    final longMessage = 'Very long error: ' * 30;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FlashcardSoftError(message: longMessage)),
      ),
    );

    expect(find.byType(Text), findsOneWidget);
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, longMessage);
  });

  testWidgets('uses errorContainer background with onErrorContainer text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FlashcardSoftError(message: 'Error!')),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    final theme = ThemeData.light();
    expect(text.style?.color, theme.colorScheme.onErrorContainer);
  });

  testWidgets('respects custom message on rebuild', (tester) async {
    Widget build(String message) => MaterialApp(
      home: Scaffold(body: FlashcardSoftError(message: message)),
    );

    await tester.pumpWidget(build('First message'));
    expect(find.text('First message'), findsOneWidget);

    await tester.pumpWidget(build('Second message'));
    expect(find.text('Second message'), findsOneWidget);
    expect(find.text('First message'), findsNothing);
  });
}
