import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/craft/presentation/widgets/craft_loading_view.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('CraftLoadingView shows a CircularProgressIndicator', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const CraftLoadingView(message: 'Loading…')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('CraftLoadingView renders the supplied message text', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const CraftLoadingView(message: 'Synthesizing audio…')),
    );
    await tester.pump();

    expect(find.text('Synthesizing audio…'), findsOneWidget);
  });

  testWidgets('CraftLoadingView centers its column on screen', (tester) async {
    await tester.pumpWidget(wrap(const CraftLoadingView(message: 'Loading…')));
    await tester.pump();

    final center = tester.widget<Center>(find.byType(Center));
    final column = tester.widget<Column>(find.byType(Column));
    expect(center, isNotNull);
    expect(column.mainAxisSize, MainAxisSize.min);
  });

  testWidgets('CraftLoadingView applies onSurfaceVariant color to the text', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const CraftLoadingView(message: 'Loading…')));
    await tester.pump();

    final text = tester.widget<Text>(find.text('Loading…'));
    final theme = Theme.of(tester.element(find.text('Loading…')));
    expect(text.style?.color, theme.colorScheme.onSurfaceVariant);
  });
}
