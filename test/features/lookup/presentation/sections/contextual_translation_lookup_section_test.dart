// Widget tests for `lib/features/lookup/presentation/sections/contextual_translation_lookup_section.dart`.
//
// The section owns its own Future (not an autoDispose FutureProvider) and
// drives a FutureBuilder over it, so we can exercise:
//   * shimmer while loading
//   * markdown body on success
//   * empty-text fallback when translatedText is empty
//   * error row on failure
//   * refresh / force-refresh path
import 'dart:async';

import 'package:drift/native.dart';
import 'package:enjoy_player/core/cache/lru_store.dart';
import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/ai/application/ai_capability_providers.dart';
import 'package:enjoy_player/features/ai/application/ai_kind_policies.dart';
import 'package:enjoy_player/features/ai/application/ai_result_cache.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/contextual_translation_capability.dart';
import 'package:enjoy_player/features/ai/domain/models/contextual_translation_result.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/lookup/domain/lookup_request.dart';
import 'package:enjoy_player/features/lookup/presentation/sections/contextual_translation_lookup_section.dart';
import 'package:enjoy_player/features/lookup/presentation/widgets/lookup_error_row.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

class _AuthSignedInCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'tester', email: 't@example.com', name: 'Tester'),
  );
}

class _AuthSignedOutCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

class _FakeContextualCapability implements ContextualTranslationCapability {
  _FakeContextualCapability(this._resultOrError);

  final Object _resultOrError;

  /// Number of translate() calls so far.
  int calls = 0;

  /// Optional one-shot override for the next translate() call. Cleared once
  /// consumed. Used by the retry test to flip a failure into a success.
  Future<ContextualTranslationResult>? nextResult;

  @override
  Future<ContextualTranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? context,
  }) async {
    calls++;
    if (nextResult != null) {
      final r = nextResult!;
      nextResult = null;
      return r;
    }
    if (_resultOrError is Exception) {
      throw _resultOrError as Exception;
    }
    return _resultOrError as ContextualTranslationResult;
  }
}

Widget _harness({required List<Override> overrides, required Widget child}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _expand(WidgetTester tester) async {
  await tester.tap(find.text('Contextual translation'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AiContextualTranslationCache ctxCache;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    ctxCache = AiContextualTranslationCache(
      dao: db.aiCacheDao,
      l1: L1Store<String, ContextualTranslationResult>(
        capacity: 16,
        ttl: const Duration(minutes: 30),
      ),
      policies: defaultAiKindPolicies,
    );
  });

  tearDown(() async {
    await db.close();
  });

  const request = LookupRequest(
    selectedText: 'bank',
    sourceLanguage: 'en',
    targetLanguage: 'zh',
    contextualContext: 'I went to the bank to deposit money.',
  );

  List<Override> baseOverrides({
    required ContextualTranslationCapability capability,
    AuthCtrl Function()? authCtrlBuilder,
  }) => [
    authCtrlProvider.overrideWith(authCtrlBuilder ?? _AuthSignedInCtrl.new),
    appDatabaseProvider.overrideWithValue(db),
    aiContextualTranslationCacheProvider.overrideWithValue(ctxCache),
    contextualTranslationCapabilityProvider.overrideWithValue(capability),
  ];

  testWidgets('renders the translated markdown body once data arrives', (
    tester,
  ) async {
    final cap = _FakeContextualCapability(
      const ContextualTranslationResult(translatedText: '我去了**银行**存钱。'),
    );

    await tester.pumpWidget(
      _harness(
        overrides: baseOverrides(capability: cap),
        child: const ContextualTranslationLookupSection(request: request),
      ),
    );
    await _expand(tester);
    // Allow the post-frame fetch + result to settle.
    await tester.pumpAndSettle();

    // The translation is rendered through MarkdownBody — check raw text.
    expect(find.textContaining('银行'), findsWidgets);
    expect(cap.calls, 1);
  });

  testWidgets('shows the empty placeholder when translatedText is empty', (
    tester,
  ) async {
    final cap = _FakeContextualCapability(
      const ContextualTranslationResult(translatedText: ''),
    );

    await tester.pumpWidget(
      _harness(
        overrides: baseOverrides(capability: cap),
        child: const ContextualTranslationLookupSection(request: request),
      ),
    );
    await _expand(tester);
    await tester.pumpAndSettle();

    expect(find.text('No result.'), findsOneWidget);
  });

  testWidgets('renders an error row on generic failure', (tester) async {
    final cap = _FakeContextualCapability(
      const NetworkFailure('boom', statusCode: 500),
    );

    await tester.pumpWidget(
      _harness(
        overrides: baseOverrides(capability: cap),
        child: const ContextualTranslationLookupSection(request: request),
      ),
    );
    await _expand(tester);
    await tester.pumpAndSettle();

    expect(find.byType(LookupErrorRow), findsOneWidget);
  });

  testWidgets(
    'shows AuthRequiredCallout on AuthFailure when user is signed out',
    (tester) async {
      final cap = _FakeContextualCapability(const AuthFailure('nope'));

      await tester.pumpWidget(
        _harness(
          overrides: baseOverrides(
            capability: cap,
            authCtrlBuilder: _AuthSignedOutCtrl.new,
          ),
          child: const ContextualTranslationLookupSection(request: request),
        ),
      );
      await _expand(tester);
      await tester.pumpAndSettle();

      expect(find.byType(LookupErrorRow), findsNothing);
      expect(find.text('Sign in'), findsOneWidget);
    },
  );

  testWidgets('refresh invokes the capability again', (tester) async {
    final cap = _FakeContextualCapability(
      const ContextualTranslationResult(translatedText: 'initial'),
    );

    await tester.pumpWidget(
      _harness(
        overrides: baseOverrides(capability: cap),
        child: const ContextualTranslationLookupSection(request: request),
      ),
    );
    await _expand(tester);
    await tester.pumpAndSettle();

    expect(cap.calls, 1);

    // Tap the refresh icon button (top-right of the body).
    final refreshIcon = find.byIcon(Icons.refresh_rounded);
    expect(refreshIcon, findsOneWidget);
    await tester.tap(refreshIcon);
    await tester.pumpAndSettle();

    expect(cap.calls, 2);
  });

  testWidgets(
    'shows error row with retry button and clears retry on completion',
    (tester) async {
      final cap = _FakeContextualCapability(
        const NetworkFailure('boom', statusCode: 503),
      );

      await tester.pumpWidget(
        _harness(
          overrides: baseOverrides(capability: cap),
          child: const ContextualTranslationLookupSection(request: request),
        ),
      );
      await _expand(tester);
      await tester.pumpAndSettle();

      // The retry button label is "Retry".
      final retry = find.text('Retry');
      expect(retry, findsOneWidget);

      // Wire the next capability call to succeed so retry completes.
      cap.nextResult = Future.value(
        const ContextualTranslationResult(translatedText: 'retry-ok'),
      );

      // Tap retry — capability is called again, this time succeeds.
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(cap.calls, greaterThanOrEqualTo(2));
      // The success body is rendered.
      expect(find.textContaining('retry-ok'), findsWidgets);
    },
  );
}
