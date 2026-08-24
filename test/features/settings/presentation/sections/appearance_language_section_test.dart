import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_chrome_icon.dart';
import 'package:enjoy_player/core/theme/widgets/sheet_drag_handle.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/appearance_language_section.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_row.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import '../../../../helpers/chrome_icon_finders.dart';

class _SignedOutAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

/// Seeds a real (in-memory) [AppPreferencesCtrl] with the given learning
/// language so `setLocale`/`setLearningLanguage` continue to exercise their
/// real DB-write side effects — only the starting state is faked.
class _SeededPrefsCtrl extends AppPreferencesCtrl {
  _SeededPrefsCtrl(this.learningLanguage);

  final String learningLanguage;

  @override
  Future<AppPreferencesState> build() async {
    return AppPreferencesState.initial.copyWith(
      learningLanguage: learningLanguage,
    );
  }
}

Widget _harness({required AppDatabase db, required String learningLanguage}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  return ProviderScope(
    overrides: [
      deviceGlobalAppDatabaseProvider.overrideWithValue(db),
      appDatabaseProvider.overrideWithValue(db),
      authCtrlProvider.overrideWith(_SignedOutAuthCtrl.new),
      appPreferencesCtrlProvider.overrideWith(
        () => _SeededPrefsCtrl(learningLanguage),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      locale: const Locale('en', 'US'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: AppearanceLanguageSectionBody()),
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
    'picking a different display language updates the row value badge '
    'immediately without leaving the hub',
    (tester) async {
      await tester.pumpWidget(_harness(db: db, learningLanguage: 'en-US'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(
        const Locale('en', 'US'),
      );

      final displayRow = find.ancestor(
        of: find.text(l10n.settingsAppearanceDisplayLanguage),
        matching: find.byType(SettingsRow),
      );

      // Default display locale is zh-CN.
      expect(
        find.descendant(
          of: displayRow,
          matching: find.text(l10n.settingsLanguageOptionZhCn),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.settingsAppearanceDisplayLanguage));
      await tester.pumpAndSettle();

      // The picker sheet is open, appended above the rest of the tree, so
      // its option row is the last "English" match.
      expect(find.byType(PaddedSheetDragHandle), findsOneWidget);

      await tester.tap(find.text(l10n.settingsLanguageOptionEnUs).last);
      await tester.pumpAndSettle();

      // The sheet is dismissed and the row's value badge reflects the pick,
      // with no need to navigate away from the settings hub.
      expect(find.byType(AppearanceLanguageSectionBody), findsOneWidget);
      expect(
        find.descendant(
          of: displayRow,
          matching: find.text(l10n.settingsLanguageOptionEnUs),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the native-language row is disabled with its explanatory subtitle when '
    'the learning language leaves only one native choice',
    (tester) async {
      // en-US learning language leaves only zh-CN as a native choice.
      await tester.pumpWidget(_harness(db: db, learningLanguage: 'en-US'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(
        const Locale('en', 'US'),
      );

      final nativeRow = find.ancestor(
        of: find.text(l10n.settingsAppearanceNativeLanguage),
        matching: find.byType(SettingsRow),
      );
      expect(nativeRow, findsOneWidget);

      final rowWidget = tester.widget<SettingsRow>(nativeRow);
      expect(rowWidget.onTap, isNull);
      expect(rowWidget.showChevron, isFalse);
      expect(rowWidget.subtitle, isNotEmpty);

      // Tapping a disabled row does nothing — no picker sheet appears.
      await tester.tap(find.text(l10n.settingsAppearanceNativeLanguage));
      await tester.pumpAndSettle();
      expect(find.byType(PaddedSheetDragHandle), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the native-language row is enabled when the learning language allows '
    'more than one native choice',
    (tester) async {
      // ja-JP learning language leaves both en-US and zh-CN as native choices.
      await tester.pumpWidget(_harness(db: db, learningLanguage: 'ja-JP'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(
        const Locale('en', 'US'),
      );

      final nativeRow = find.ancestor(
        of: find.text(l10n.settingsAppearanceNativeLanguage),
        matching: find.byType(SettingsRow),
      );
      final rowWidget = tester.widget<SettingsRow>(nativeRow);
      expect(rowWidget.onTap, isNotNull);
      expect(rowWidget.showChevron, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'theme row opens System / Light / Dark and applying Light updates the badge',
    (tester) async {
      await tester.pumpWidget(_harness(db: db, learningLanguage: 'en-US'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(
        const Locale('en', 'US'),
      );

      expect(find.text(l10n.settingsAppearanceTheme), findsOneWidget);
      expect(find.text(l10n.settingsAppearanceThemeSystem), findsOneWidget);
      expect(findChromeIcon(EnjoyChromeGlyph.monitor), findsOneWidget);

      await tester.tap(find.text(l10n.settingsAppearanceTheme));
      await tester.pumpAndSettle();

      expect(find.byType(PaddedSheetDragHandle), findsOneWidget);
      expect(find.text(l10n.settingsAppearanceThemeLight), findsOneWidget);
      expect(find.text(l10n.settingsAppearanceThemeDark), findsOneWidget);

      await tester.tap(find.text(l10n.settingsAppearanceThemeLight));
      await tester.pumpAndSettle();

      expect(find.byType(PaddedSheetDragHandle), findsNothing);
      expect(find.text(l10n.settingsAppearanceThemeLight), findsOneWidget);
      expect(findChromeIcon(EnjoyChromeGlyph.sun), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
