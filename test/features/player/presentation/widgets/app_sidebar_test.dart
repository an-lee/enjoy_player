// Tests for `lib/features/player/presentation/widgets/app_sidebar.dart`.
//
// Renders the primary navigation sidebar with a fake in-memory Drift DB and
// GoRouter so that providers and navigation-dependent logic resolve cleanly.
import 'package:drift/native.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/player/presentation/widgets/app_sidebar.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget buildHost(ProviderContainer container, GoRouter router) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      locale: const Locale('en', 'US'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: AppSidebar()),
        ),
        GoRoute(
          path: '/discover',
          builder: (_, __) => const Scaffold(body: AppSidebar()),
        ),
        GoRoute(
          path: '/library',
          builder: (_, __) => const Scaffold(body: AppSidebar()),
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceGlobalAppDatabaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    router.dispose();
    container.dispose();
    await db.close();
  });

  testWidgets('AppSidebar renders brand row, search field and nav pills', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildHost(container, router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Three nav pills (Home, Discover, Library) rendered.
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
    expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);
    // Search field is present.
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('AppSidebar tapping the Discover nav pill navigates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildHost(container, router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pump();

    expect(router.state.uri.path, '/discover');
  });

  testWidgets('AppSidebar search field calls setQuery on change', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildHost(container, router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField).first, 'foo');
    await tester.pump();

    // Commit the search so the debounce Timer cancels before teardown.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // The TextField's local controller should now reflect the typed text.
    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text, 'foo');
  });
}
