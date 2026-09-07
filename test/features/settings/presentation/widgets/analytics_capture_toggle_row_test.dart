// Widget test for the Usage-analytics opt-out row (spec 046 US4): the switch
// reflects the persisted preference and toggling writes it through the
// notifier (the provider applies it to the vendor).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/analytics/analytics_capture_pref.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/analytics_capture_toggle_row.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Future<void> _pumpRow(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AnalyticsCaptureToggleRow()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('renders localized label with the switch ON by default', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await _pumpRow(tester, container);

    expect(find.text('Usage analytics'), findsOneWidget);
    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches.single.value, isTrue);
  });

  testWidgets('toggling persists the opt-out and reflects it', (tester) async {
    final container = ProviderContainer(
      overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await _pumpRow(tester, container);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(
      tester.widgetList<Switch>(find.byType(Switch)).single.value,
      isFalse,
    );
    expect(await container.read(analyticsCapturePrefProvider.future), isFalse);
  });
}
