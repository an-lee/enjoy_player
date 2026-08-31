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
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
      // Dismiss affordance is rendered by the notice body, not SnackBar's slot
      // (the field is left at its null default; the theme resolves it off).
      expect(snackBar.showCloseIcon, isNull);
      expect(find.byIcon(Icons.close), findsOneWidget);
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
      expect(snackBar.showCloseIcon, isNull);
      expect(find.byIcon(Icons.close), findsNothing);
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
      expect(snackBar.showCloseIcon, isNull);
      expect(find.byIcon(Icons.close), findsOneWidget);
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
      tester.view.padding = const FakeViewPadding(
        left: 0,
        top: 72,
        right: 0,
        bottom: 102,
      );
      tester.view.viewPadding = const FakeViewPadding(
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

    // Regression: when SnackBar's built-in action is wider than
    // `actionOverflowThreshold` (25% of the bar) it moves to its own row and
    // *still* reserves 40% of the width next to the message, so the
    // credits-exhausted copy rendered as a narrow ~30% column on phones.
    // AppNotice owns the action / dismiss layout, so the text keeps the bar's
    // full inner width.
    testWidgets('action notice keeps the message at full inner width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393 * 3, 851 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(host(messengerKey: messengerKey));
      final ctx = tester.element(find.byType(Scaffold));

      const message =
          'AI credits limit reached. Upgrade to Pro or buy a credits '
          'package to continue.';
      var tapped = 0;
      AppNotice.error(
        ctx,
        message,
        action: (label: 'View plans & packages', onPressed: () => tapped++),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final barWidth = tester
          .getSize(
            find
                .descendant(
                  of: find.byType(SnackBar),
                  matching: find.byType(Material),
                )
                .first,
          )
          .width;
      final textWidth = tester.getSize(find.text(message)).width;
      // Icon (22) + gap (12) + gutters are all that is left of the bar, so the
      // text owns ~82% of it; the broken layout sat at ~30%.
      expect(textWidth, greaterThan(barWidth * 0.75));
      // An actionable notice still waits for the user instead of timing out.
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isTrue);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('View plans & packages'));
      expect(tapped, 1);
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    });

    testWidgets('body close button dismisses a notice without an action', (
      tester,
    ) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(host(messengerKey: messengerKey));
      final ctx = tester.element(find.byType(Scaffold));

      AppNotice.warning(ctx, 'careful');
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('careful'), findsNothing);
    });

    // Regression: the dismiss button rides inline with the message (SDK
    // geometry), so a dismiss-only notice stays at SnackBar's own
    // single-line height instead of growing a trailing row.
    testWidgets('dismiss-only notice keeps the single-line height', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393 * 3, 851 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(host(messengerKey: messengerKey));
      final ctx = tester.element(find.byType(Scaffold));

      AppNotice.error(ctx, 'one line');
      await tester.pump();
      await tester.pumpAndSettle();

      // The close button's 48dp tap target sets the row height — anything
      // taller means the dismiss button grew its own trailing row again.
      // Measure the bar itself (inside the floating margin wrapper).
      final bar = tester.renderObject<RenderBox>(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(bar.size.height, lessThan(60));
      expect(tester.takeException(), isNull);
    });

    // Regression: the CTA is a body-owned button, so a long localized label
    // must ellipsize instead of soft-wrapping into a multi-line button.
    testWidgets('long action label ellipsizes instead of wrapping', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 700 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(host(messengerKey: messengerKey));
      final ctx = tester.element(find.byType(Scaffold));

      const label =
          'View plans & packages and manage your subscription settings';
      AppNotice.error(
        ctx,
        'limit reached',
        action: (label: label, onPressed: () {}),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.getSize(find.text(label)).height, lessThan(24));
      expect(tester.takeException(), isNull);
    });
  });
}
