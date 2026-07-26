// Tests for `lib/features/ai/presentation/settings/ai_providers_screen.dart`.
//
// Renders the AI providers settings screen with a fake in-memory Drift DB
// and a fake BYOK secret store so the providers build and resolve cleanly.
import 'package:drift/native.dart';
import 'package:enjoy_player/data/api/byok_secret_store.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/ai/application/ai_modality_config_controller.dart';
import 'package:enjoy_player/features/ai/data/ai_modality_config_repository.dart';
import 'package:enjoy_player/features/ai/domain/byok_config_validator.dart';
import 'package:enjoy_player/features/ai/domain/modality_kind.dart';
import 'package:enjoy_player/features/ai/presentation/settings/ai_providers_screen.dart';
import 'package:enjoy_player/features/ai/presentation/settings/widgets/modality_provider_card.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecretStore implements ByokSecretStoreBase {
  @override
  Future<void> deleteApiKey(ModalityKind modality) async {}

  @override
  Future<bool> hasApiKey(ModalityKind modality) async => false;

  @override
  Future<String?> readApiKey(ModalityKind modality) async => null;

  @override
  Future<void> writeApiKey(ModalityKind modality, String apiKey) async {}
}

Widget buildHost(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AiProvidersScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    final fakeSecrets = _FakeSecretStore();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceGlobalAppDatabaseProvider.overrideWithValue(db),
        aiModalityConfigRepositoryProvider.overrideWith(
          (ref) => AiModalityConfigRepository(
            ref.watch(appDatabaseProvider),
            fakeSecrets,
            const ByokConfigValidator(),
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets(
    'AiProvidersScreen renders title and four ModalityProviderCards',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildHost(container));
      await tester.pumpAndSettle();

      // Title is rendered.
      expect(find.byType(AppBar), findsOneWidget);
      // Four ModalityProviderCards rendered.
      expect(find.byType(ModalityProviderCard), findsNWidgets(4));
    },
  );

  testWidgets('AiProvidersScreen shows privacy callout', (tester) async {
    await tester.pumpWidget(buildHost(container));
    await tester.pumpAndSettle();

    // Shield icon should be present as part of the privacy callout.
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
  });
}
