import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/player/player_surface_overlay_coordinator.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host({
    GlobalKey<ScaffoldMessengerState>? messengerKey,
    Widget? child,
    ProviderContainer? container,
  }) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
    final app = MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      scaffoldMessengerKey: messengerKey,
      home: Scaffold(
        body: Builder(
          builder: (context) =>
              child ?? Center(child: Text('host-${context.mounted}')),
        ),
      ),
    );
    if (container == null) return app;
    return UncontrolledProviderScope(container: container, child: app);
  }

  group('AppNotice', () {
    testWidgets('success shows a primaryContainer snackbar via global key', (
      tester,
    ) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(host(messengerKey: messengerKey));

      final ctx = tester.element(find.byType(Scaffold));
      AppNotice.success(ctx, 'hello success');

      await tester.pump(); // schedules the post-frame callback
      await tester.pump();

      expect(find.text('hello success'), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      final scheme = Theme.of(ctx).colorScheme;
      expect(snackBar.backgroundColor, scheme.primaryContainer);
    });

    testWidgets('error uses errorContainer and clears existing snackbars', (
      tester,
    ) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(host(messengerKey: messengerKey));
      final ctx = tester.element(find.byType(Scaffold));

      AppNotice.error(ctx, 'oops');
      await tester.pump();
      await tester.pump();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      final scheme = Theme.of(ctx).colorScheme;
      expect(snackBar.backgroundColor, scheme.errorContainer);
      expect(snackBar.showCloseIcon, isTrue);
    });

    testWidgets('info uses surfaceContainerHigh without close icon', (
      tester,
    ) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(host(messengerKey: messengerKey));
      final ctx = tester.element(find.byType(Scaffold));

      AppNotice.info(ctx, 'FYI');
      await tester.pump();
      await tester.pump();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      final scheme = Theme.of(ctx).colorScheme;
      expect(snackBar.backgroundColor, scheme.surfaceContainerHigh);
      expect(snackBar.showCloseIcon, isFalse);
    });

    testWidgets('warning uses tertiaryContainer with close icon', (
      tester,
    ) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(host(messengerKey: messengerKey));
      final ctx = tester.element(find.byType(Scaffold));

      AppNotice.warning(ctx, 'careful');
      await tester.pump();
      await tester.pump();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      final scheme = Theme.of(ctx).colorScheme;
      expect(snackBar.backgroundColor, scheme.tertiaryContainer);
      expect(snackBar.showCloseIcon, isTrue);
    });

    testWidgets(
      'falls back to ScaffoldMessenger.maybeOf when global key is empty',
      (tester) async {
        await tester.pumpWidget(host());
        final ctx = tester.element(find.byType(Scaffold));

        AppNotice.success(ctx, 'local only');
        await tester.pump();
        await tester.pump();

        expect(find.text('local only'), findsOneWidget);
      },
    );

    testWidgets('no-op when no ScaffoldMessenger is available', (tester) async {
      // No MaterialApp/Scaffold ancestor → both global key and maybeOf are null.
      late BuildContext bareContext;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            bareContext = context;
            return const SizedBox.shrink();
          },
        ),
      );
      // Bare BuildContext above any MaterialApp; AppNotice should silently skip.
      AppNotice.success(bareContext, 'should be skipped');
      await tester.pump();
      await tester.pump();
      expect(find.text('should be skipped'), findsNothing);
    });

    testWidgets(
      'success acquires overlay park token and releases when snackbar closes',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final messengerKey = GlobalKey<ScaffoldMessengerState>();
        await tester.pumpWidget(
          host(messengerKey: messengerKey, container: container),
        );

        final ctx = tester.element(find.byType(Scaffold));
        expect(
          container.read(playerSurfaceShouldParkForOverlayProvider),
          isFalse,
        );

        AppNotice.success(ctx, 'parked notice');
        await tester.pump();
        await tester.pump();

        expect(find.text('parked notice'), findsOneWidget);
        expect(
          container.read(playerSurfaceShouldParkForOverlayProvider),
          isTrue,
        );

        // Dismiss explicitly — more reliable than advancing the timer in tests.
        messengerKey.currentState!.hideCurrentSnackBar();
        await tester.pumpAndSettle();

        expect(find.text('parked notice'), findsNothing);
        expect(
          container.read(playerSurfaceShouldParkForOverlayProvider),
          isFalse,
        );
      },
    );

    // Regression: an ancestor Scaffold can leak padding.bottom greater than
    // the physical safe inset into the body MediaQuery (extendBody feeds
    // max(padding, bottomWidgetHeight)). The notice margin must clamp to
    // viewPadding so the floating SnackBar can never be taller than the
    // screen — a SnackBar that cannot fit trips the "Floating SnackBar
    // presented off screen" layout assert on every frame (frozen UI in
    // debug builds).
    testWidgets('clamps leaked bottom padding to the view inset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(392.7 * 3, 850.9 * 3);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = FakeViewPadding(
        left: 0,
        top: 72,
        right: 0,
        bottom: 102,
      );
      tester.view.viewPadding = FakeViewPadding(
        left: 0,
        top: 72,
        right: 0,
        bottom: 102,
      );
      addTearDown(tester.view.reset);

      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: scheme,
            extensions: [EnjoyThemeTokens.build(scheme)],
          ),
          scaffoldMessengerKey: messengerKey,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(392.7, 850.9),
              padding: EdgeInsets.only(bottom: 850.9),
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => AppNotice.success(context, 'clamped'),
                    child: const Text('show'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('show'));
      await tester.pump(); // post-frame notice
      await tester.pump(const Duration(milliseconds: 300));

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      // 34 (view inset) + 0 (no shell inset here) + 16 (spacing) — not 850.9+.
      expect(snackBar.margin, const EdgeInsets.fromLTRB(16, 0, 16, 50));
      final box = tester.renderObject<RenderBox>(find.byType(SnackBar));
      expect(box.size.height, lessThan(200));
      expect(tester.takeException(), isNull);
    });
  });
}
