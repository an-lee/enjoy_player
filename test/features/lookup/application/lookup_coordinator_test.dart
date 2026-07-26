// Tests for `lib/features/lookup/application/lookup_coordinator.dart` —
// covers the rail breakpoint branch (`w >= 900` → dialog) and the
// compact branch (`w < 900` → bottom sheet) by exercising
// `LookupCoordinator.open()` in widget tests with synthetic MediaQuery sizes
// and inspecting the resulting modal widget.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/lookup/application/lookup_coordinator.dart';
import 'package:enjoy_player/features/lookup/domain/lookup_request.dart';
import 'package:enjoy_player/features/lookup/presentation/dictionary_lookup_sheet.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class _AuthSignedOutCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

class _AuthSignedInCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'test-user', email: 't@example.com', name: 'Test'),
  );
}

Widget _wrap({
  required AppDatabase db,
  required AuthCtrl authCtrl,
  required Size size,
  required List<Override> extraOverrides,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authCtrlProvider.overrideWith(() => authCtrl),
      ...extraOverrides,
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
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              // Capture a FutureProvider that resolves after open() completes.
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    final req = LookupRequest(
                      selectedText: 'hello',
                      sourceLanguage: 'en',
                      targetLanguage: 'zh',
                    );
                    unawaited(
                      ref
                          .read(lookupCoordinatorProvider.notifier)
                          .open(context, req),
                    );
                  },
                  child: const Text('OpenLookup'),
                ),
              );
            },
          ),
        ),
      ),
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

  testWidgets('LookupCoordinator.build initializes to 0', (tester) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    expect(container.read(lookupCoordinatorProvider), 0);
  });

  for (final entry in <(String, Size, DictionaryLookupPresentation)>[
    (
      'narrow 500x800',
      Size(500, 800),
      DictionaryLookupPresentation.bottomSheet,
    ),
    (
      'just below rail 899x800',
      Size(899, 800),
      DictionaryLookupPresentation.bottomSheet,
    ),
    ('rail 900x800', Size(900, 800), DictionaryLookupPresentation.dialog),
    ('wide 1200x900', Size(1200, 900), DictionaryLookupPresentation.dialog),
  ]) {
    testWidgets('open() uses ${entry.$3.name} at ${entry.$1}', (tester) async {
      await tester.pumpWidget(
        _wrap(
          db: db,
          authCtrl: _AuthSignedOutCtrl(),
          size: entry.$2,
          extraOverrides: const [],
        ),
      );
      await tester.pump();

      // Tap the button to fire open().
      await tester.tap(find.text('OpenLookup'));
      await tester.pumpAndSettle();

      // The DictionaryLookupSheet wraps the lookup content with a Header
      // that contains the "Look up" / "Lookup" label and language picker.
      // Both branches end up rendering at least one DictionaryLookupSheet
      // widget; we just need to verify *which* presentation flag it got.
      final sheetWidgets = tester
          .widgetList(find.byType(DictionaryLookupSheet))
          .toList();
      expect(
        sheetWidgets,
        isNotEmpty,
        reason: 'DictionaryLookupSheet should be rendered for ${entry.$1}',
      );
      final any = sheetWidgets.first as DictionaryLookupSheet;
      expect(
        any.presentation,
        entry.$3,
        reason:
            'expected ${entry.$3.name} at viewport ${entry.$1}, got '
            '${any.presentation.name}',
      );
    });
  }
}
