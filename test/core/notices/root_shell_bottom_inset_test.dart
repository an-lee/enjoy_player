import 'package:enjoy_player/core/notices/root_shell_bottom_inset.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kRootShellTransportSnackClearance', () {
    test('is a positive constant (>=64 logical px)', () {
      expect(kRootShellTransportSnackClearance, greaterThanOrEqualTo(64));
    });
  });

  group('rootShellBottomNavClearance', () {
    Widget host({double bottomInset = 0}) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: EdgeInsets.only(bottom: bottomInset)),
                child: Builder(
                  builder: (innerCtx) {
                    final out = rootShellBottomNavClearance(innerCtx);
                    return Text(out.toString());
                  },
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('adds system bottom inset to bottom-nav height', (
      tester,
    ) async {
      await tester.pumpWidget(host(bottomInset: 12));
      final text = tester.widget<Text>(find.byType(Text));
      final clearance = double.parse(text.data!);
      final tokens = EnjoyThemeTokens.of(tester.element(find.byType(Text)));
      expect(clearance, tokens.bottomNavHeight + 12);
    });

    testWidgets('zero inset still returns the nav height', (tester) async {
      await tester.pumpWidget(host());
      final text = tester.widget<Text>(find.byType(Text));
      final clearance = double.parse(text.data!);
      final tokens = EnjoyThemeTokens.of(tester.element(find.byType(Text)));
      expect(clearance, tokens.bottomNavHeight);
    });
  });

  group('RootShellBottomInset', () {
    testWidgets('maybeOf returns null when no ancestor is present', (
      tester,
    ) async {
      BuildContext? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(captured, isNotNull);
      expect(RootShellBottomInset.maybeOf(captured!), isNull);
    });

    testWidgets('maybeOf returns the ancestor inset when present', (
      tester,
    ) async {
      late RootShellBottomInset found;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RootShellBottomInset(
              bottomClearance: 88,
              child: Builder(
                builder: (context) {
                  found = RootShellBottomInset.maybeOf(context)!;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(found.bottomClearance, 88);
    });

    testWidgets('clearanceOf returns 0 when no inset is present', (
      tester,
    ) async {
      double? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                captured = RootShellBottomInset.clearanceOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(captured, 0);
    });

    testWidgets('clearanceOf returns ancestor bottomClearance when present', (
      tester,
    ) async {
      double? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RootShellBottomInset(
              bottomClearance: 42.5,
              child: Builder(
                builder: (context) {
                  captured = RootShellBottomInset.clearanceOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(captured, 42.5);
    });

    test(
      'updateShouldNotify returns true only when bottomClearance differs',
      () {
        const oldWidget = RootShellBottomInset(
          bottomClearance: 10,
          child: SizedBox.shrink(),
        );
        const sameWidget = RootShellBottomInset(
          bottomClearance: 10,
          child: SizedBox.shrink(),
        );
        const differentWidget = RootShellBottomInset(
          bottomClearance: 20,
          child: SizedBox.shrink(),
        );
        expect(oldWidget.updateShouldNotify(sameWidget), isFalse);
        expect(oldWidget.updateShouldNotify(differentWidget), isTrue);
      },
    );
  });

  // Anchor: import the bottom-nav widget to ensure that consumers of the
  // clearance (e.g. AppNotice) compile against the same token surface.
  test('enjoyBottomNav exists and is a Widget', () {
    expect(EnjoyBottomNav, isNotNull);
  });
}
