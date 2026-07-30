import 'dart:async';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _theme() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
  return ThemeData(
    colorScheme: scheme,
    extensions: [EnjoyThemeTokens.build(scheme)],
  );
}

/// Nested shell navigator under MaterialApp's root navigator (ShellRoute shape).
Widget _shellUnderRoot({
  required GlobalKey<NavigatorState> rootKey,
  required GlobalKey<NavigatorState> shellKey,
  required Widget home,
}) {
  return MaterialApp(
    theme: _theme(),
    navigatorKey: rootKey,
    home: Navigator(
      key: shellKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(builder: (_) => home);
      },
    ),
  );
}

void main() {
  testWidgets('showEnjoyDialog defaults to the root navigator', (tester) async {
    final rootKey = GlobalKey<NavigatorState>();
    final shellKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _shellUnderRoot(
        rootKey: rootKey,
        shellKey: shellKey,
        home: Builder(
          builder: (shellContext) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  unawaited(
                    showEnjoyDialog<void>(
                      context: shellContext,
                      builder: (ctx) =>
                          const AlertDialog(title: Text('enjoy-dialog')),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    expect(rootKey.currentState!.canPop(), isFalse);
    expect(shellKey.currentState!.canPop(), isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('enjoy-dialog'), findsOneWidget);
    expect(rootKey.currentState!.canPop(), isTrue);
    expect(shellKey.currentState!.canPop(), isFalse);
  });

  testWidgets('showEnjoySheet defaults to the root navigator', (tester) async {
    final rootKey = GlobalKey<NavigatorState>();
    final shellKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _shellUnderRoot(
        rootKey: rootKey,
        shellKey: shellKey,
        home: Builder(
          builder: (shellContext) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  unawaited(
                    showEnjoySheet<void>(
                      context: shellContext,
                      builder: (ctx) => const SizedBox(
                        height: 120,
                        child: Center(child: Text('enjoy-sheet')),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('enjoy-sheet'), findsOneWidget);
    expect(rootKey.currentState!.canPop(), isTrue);
    expect(shellKey.currentState!.canPop(), isFalse);
  });

  testWidgets('useRootNavigator false keeps the modal on the shell navigator', (
    tester,
  ) async {
    final rootKey = GlobalKey<NavigatorState>();
    final shellKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _shellUnderRoot(
        rootKey: rootKey,
        shellKey: shellKey,
        home: Builder(
          builder: (shellContext) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  unawaited(
                    showEnjoyDialog<void>(
                      context: shellContext,
                      useRootNavigator: false,
                      builder: (ctx) =>
                          const AlertDialog(title: Text('shell-dialog')),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('shell-dialog'), findsOneWidget);
    expect(rootKey.currentState!.canPop(), isFalse);
    expect(shellKey.currentState!.canPop(), isTrue);
  });
}
