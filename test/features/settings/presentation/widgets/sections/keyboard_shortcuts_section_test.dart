// Tests for `lib/features/settings/presentation/widgets/sections/`
// `keyboard_shortcuts_section.dart` — exercises the cheatsheet row, the
// customize row push, and the trailing binding chip rendered via the
// `hotkeysCtrlProvider.effectiveKeys('global.help')` resolution.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/hotkeys/presentation/widgets/kbd_chip.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/keyboard_shortcuts_section.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Widget _harness(Widget child, {required AppDatabase db, GoRouter? router}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  final app = MaterialApp(
    theme: ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: [EnjoyThemeTokens.build(scheme)],
    ),
    locale: const Locale('en', 'US'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: router == null
        ? app
        : MaterialApp.router(
            theme: ThemeData(
              colorScheme: scheme,
              useMaterial3: true,
              brightness: Brightness.dark,
              extensions: [EnjoyThemeTokens.build(scheme)],
            ),
            locale: const Locale('en', 'US'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    'renders both rows with default binding (Shift+?) shown in the cheatsheet row',
    (tester) async {
      await tester.pumpWidget(
        _harness(const KeyboardShortcutsSectionBody(), db: db),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      // Default binding is "shift+slash" → the chip row shows "Shift /".
      expect(find.byType(KbdChordRow), findsOneWidget);
    },
  );

  testWidgets('cheatsheet tap opens the hotkeys help dialog', (tester) async {
    await tester.pumpWidget(
      _harness(const KeyboardShortcutsSectionBody(), db: db),
    );
    await tester.pumpAndSettle();

    // Tap the first SettingsRow (cheatsheet opener).
    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    // Search bar present in the dialog.
    expect(find.byIcon(Icons.search_rounded), findsWidgets);
  });

  testWidgets(
    'customize tap pushes the keyboard settings route via go_router',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: KeyboardShortcutsSectionBody()),
          ),
          GoRoute(
            path: '/settings/keyboard',
            builder: (_, _) =>
                const Scaffold(body: Text('KeyboardCustomizeLanded')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _harness(const SizedBox.shrink(), db: db, router: router),
      );
      await tester.pumpAndSettle();

      // Tap the customize row.
      await tester.tap(find.text('Customize shortcuts'));
      await tester.pumpAndSettle();

      expect(find.text('KeyboardCustomizeLanded'), findsOneWidget);
    },
  );

  testWidgets('uses persisted custom binding for the cheatsheet row', (
    tester,
  ) async {
    await db.settingsDao.setValue(
      'hotkeys_custom_bindings',
      '{"global.help":"ctrl+h"}',
    );

    await tester.pumpWidget(
      _harness(const KeyboardShortcutsSectionBody(), db: db),
    );
    await tester.pumpAndSettle();

    expect(find.byType(KbdChordRow), findsOneWidget);
    // Verify the chip renders the custom chord text instead of the default.
    // KbdChordRow shows each segment as Text; "Ctrl" + "H" appear.
    expect(find.text('Ctrl'), findsWidgets);
    expect(find.text('H'), findsWidgets);
  });
}
