import 'package:enjoy_player/features/ai/domain/models/dictionary_result.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_explanation_codec.dart';
import 'package:enjoy_player/features/vocabulary/presentation/widgets/vocabulary_flashcard_dictionary_tab.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

class _AuthSignedInCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'test-user', email: 't@example.com', name: 'Test'),
  );
}

class _AuthSignedOutCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

Widget _wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('auto-fetches dictionary when signed in and cache empty', (
    tester,
  ) async {
    var fetchCount = 0;
    await tester.pumpWidget(
      _wrap(
        FlashcardDictionaryTab(
          explanation: null,
          fetchInFlight: false,
          error: null,
          onFetch: () => fetchCount++,
        ),
        overrides: [authCtrlProvider.overrideWith(_AuthSignedInCtrl.new)],
      ),
    );
    // AuthCtrl is async — wait for signed-in, then post-frame autoload.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(fetchCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.text('Dictionary not available offline'), findsNothing);
    expect(find.text('Look up dictionary'), findsNothing);
  });

  testWidgets('shows loading while fetch is in flight', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FlashcardDictionaryTab(
          explanation: null,
          fetchInFlight: true,
          error: null,
          onFetch: () {},
        ),
        overrides: [authCtrlProvider.overrideWith(_AuthSignedInCtrl.new)],
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Look up dictionary'), findsNothing);
  });

  testWidgets('shows retry only after a failed fetch', (tester) async {
    var fetchCount = 0;
    await tester.pumpWidget(
      _wrap(
        FlashcardDictionaryTab(
          explanation: null,
          fetchInFlight: false,
          error: 'fetch_failed',
          onFetch: () => fetchCount++,
        ),
        overrides: [authCtrlProvider.overrideWith(_AuthSignedInCtrl.new)],
      ),
    );
    await tester.pump();

    expect(find.text('Look up dictionary'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(fetchCount, 0);

    await tester.tap(find.text('Look up dictionary'));
    await tester.pump();
    expect(fetchCount, 1);
  });

  testWidgets('does not auto-fetch when signed out', (tester) async {
    var fetchCount = 0;
    await tester.pumpWidget(
      _wrap(
        FlashcardDictionaryTab(
          explanation: null,
          fetchInFlight: false,
          error: null,
          onFetch: () => fetchCount++,
        ),
        overrides: [authCtrlProvider.overrideWith(_AuthSignedOutCtrl.new)],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(fetchCount, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders cached dictionary without fetching', (tester) async {
    var fetchCount = 0;
    final cached = encodeDictionaryExplanation(
      const DictionaryResult(
        word: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        senses: [DictionarySense(definition: 'A greeting.', translation: '你好')],
      ),
    );
    await tester.pumpWidget(
      _wrap(
        FlashcardDictionaryTab(
          explanation: cached,
          fetchInFlight: false,
          error: null,
          onFetch: () => fetchCount++,
        ),
        overrides: [authCtrlProvider.overrideWith(_AuthSignedInCtrl.new)],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(fetchCount, 0);
    expect(find.text('A greeting.'), findsOneWidget);
    expect(find.text('你好'), findsOneWidget);
  });
}
