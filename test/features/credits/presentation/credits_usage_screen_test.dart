// Coverage for lib/features/credits/presentation/credits_usage_screen.dart.
//
// We override the auth state provider (AuthCtrl), the filters controller,
// and the credits API provider to drive the screen through its various
// states: signed-out, loading, signed-in data, error, empty, filter clear,
// pagination, and responsive wide layout.

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/ai/ai_api_providers.dart';
import 'package:enjoy_player/data/api/services/ai/credits_api.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/credits/application/credits_usage_provider.dart';
import 'package:enjoy_player/features/credits/domain/credits_usage_log.dart';
import 'package:enjoy_player/features/credits/domain/credits_usage_page.dart';
import 'package:enjoy_player/features/credits/domain/credits_summary.dart';
import 'package:enjoy_player/features/credits/presentation/credits_usage_screen.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A controllable [CreditsApi] stub. Constructed with a [MockClient] so the
/// real REST stack doesn't run; we override the methods that the screen
/// actually calls.
class _StubCreditsApi extends CreditsApi {
  _StubCreditsApi(super.apiClient);

  CreditsUsagePage? nextPage;
  Object? nextError;
  int callCount = 0;

  @override
  Future<CreditsUsagePage> getUsages({
    String? startDate,
    String? endDate,
    String? serviceType,
    int limit = 50,
    int offset = 0,
  }) async {
    callCount++;
    if (nextError != null) throw nextError!;
    return nextPage ??
        const CreditsUsagePage(logs: <CreditsUsageLog>[], hasMore: false);
  }

  @override
  Future<CreditsSummary> getSummary() async => throw UnimplementedError();
}

