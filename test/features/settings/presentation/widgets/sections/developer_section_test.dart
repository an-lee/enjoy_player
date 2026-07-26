// Tests for `lib/features/settings/presentation/widgets/sections/developer_section.dart`.
//
// Renders the API URL / AI API URL editors with a fake in-memory Drift DB
// so the providers build and resolve cleanly.
import 'package:drift/native.dart';
import 'package:enjoy_player/data/api/api_client_provider.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/sections/developer_section.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildHost(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: DeveloperSectionBody()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('renders API URL and AI API URL expansion tiles', (tester) async {
    await tester.pumpWidget(buildHost(container));
    await tester.pumpAndSettle();

    // Both expansion tiles should be present with their titles.
    expect(find.byType(ExpansionTile), findsNWidgets(2));
    expect(find.byIcon(Icons.dns_outlined), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
  });

  testWidgets('expanding the API URL tile reveals the editor', (tester) async {
    await tester.pumpWidget(buildHost(container));
    await tester.pumpAndSettle();

    // First ExpansionTile → tap to expand.
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();

    // Editor widgets appear (TextField + FilledButton).
    expect(find.byType(TextField), findsAtLeast(1));
    expect(find.byType(FilledButton), findsAtLeast(1));
  });

  testWidgets(
    'AI API URL tile contains Save and Use API URL buttons after expand',
    (tester) async {
      await tester.pumpWidget(buildHost(container));
      await tester.pumpAndSettle();

      // Second ExpansionTile → tap to expand.
      await tester.tap(find.byType(ExpansionTile).at(1));
      await tester.pumpAndSettle();

      // Editor should now have TextField + FilledButton (Save) + OutlinedButton (Use default).
      expect(find.byType(TextField), findsAtLeast(1));
      expect(find.byType(FilledButton), findsAtLeast(1));
      expect(find.byType(OutlinedButton), findsAtLeast(1));
    },
  );

  test(
    'apiBaseUrlProvider builds from default when no persisted value',
    () async {
      // No settings persisted → default URL.
      final url = await container.read(apiBaseUrlProvider.future);
      expect(url, startsWith('https://'));
    },
  );

  test('setBaseUrl persists and updates state', () async {
    final notifier = container.read(apiBaseUrlProvider.notifier);
    await notifier.setBaseUrl('https://example.test/api');
    expect(
      await container.read(apiBaseUrlProvider.future),
      'https://example.test/api',
    );
  });
}
