import 'package:enjoy_player/features/ai/domain/models/contextual_translation_result.dart';
import 'package:enjoy_player/features/ai/domain/models/dictionary_result.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_source_title.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_explanation_codec.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_flashcard.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_text_style.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthSignedInCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'test-user', email: 't@example.com', name: 'Test'),
  );
}

VocabularyItem _item({String? explanation}) => VocabularyItem(
  id: 'i1',
  word: 'hello',
  language: 'en',
  targetLanguage: 'zh',
  status: VocabularyStatus.new_,
  easeFactor: 2.5,
  interval: 0,
  nextReviewAt: DateTime.utc(2030),
  reviewsCount: 0,
  contextsCount: 1,
  explanation: explanation,
  createdAt: DateTime.utc(2020),
  updatedAt: DateTime.utc(2020),
);

VocabularyContext _context({String? explanation}) => VocabularyContext(
  id: 'c1',
  vocabularyItemId: 'i1',
  text: 'Hello world.',
  sourceType: VocabularySourceType.video,
  sourceId: 'v1',
  locator: const MediaLocator(start: 1000, duration: 2000),
  explanation: explanation,
  createdAt: DateTime.utc(2020),
  updatedAt: DateTime.utc(2020),
);

Widget _wrap(Widget child, {String? sourceTitle = 'Test Talk Title'}) {
  return ProviderScope(
    overrides: [
      authCtrlProvider.overrideWith(_AuthSignedInCtrl.new),
      vocabularySourceTitleProvider.overrideWith(
        (ref, id) async => sourceTitle,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

VocabularyFlashcard _card({
  VocabularyItem? item,
  VocabularyContext? primaryContext,
  bool flipped = true,
  VoidCallback? onUnflip,
}) {
  return VocabularyFlashcard(
    item: item ?? _item(),
    primaryContext: primaryContext ?? _context(),
    flipped: flipped,
    dictionaryFetchInFlight: false,
    contextualFetchInFlight: false,
    clipPlayInFlight: false,
    onFlip: () {},
    onUnflip: onUnflip ?? () {},
    onFetchDictionary: () {},
    onFetchContextual: () {},
    onPlayClip: () {},
    onOpenInPlayer: () {},
    onShadowReading: () {},
  );
}

void main() {
  test('formatVocabularyIpa strips duplicate slashes', () {
    expect(formatVocabularyIpa('ɪnˈvɪʒən'), '/ɪnˈvɪʒən/');
    expect(formatVocabularyIpa('/ɪnˈvɪʒən/'), '/ɪnˈvɪʒən/');
    expect(formatVocabularyIpa('//ɪnˈvɪʒən//'), '/ɪnˈvɪʒən/');
  });

  test('stripRedundantContextualHeading drops duplicate translation H2', () {
    expect(stripRedundantContextualHeading('## 翻译\n\nImagine.'), 'Imagine.');
    expect(
      stripRedundantContextualHeading('## Meaning\n\nKeep this.'),
      '## Meaning\n\nKeep this.',
    );
  });

  test('pruneEmptyMarkdownSections drops empty headings', () {
    expect(
      pruneEmptyMarkdownSections(
        '原来句子。\n\n## 关键词/短语分析\n\n## 词性\n\n### 有内容\n\n动词。',
      ),
      '原来句子。\n\n### 有内容\n\n动词。',
    );
  });

  test('prepareContextualMarkdown strips redundant and empty sections', () {
    expect(
      prepareContextualMarkdown('## 翻译\n\n原来句子。\n\n## 关键词/短语分析\n\n## 词性\n'),
      '原来句子。',
    );
  });

  test('parseContextualMarkdownDocument splits preamble and sections', () {
    final doc = parseContextualMarkdownDocument(
      '## 翻译\n\n原来句子。\n\n## 词性\n\n名词。\n\n## 语境中的含义\n\n炎症。',
    );
    expect(doc.preamble, '原来句子。');
    expect(doc.sections.map((s) => s.title), ['词性', '语境中的含义']);
    expect(doc.sections.map((s) => s.body), ['名词。', '炎症。']);
  });

  testWidgets('Dictionary tab shows cached explanation', (tester) async {
    final explanation = encodeDictionaryExplanation(
      const DictionaryResult(
        word: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        senses: [DictionarySense(definition: 'a greeting')],
      ),
    );
    await tester.pumpWidget(
      _wrap(_card(item: _item(explanation: explanation))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsNothing);
    await tester.tap(find.text('Dictionary'));
    await tester.pumpAndSettle();
    expect(find.textContaining('a greeting'), findsOneWidget);
  });

  testWidgets('Context tab shows play and open actions for media', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_card()));
    await tester.pumpAndSettle();
    expect(find.text('Hello world.'), findsOneWidget);
    expect(find.byTooltip('Play segment'), findsOneWidget);
    expect(find.byTooltip('Open in player'), findsOneWidget);
    expect(find.byTooltip('Echo reading'), findsOneWidget);
    expect(find.text('Flip back'), findsNothing);
  });

  testWidgets('tapping the back face invokes onUnflip', (tester) async {
    var unflipped = false;
    await tester.pumpWidget(_wrap(_card(onUnflip: () => unflipped = true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('hello'));
    await tester.pumpAndSettle();
    expect(unflipped, isTrue);
  });

  testWidgets('Dictionary tab shows IPA and translation separately', (
    tester,
  ) async {
    final explanation = encodeDictionaryExplanation(
      const DictionaryResult(
        word: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        ipa: '/həˈləʊ/',
        senses: [
          DictionarySense(
            definition: 'a greeting',
            translation: '你好',
            partOfSpeech: 'noun',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      _wrap(_card(item: _item(explanation: explanation))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dictionary'));
    await tester.pumpAndSettle();
    expect(find.text('/həˈləʊ/'), findsOneWidget);
    expect(find.text('//həˈləʊ//'), findsNothing);
    expect(find.text('noun'), findsOneWidget);
    expect(find.text('a greeting'), findsOneWidget);
    expect(find.text('你好'), findsOneWidget);
  });

  testWidgets('Context tab renders markdown without empty heading clutter', (
    tester,
  ) async {
    final explanation = encodeContextualExplanation(
      const ContextualTranslationResult(
        translatedText:
            '## Translation\n\nImagine or conceive.\n\n## 关键词/短语分析\n\n## 词性\n',
      ),
    );
    await tester.pumpWidget(
      _wrap(_card(primaryContext: _context(explanation: explanation))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Contextual translation'), findsOneWidget);
    expect(find.textContaining('## Translation'), findsNothing);
    expect(find.textContaining('关键词'), findsNothing);
    expect(find.textContaining('词性'), findsNothing);
    expect(find.textContaining('Imagine or conceive.'), findsOneWidget);
  });

  testWidgets('Context sentence highlights the study word', (tester) async {
    await tester.pumpWidget(_wrap(_card()));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((w) {
        if (w is! RichText) return false;
        return w.text.toPlainText().contains('Hello world.');
      }),
      findsWidgets,
    );
  });

  testWidgets('Context tab shows media title instead of source id', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_card()));
    await tester.pumpAndSettle();
    expect(find.text('Test Talk Title'), findsOneWidget);
    expect(find.text('v1'), findsNothing);
  });

  testWidgets('Context tab falls back when title missing', (tester) async {
    await tester.pumpWidget(_wrap(_card(), sourceTitle: null));
    await tester.pumpAndSettle();
    expect(find.text('Unknown source'), findsOneWidget);
    expect(find.text('v1'), findsNothing);
  });
}
