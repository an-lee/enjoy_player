// Widget tests for `lib/features/lookup/presentation/sections/dictionary_lookup_section.dart`.
//
// The section watches `lookupSheetDictionaryProvider` and renders one of:
//   * a shimmer while loading
//   * a `_DictionaryBody` for a successful result
//   * an `AuthRequiredCallout` for AuthFailure
//   * a `LookupErrorRow` (with optional "View plans" CTA) for CreditsFailure
//   * a `LookupErrorRow` for other failures
//
// We override the dictionary capability provider so the lookup resolves to a
// pre-canned `DictionaryResult`, plus override the auth controller to keep
// the auth gate out of the way.
import 'package:drift/native.dart';
import 'package:enjoy_player/core/cache/lru_store.dart';
import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/ai/application/ai_capability_providers.dart';
import 'package:enjoy_player/features/ai/application/ai_kind_policies.dart';
import 'package:enjoy_player/features/ai/application/ai_result_cache.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/dictionary_capability.dart';
import 'package:enjoy_player/features/ai/domain/models/dictionary_result.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/lookup/domain/lookup_request.dart';
import 'package:enjoy_player/features/lookup/presentation/sections/dictionary_lookup_section.dart';
import 'package:enjoy_player/features/lookup/presentation/widgets/lookup_error_row.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

// === Fakes ===

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

class _FakeDictionaryCapability implements DictionaryCapability {
  _FakeDictionaryCapability(this._resultOrError);
  final Object _resultOrError;

  @override
  Future<DictionaryResult> lookupDictionary({
    required String word,
    required String sourceLanguage,
    required String targetLanguage,
    bool? forceRefresh,
  }) async {
    if (_resultOrError is Exception) throw _resultOrError;
    return _resultOrError as DictionaryResult;
  }
}

const _fullDictionaryResult = DictionaryResult(
  word: 'run',
  sourceLanguage: 'en',
  targetLanguage: 'zh',
  lemma: 'to run',
  ipa: '/rʌn/',
  senses: [
    DictionarySense(
      definition: 'move at a pace faster than walking',
      translation: '跑步',
      partOfSpeech: 'verb',
      examples: [
        DictionaryExample(source: 'I run every morning.', target: '我每天早上跑步。'),
      ],
    ),
    DictionarySense(
      definition: 'a continuous period of time',
      translation: '运行',
      notes: 'Figurative use.',
    ),
  ],
);

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
  // The card starts collapsed — tap the "Definition" header to expand and
  // surface the body.
  await tester.tap(find.text('Definition'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AiResultCache<DictionaryResult> dictCache;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    dictCache = AiResultCache<DictionaryResult>(
      dao: db.aiCacheDao,
      l1: L1Store<String, DictionaryResult>(
        capacity: 16,
        ttl: const Duration(minutes: 30),
      ),
      policies: defaultAiKindPolicies,
      fromJson: DictionaryResult.fromJson,
      toJson: (value) => value.toJson(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  const request = LookupRequest(
    selectedText: 'run',
    sourceLanguage: 'en',
    targetLanguage: 'zh',
  );

  List<Override> baseOverrides({DictionaryCapability? capability}) => [
    authCtrlProvider.overrideWith(_AuthSignedInCtrl.new),
    appDatabaseProvider.overrideWithValue(db),
    aiDictionaryCacheProvider.overrideWithValue(dictCache),
    if (capability != null)
      dictionaryCapabilityProvider.overrideWithValue(capability),
  ];

  testWidgets('renders the dictionary body with senses after data arrives', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        overrides: baseOverrides(
          capability: _FakeDictionaryCapability(_fullDictionaryResult),
        ),
        child: const DictionaryLookupSection(request: request),
      ),
    );
    await _expand(tester);

    // Headword shows the queried word.
    expect(find.text('run'), findsWidgets);
    // Lemma + IPA render.
    expect(find.textContaining('/rʌn/'), findsOneWidget);
    // Sense definition + translation.
    expect(find.textContaining('move at a pace'), findsOneWidget);
    expect(find.text('跑步'), findsOneWidget);
    // Second sense without examples.
    expect(find.text('运行'), findsOneWidget);
    // Example source + target.
    expect(find.text('I run every morning.'), findsOneWidget);
    expect(find.text('我每天早上跑步。'), findsOneWidget);
  });

  testWidgets('omits lemma when it equals the headword', (tester) async {
    const result = DictionaryResult(
      word: 'hello',
      sourceLanguage: 'en',
      targetLanguage: 'zh',
      lemma: 'hello',
      senses: [],
    );
    await tester.pumpWidget(
      _harness(
        overrides: baseOverrides(capability: _FakeDictionaryCapability(result)),
        child: const DictionaryLookupSection(
          request: LookupRequest(
            selectedText: 'hello',
            sourceLanguage: 'en',
            targetLanguage: 'zh',
          ),
        ),
      ),
    );
    await _expand(tester);

    expect(find.text('hello'), findsWidgets);
    // Lemma segment should be skipped when lemmaTrim == word.trim().
    expect(find.textContaining('Lemma ·'), findsNothing);
  });

  testWidgets('shows AuthRequiredCallout on AuthFailure', (tester) async {
    await tester.pumpWidget(
      _harness(
        overrides: [
          authCtrlProvider.overrideWith(_AuthSignedOutCtrl.new),
          appDatabaseProvider.overrideWithValue(db),
          aiDictionaryCacheProvider.overrideWithValue(dictCache),
          dictionaryCapabilityProvider.overrideWithValue(
            _FakeDictionaryCapability(const AuthFailure('nope')),
          ),
        ],
        child: const DictionaryLookupSection(request: request),
      ),
    );
    await _expand(tester);

    expect(find.byType(LookupErrorRow), findsNothing);
    // When the user is signed out, `AuthRequiredCallout` shows a sign-in
    // button so they can re-auth before retrying the lookup.
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('shows error row with View plans CTA on CreditsFailure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        overrides: baseOverrides(
          capability: _FakeDictionaryCapability(
            const CreditsFailure('out of credits'),
          ),
        ),
        child: const DictionaryLookupSection(request: request),
      ),
    );
    await _expand(tester);

    expect(find.byType(LookupErrorRow), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    // The unified "View plans & packages" CTA (spec 045) for credits failures.
    expect(
      find.text(
        lookupAppLocalizations(
          const Locale('en'),
        ).subscriptionViewPlansAndPackages,
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the numbered credits message when the 402 carries the '
      'worker envelope (no raw status leak)', (tester) async {
    await tester.pumpWidget(
      _harness(
        overrides: baseOverrides(
          capability: _FakeDictionaryCapability(
            const CreditsFailure(
              'HTTP 402',
              requiredCredits: 750,
              usedCredits: 800,
              limitCredits: 1000,
            ),
          ),
        ),
        child: const DictionaryLookupSection(request: request),
      ),
    );
    await _expand(tester);

    expect(find.textContaining('750'), findsOneWidget);
    expect(find.textContaining('200'), findsOneWidget);
    expect(find.text('HTTP 402'), findsNothing);
  });

  testWidgets('shows plain error row for generic failure', (tester) async {
    await tester.pumpWidget(
      _harness(
        overrides: baseOverrides(
          capability: _FakeDictionaryCapability(
            const NetworkFailure('boom', statusCode: 500),
          ),
        ),
        child: const DictionaryLookupSection(request: request),
      ),
    );
    await _expand(tester);

    expect(find.byType(LookupErrorRow), findsOneWidget);
    // No "View plans" CTA for non-credit errors.
    expect(find.text('View plans'), findsNothing);
  });
}