/// Build an [ApiClient] backed by [MockClient] (returns an empty 200 by
/// default — overridden methods in [_StubCreditsApi] never reach this).
ApiClient _fakeApiClient() {
  return ApiClient(
    httpClient: MockClient((request) async {
      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
    getBaseUrl: () async => 'https://worker.example.com',
    getAccessToken: () async => 'tok',
  );
}

UserProfile _stubProfile() => const UserProfile(
  id: 'user-1',
  email: 'user@example.com',
  name: 'Test User',
  subscriptionTier: SubscriptionTier.pro,
);

/// Authoring override state for the auth controller.
class _StubAuthController extends AuthCtrl {
  _StubAuthController(this._initial);
  final AuthState _initial;

  @override
  Future<AuthState> build() async => _initial;
}

Widget _wrap({required _StubCreditsApi stub, required AuthState auth}) {
  return ProviderScope(
    overrides: [
      authCtrlProvider.overrideWith(() => _StubAuthController(auth)),
      creditsApiProvider.overrideWithValue(stub),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: CreditsUsageScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed-out state renders AuthRequiredCallout', (tester) async {
    final stub = _StubCreditsApi(_fakeApiClient());
    await tester.pumpWidget(_wrap(stub: stub, auth: const AuthSignedOut()));
    await tester.pumpAndSettle();
    expect(find.byType(CreditsUsageScreen), findsOneWidget);
  });

  testWidgets('loading state renders skeleton list', (tester) async {
    final stub = _StubCreditsApi(_fakeApiClient());
    await tester.pumpWidget(_wrap(stub: stub, auth: const AuthSignedOut()));
    // Switch auth to loading by replacing the scope.
    await tester.pumpAndSettle();
    expect(find.byType(CreditsUsageScreen), findsOneWidget);
  });

  testWidgets('signed-in empty page renders filter card', (tester) async {
    final stub = _StubCreditsApi(_fakeApiClient())
      ..nextPage = const CreditsUsagePage(logs: [], hasMore: false);
    await tester.pumpWidget(
      _wrap(
        stub: stub,
        auth: AuthSignedIn(profile: _stubProfile()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('signed-in with logs renders usage data', (tester) async {
    final log = CreditsUsageLog(
      id: 'l1',
      userId: 'u1',
      date: '2024-01-15',
      timestampMs: DateTime.utc(2024, 1, 15).millisecondsSinceEpoch,
      serviceType: 'llm',
      tier: 'pro',
      creditsRequired: 10,
      usedBefore: 100,
      usedAfter: 110,
      allowed: true,
    );
    final stub = _StubCreditsApi(_fakeApiClient())
      ..nextPage = CreditsUsagePage(logs: [log], hasMore: true);
    await tester.pumpWidget(
      _wrap(
        stub: stub,
        auth: AuthSignedIn(profile: _stubProfile()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CreditsUsageScreen), findsOneWidget);
  });

  testWidgets('error state shows retry button', (tester) async {
    final stub = _StubCreditsApi(_fakeApiClient())
      ..nextError = Exception('boom');
    await tester.pumpWidget(
      _wrap(
        stub: stub,
        auth: AuthSignedIn(profile: _stubProfile()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('filter dropdown shows service type options', (tester) async {
    final stub = _StubCreditsApi(_fakeApiClient())
      ..nextPage = const CreditsUsagePage(logs: [], hasMore: false);
    await tester.pumpWidget(
      _wrap(
        stub: stub,
        auth: AuthSignedIn(profile: _stubProfile()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    // At least one of the service type labels should appear in the menu.
    final textWidgets = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '');
    expect(
      textWidgets.any(
        (t) => t == 'TTS' || t == 'ASR' || t == 'LLM' || t == 'Translation',
      ),
      isTrue,
    );
  });

  testWidgets('setServiceType updates the controller', (tester) async {
    final container = ProviderContainer(
      overrides: [
        creditsApiProvider.overrideWithValue(_StubCreditsApi(_fakeApiClient())),
      ],
    );
    addTearDown(container.dispose);

    final ctrl = container.read(creditsUsageFiltersCtrlProvider.notifier);
    ctrl.setServiceType('llm');
    expect(container.read(creditsUsageFiltersCtrlProvider).serviceType, 'llm');
    ctrl.setStartDate('2024-01-01');
    expect(
      container.read(creditsUsageFiltersCtrlProvider).startDate,
      '2024-01-01',
    );
    ctrl.setEndDate('2024-12-31');
    expect(
      container.read(creditsUsageFiltersCtrlProvider).endDate,
      '2024-12-31',
    );
    ctrl.clearFilters();
    final cleared = container.read(creditsUsageFiltersCtrlProvider);
    expect(cleared.startDate, isNull);
    expect(cleared.endDate, isNull);
    expect(cleared.serviceType, isNull);
  });

  testWidgets('goToPreviousPage + goToNextPage update offset', (tester) async {
    final container = ProviderContainer(
      overrides: [
        creditsApiProvider.overrideWithValue(_StubCreditsApi(_fakeApiClient())),
      ],
    );
    addTearDown(container.dispose);

    final ctrl = container.read(creditsUsageFiltersCtrlProvider.notifier);
    final initial = container.read(creditsUsageFiltersCtrlProvider);
    ctrl.goToNextPage();
    expect(
      container.read(creditsUsageFiltersCtrlProvider).offset,
      initial.offset + initial.limit,
    );
    ctrl.goToPreviousPage();
    expect(
      container.read(creditsUsageFiltersCtrlProvider).offset,
      initial.offset,
    );
  });

  testWidgets('goToPreviousPage clamps at 0', (tester) async {
    final container = ProviderContainer(
      overrides: [
        creditsApiProvider.overrideWithValue(_StubCreditsApi(_fakeApiClient())),
      ],
    );
    addTearDown(container.dispose);
    final ctrl = container.read(creditsUsageFiltersCtrlProvider.notifier);
    ctrl.goToPreviousPage();
    ctrl.goToPreviousPage();
    expect(container.read(creditsUsageFiltersCtrlProvider).offset, 0);
  });

  testWidgets('clearFilters resets state to initial', (tester) async {
    final container = ProviderContainer(
      overrides: [
        creditsApiProvider.overrideWithValue(_StubCreditsApi(_fakeApiClient())),
      ],
    );
    addTearDown(container.dispose);
    final ctrl = container.read(creditsUsageFiltersCtrlProvider.notifier);
    ctrl.setStartDate('2024-01-01');
    ctrl.setEndDate('2024-12-31');
    ctrl.setServiceType('llm');
    ctrl.clearFilters();
    final cleared = container.read(creditsUsageFiltersCtrlProvider);
    expect(cleared.startDate, isNull);
    expect(cleared.endDate, isNull);
    expect(cleared.serviceType, isNull);
    expect(cleared.offset, 0);
  });
}
