import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_providers.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_session_selection.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_review_options.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

VocabularyItem _item({
  required String id,
  required String word,
  required String language,
  VocabularyStatus status = VocabularyStatus.new_,
  DateTime? nextReviewAt,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return VocabularyItem(
    id: id,
    word: word,
    language: language,
    targetLanguage: 'zh',
    status: status,
    easeFactor: 2.5,
    interval: 1,
    nextReviewAt: nextReviewAt ?? now,
    reviewsCount: 1,
    contextsCount: 1,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _harness({List<VocabularyItem> items = const []}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  return ProviderScope(
    overrides: [
      vocabularyItemsProvider.overrideWith((ref) => Stream.value(items)),
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
      home: const Scaffold(
        body: SizedBox(height: 800, child: VocabularyReviewOptionsSheet()),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VocabularyReviewOptionsSheet', () {
    testWidgets('renders all five review mode tiles', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Choose what to review'), findsOneWidget);
      expect(find.text('Due items'), findsOneWidget);
      expect(find.text('All words'), findsOneWidget);
      expect(find.text('By status'), findsOneWidget);
      expect(find.text('By language'), findsOneWidget);
      expect(find.text('Random'), findsOneWidget);
      expect(find.byType(DropdownButton<VocabularyStatus>), findsNothing);
    });

    testWidgets('selecting byStatus shows status dropdown', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('By status'));
      await tester.pumpAndSettle();

      expect(find.text('Status'), findsOneWidget);
      expect(find.byType(DropdownButton<VocabularyStatus>), findsOneWidget);
    });

    testWidgets(
      'selecting byLanguage shows language dropdown seeded from items',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            items: [
              _item(id: '1', word: 'hola', language: 'es'),
              _item(id: '2', word: 'ciao', language: 'it'),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('By language'));
        await tester.pumpAndSettle();

        expect(find.text('Language'), findsOneWidget);
        expect(find.byType(DropdownButton<String>), findsOneWidget);
      },
    );

    testWidgets('selecting random shows number-of-words field', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Random'));
      await tester.pumpAndSettle();

      expect(find.text('Number of words'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Number of words'),
        findsOneWidget,
      );
    });

    testWidgets(
      'start review with empty queue surfaces error and does not pop',
      (tester) async {
        await tester.pumpWidget(_harness());
        await tester.pumpAndSettle();

        expect(find.text('No words match this selection.'), findsNothing);
        await tester.tap(find.text('Start review'));
        await tester.pumpAndSettle();

        expect(find.text('No words match this selection.'), findsOneWidget);
      },
    );

    testWidgets('preview queue count reflects items for due mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          items: [
            _item(
              id: '1',
              word: 'due',
              language: 'en',
              nextReviewAt: DateTime.utc(2000),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 words'), findsOneWidget);
    });

    testWidgets('changing random count text updates preview', (tester) async {
      await tester.pumpWidget(
        _harness(
          items: [
            _item(id: '1', word: 'a', language: 'en'),
            _item(id: '2', word: 'b', language: 'en'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Random'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Number of words'),
        '1',
      );
      await tester.pumpAndSettle();

      expect(find.text('1 words'), findsOneWidget);
    });

    testWidgets('selecting byStatus and changing status value updates filter', (
      tester,
    ) async {
      // One due item with future date so it is not due.
      // Use two items with same status to verify filter counts.
      await tester.pumpWidget(
        _harness(
          items: [
            _item(
              id: '1',
              word: 'new1',
              language: 'en',
              status: VocabularyStatus.new_,
            ),
            _item(
              id: '2',
              word: 'new2',
              language: 'en',
              status: VocabularyStatus.new_,
            ),
            _item(
              id: '3',
              word: 'mastered',
              language: 'en',
              status: VocabularyStatus.mastered,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('By status'));
      await tester.pumpAndSettle();

      // Default status filter is .new_ -> 2 words.
      expect(find.text('2 words'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<VocabularyStatus>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mastered').last);
      await tester.pumpAndSettle();

      // After switching to Mastered, queue count drops to 1.
      expect(find.text('1 words'), findsOneWidget);
    });

    testWidgets('tapping a mode resets any prior error', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start review'));
      await tester.pumpAndSettle();
      expect(find.text('No words match this selection.'), findsOneWidget);

      await tester.tap(find.text('All words'));
      await tester.pumpAndSettle();
      expect(find.text('No words match this selection.'), findsNothing);
    });

    testWidgets('ReviewSelectionOptions enum exposes all five modes', (
      tester,
    ) async {
      expect(
        VocabularyReviewMode.values,
        containsAll([
          VocabularyReviewMode.due,
          VocabularyReviewMode.all,
          VocabularyReviewMode.byStatus,
          VocabularyReviewMode.byLanguage,
          VocabularyReviewMode.random,
        ]),
      );
    });
  });
}
