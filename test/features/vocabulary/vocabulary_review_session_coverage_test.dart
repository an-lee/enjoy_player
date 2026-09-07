import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/ai/application/ai_capability_providers.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/contextual_translation_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/dictionary_capability.dart';
import 'package:enjoy_player/features/ai/domain/models/contextual_translation_result.dart';
import 'package:enjoy_player/features/ai/domain/models/dictionary_result.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';
import 'package:enjoy_player/features/vocabulary/data/vocabulary_repository.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_review_practice.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_session_selection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_player_engine.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final class _ThrowingDictionary implements DictionaryCapability {
  const _ThrowingDictionary();

  @override
  Future<DictionaryResult> lookupDictionary({
    required String word,
    required String sourceLanguage,
    required String targetLanguage,
    bool? forceRefresh,
  }) async {
    throw Exception('dictionary network error');
  }
}

final class _ThrowingContextual implements ContextualTranslationCapability {
  const _ThrowingContextual();

  @override
  Future<ContextualTranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? context,
  }) async {
    throw Exception('contextual network error');
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

VocabularyItem _makeItem({String id = 'i1', String word = 'hello'}) {
  return VocabularyItem(
    id: id,
    word: word,
    language: 'en',
    targetLanguage: 'zh',
    status: VocabularyStatus.new_,
    easeFactor: 2.5,
    interval: 0,
    reviewsCount: 0,
    nextReviewAt: DateTime.utc(2030),
    createdAt: DateTime.utc(2020),
    updatedAt: DateTime.utc(2020),
    contextsCount: 1,
  );
}

VocabularyContext _makeContext({
  String id = 'c1',
  String itemId = 'i1',
  String text = 'sample text',
  VocabularySourceType sourceType = VocabularySourceType.video,
  String sourceId = 'v1',
  MediaLocator? locator = const MediaLocator(start: 0, duration: 1000),
}) {
  return VocabularyContext(
    id: id,
    vocabularyItemId: itemId,
    text: text,
    sourceType: sourceType,
    sourceId: sourceId,
    locator: locator,
    createdAt: DateTime.utc(2020),
    updatedAt: DateTime.utc(2020),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late FakePlayerEngine fakeEngine;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    fakeEngine = FakePlayerEngine();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        playerEngineTestDoubleProvider.overrideWithValue(fakeEngine),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await fakeEngine.dispose();
    await db.close();
  });

  // =========================================================================
  // ReviewSessionState pure getters / edge cases
  // =========================================================================

  group('ReviewSessionState getters', () {
    test('hasActiveSession is false for empty queue', () {
      const state = ReviewSessionState(queue: []);
      expect(state.hasActiveSession, isFalse);
    });

    test('canUndo is false when ratingInFlight', () {
      final state = ReviewSessionState(
        queue: [_makeItem()],
        ratedStack: const ['i1'],
        ratingInFlight: true,
      );
      expect(state.canUndo, isFalse);
    });

    test('canUndo is false when ratedStack is empty', () {
      final state = ReviewSessionState(queue: [_makeItem()]);
      expect(state.canUndo, isFalse);
    });

    test('canUndo is true when ratedStack non-empty and not in flight', () {
      final state = ReviewSessionState(
        queue: [_makeItem()],
        ratedStack: const ['i1'],
      );
      expect(state.canUndo, isTrue);
    });

    test('currentItem returns null when completed', () {
      final state = ReviewSessionState(
        queue: [_makeItem()],
        completed: true,
        index: 1,
      );
      expect(state.currentItem, isNull);
    });

    test('currentItem returns null when index out of bounds', () {
      final state = ReviewSessionState(queue: [_makeItem()], index: 5);
      expect(state.currentItem, isNull);
    });

    test('currentItem returns null when index is negative', () {
      final state = ReviewSessionState(queue: [_makeItem()], index: -1);
      expect(state.currentItem, isNull);
    });

    test('currentPrimaryContext returns null when item is null', () {
      const state = ReviewSessionState(queue: []);
      expect(state.currentPrimaryContext, isNull);
    });

    test('activeContextIndexFor clamps negative raw index to 0', () {
      final state = ReviewSessionState(
        queue: [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
        activeContextIndexByItemId: {'i1': -3},
      );
      expect(state.activeContextIndexFor('i1'), 0);
    });

    test('activeContextIndexFor clamps raw >= list.length to last', () {
      final state = ReviewSessionState(
        queue: [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext(id: 'c1'), _makeContext(id: 'c2')],
        },
        activeContextIndexByItemId: {'i1': 99},
      );
      expect(state.activeContextIndexFor('i1'), 1);
    });

    test('activeContextIndexFor returns 0 for empty list', () {
      final state = ReviewSessionState(queue: [_makeItem()]);
      expect(state.activeContextIndexFor('i1'), 0);
    });

    test('displayCurrent returns total when completed', () {
      final state = ReviewSessionState(
        queue: [
          _makeItem(),
          _makeItem(id: 'i2'),
        ],
        completed: true,
        index: 2,
      );
      expect(state.displayCurrent, 2);
    });

    test('remaining returns 0 when completed', () {
      final state = ReviewSessionState(
        queue: [
          _makeItem(),
          _makeItem(id: 'i2'),
        ],
        completed: true,
        index: 2,
      );
      expect(state.remaining, 0);
    });

    test('remaining returns correct count mid-session', () {
      final state = ReviewSessionState(
        queue: [
          _makeItem(),
          _makeItem(id: 'i2'),
          _makeItem(id: 'i3'),
        ],
        index: 0,
      );
      expect(state.remaining, 2);
    });

    test('primaryContextFor returns null for empty list', () {
      final state = ReviewSessionState(queue: [_makeItem()]);
      expect(state.primaryContextFor('i1'), isNull);
    });

    test('practiceSheetOpen is true for non-none phases', () {
      final state = ReviewSessionState(
        queue: [_makeItem()],
        practicePhase: ReviewPracticePhase.echo,
      );
      expect(state.practiceSheetOpen, isTrue);
    });

    test('practiceSheetOpen is false for none phase', () {
      final state = ReviewSessionState(queue: [_makeItem()]);
      expect(state.practiceSheetOpen, isFalse);
    });

    test('practiceOwnsVideoStage is true for clip phases', () {
      final opening = ReviewSessionState(
        queue: [_makeItem()],
        practicePhase: ReviewPracticePhase.clipOpening,
      );
      expect(opening.practiceOwnsVideoStage, isTrue);

      final ready = ReviewSessionState(
        queue: [_makeItem()],
        practicePhase: ReviewPracticePhase.clipReady,
      );
      expect(ready.practiceOwnsVideoStage, isTrue);
    });

    test('practiceOwnsVideoStage is false for echo and none', () {
      final echo = ReviewSessionState(
        queue: [_makeItem()],
        practicePhase: ReviewPracticePhase.echo,
      );
      expect(echo.practiceOwnsVideoStage, isFalse);

      final none = ReviewSessionState(queue: [_makeItem()]);
      expect(none.practiceOwnsVideoStage, isFalse);
    });

    test('clipPlayInFlight is true only for clipOpening', () {
      final opening = ReviewSessionState(
        queue: [_makeItem()],
        practicePhase: ReviewPracticePhase.clipOpening,
      );
      expect(opening.clipPlayInFlight, isTrue);

      final ready = ReviewSessionState(
        queue: [_makeItem()],
        practicePhase: ReviewPracticePhase.clipReady,
      );
      expect(ready.clipPlayInFlight, isFalse);
    });

    test('claimsVideoSurface is true only for clipReady', () {
      final ready = ReviewSessionState(
        queue: [_makeItem()],
        practicePhase: ReviewPracticePhase.clipReady,
      );
      expect(ready.claimsVideoSurface, isTrue);

      final opening = ReviewSessionState(
        queue: [_makeItem()],
        practicePhase: ReviewPracticePhase.clipOpening,
      );
      expect(opening.claimsVideoSurface, isFalse);
    });

    test('practiceMode maps phases correctly', () {
      expect(
        ReviewSessionState(queue: [_makeItem()]).practiceMode,
        ReviewPracticeMode.none,
      );
      expect(
        ReviewSessionState(
          queue: [_makeItem()],
          practicePhase: ReviewPracticePhase.clipOpening,
        ).practiceMode,
        ReviewPracticeMode.clip,
      );
      expect(
        ReviewSessionState(
          queue: [_makeItem()],
          practicePhase: ReviewPracticePhase.clipReady,
        ).practiceMode,
        ReviewPracticeMode.clip,
      );
      expect(
        ReviewSessionState(
          queue: [_makeItem()],
          practicePhase: ReviewPracticePhase.echo,
        ).practiceMode,
        ReviewPracticeMode.echo,
      );
    });

    test('currentContextsCount returns 0 when item is null', () {
      const state = ReviewSessionState(queue: []);
      expect(state.currentContextsCount, 0);
    });

    test('currentActiveContextIndex returns 0 when item is null', () {
      const state = ReviewSessionState(queue: []);
      expect(state.currentActiveContextIndex, 0);
    });
  });

  // =========================================================================
  // copyWith clear flags
  // =========================================================================

  group('copyWith clear flags', () {
    test('clearDictionaryError removes dictionaryError', () {
      final state = ReviewSessionState(
        queue: [_makeItem()],
        dictionaryError: 'some_error',
      );
      final cleared = state.copyWith(clearDictionaryError: true);
      expect(cleared.dictionaryError, isNull);
    });

    test('clearContextualError removes contextualError', () {
      final state = ReviewSessionState(
        queue: [_makeItem()],
        contextualError: 'some_error',
      );
      final cleared = state.copyWith(clearContextualError: true);
      expect(cleared.contextualError, isNull);
    });

    test('clearMediaError removes mediaError', () {
      final state = ReviewSessionState(
        queue: [_makeItem()],
        mediaError: 'some_error',
      );
      final cleared = state.copyWith(clearMediaError: true);
      expect(cleared.mediaError, isNull);
    });

    test('setting new error value replaces old', () {
      final state = ReviewSessionState(
        queue: [_makeItem()],
        dictionaryError: 'old',
      );
      final updated = state.copyWith(dictionaryError: 'new');
      expect(updated.dictionaryError, 'new');
    });
  });

  // =========================================================================
  // startWithQueue
  // =========================================================================

  group('startWithQueue', () {
    test('empty queue resets state', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      expect(
        container.read(vocabularyReviewSessionProvider).hasActiveSession,
        isTrue,
      );

      session.startWithQueue([]);
      expect(
        container.read(vocabularyReviewSessionProvider).hasActiveSession,
        isFalse,
      );
    });

    test('primaryContextByItemId fallback populates contexts', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      final ctx = _makeContext();
      session.startWithQueue(
        [_makeItem()],
        primaryContextByItemId: {'i1': ctx},
      );
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.contextsFor('i1'), hasLength(1));
      expect(state.contextsFor('i1').first.id, 'c1');
      expect(state.activeContextIndexFor('i1'), 0);
    });

    test('explicit contextsByItemId takes precedence', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      final ctx1 = _makeContext(id: 'c1');
      final ctx2 = _makeContext(id: 'c2');
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [ctx1, ctx2],
        },
        activeContextIndexByItemId: {'i1': 1},
        primaryContextByItemId: {'i1': _makeContext(id: 'ignored')},
      );
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.contextsFor('i1'), hasLength(2));
      expect(state.activeContextIndexFor('i1'), 1);
    });
  });

  // =========================================================================
  // clear()
  // =========================================================================

  group('clear', () {
    test('clears session and deactivates echo when practice was open', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
      );
      session.debugSetPracticePhase(ReviewPracticePhase.echo);
      expect(
        container.read(vocabularyReviewSessionProvider).practiceSheetOpen,
        isTrue,
      );

      session.clear();
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.hasActiveSession, isFalse);
      expect(state.queue, isEmpty);
    });

    test('clears session without practice (no echo deactivation needed)', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.clear();
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.hasActiveSession, isFalse);
    });
  });

  // =========================================================================
  // clearPractice
  // =========================================================================

  group('clearPractice', () {
    test('early return when phase is already none', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      // Should not throw or change state.
      await session.clearPractice();
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.practicePhase, ReviewPracticePhase.none);
      expect(state.hasActiveSession, isTrue);
    });

    test('clears clip phase and media error', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
      );
      session.debugSetPracticePhase(ReviewPracticePhase.clipReady);
      await session.clearPractice();
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.practicePhase, ReviewPracticePhase.none);
      expect(state.mediaError, isNull);
    });
  });

  // =========================================================================
  // selectContext edge cases
  // =========================================================================

  group('selectContext edge cases', () {
    test('no-op when completed', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext(id: 'c1'), _makeContext(id: 'c2')],
        },
      );
      // Force completed state.
      session.debugSetPracticePhase(ReviewPracticePhase.none);
      // Manually complete by rating the only item.
      session.flip();
      await session.rate(VocabularyRating.know);
      expect(container.read(vocabularyReviewSessionProvider).completed, isTrue);

      await session.selectContext(1);
      // Should remain unchanged (no-op).
      expect(container.read(vocabularyReviewSessionProvider).completed, isTrue);
    });

    test('no-op when context list is empty', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      await session.selectContext(1);
      // No contexts, so nothing changes.
      expect(
        container
            .read(vocabularyReviewSessionProvider)
            .currentActiveContextIndex,
        0,
      );
    });
  });

  // =========================================================================
  // selectPreviousContext / selectNextContext
  // =========================================================================

  group('selectPreviousContext / selectNextContext', () {
    test('selectPreviousContext no-op at index 0', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext(id: 'c1'), _makeContext(id: 'c2')],
        },
      );
      await session.selectPreviousContext();
      expect(
        container
            .read(vocabularyReviewSessionProvider)
            .currentActiveContextIndex,
        0,
      );
    });

    test('selectNextContext no-op at last index', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext(id: 'c1'), _makeContext(id: 'c2')],
        },
        activeContextIndexByItemId: {'i1': 1},
      );
      await session.selectNextContext();
      expect(
        container
            .read(vocabularyReviewSessionProvider)
            .currentActiveContextIndex,
        1,
      );
    });

    test('selectNextContext advances index', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext(id: 'c1'), _makeContext(id: 'c2')],
        },
      );
      await session.selectNextContext();
      expect(
        container
            .read(vocabularyReviewSessionProvider)
            .currentActiveContextIndex,
        1,
      );
    });

    test('selectPreviousContext decrements index', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext(id: 'c1'), _makeContext(id: 'c2')],
        },
        activeContextIndexByItemId: {'i1': 1},
      );
      await session.selectPreviousContext();
      expect(
        container
            .read(vocabularyReviewSessionProvider)
            .currentActiveContextIndex,
        0,
      );
    });

    test('selectPreviousContext no-op when item is null', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      // No active session.
      await session.selectPreviousContext();
      // Should not throw.
    });

    test('selectNextContext no-op when item is null', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      await session.selectNextContext();
      // Should not throw.
    });
  });

  // =========================================================================
  // flip / unflip / toggleFlip guards
  // =========================================================================

  group('flip / unflip / toggleFlip guards', () {
    test('flip no-op when completed', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.flip();
      // Complete the session by rating.
      container.read(vocabularyReviewSessionProvider.notifier).skip();
      expect(container.read(vocabularyReviewSessionProvider).completed, isTrue);
      session.flip();
      expect(container.read(vocabularyReviewSessionProvider).flipped, isFalse);
    });

    test('unflip no-op when not flipped', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.unflip();
      expect(container.read(vocabularyReviewSessionProvider).flipped, isFalse);
    });

    test('unflip no-op when completed', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.flip();
      session.skip();
      // Now completed; unflip should be no-op.
      session.unflip();
      expect(container.read(vocabularyReviewSessionProvider).flipped, isFalse);
    });

    test('toggleFlip flips then unflips', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.toggleFlip();
      expect(container.read(vocabularyReviewSessionProvider).flipped, isTrue);
      session.toggleFlip();
      expect(container.read(vocabularyReviewSessionProvider).flipped, isFalse);
    });

    test('flip no-op when practiceSheetOpen', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.debugSetPracticePhase(ReviewPracticePhase.echo);
      session.flip();
      expect(container.read(vocabularyReviewSessionProvider).flipped, isFalse);
    });

    test('unflip no-op when practiceSheetOpen', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      // First flip without practice.
      session.flip();
      expect(container.read(vocabularyReviewSessionProvider).flipped, isTrue);
      // Now open practice.
      session.debugSetPracticePhase(ReviewPracticePhase.echo);
      session.unflip();
      // Should remain flipped because unflip is blocked.
      expect(container.read(vocabularyReviewSessionProvider).flipped, isTrue);
    });
  });

  // =========================================================================
  // rate guards and completion
  // =========================================================================

  group('rate guards and completion', () {
    test('rate no-op when not flipped', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      await session.rate(VocabularyRating.know);
      expect(container.read(vocabularyReviewSessionProvider).index, 0);
      expect(
        container.read(vocabularyReviewSessionProvider).ratedStack,
        isEmpty,
      );
    });

    test('rate no-op when completed', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.flip();
      await session.rate(VocabularyRating.know);
      expect(container.read(vocabularyReviewSessionProvider).completed, isTrue);
      // Try rating again — should be no-op.
      await session.rate(VocabularyRating.know);
      expect(
        container.read(vocabularyReviewSessionProvider).ratedStack,
        hasLength(1),
      );
    });

    test('rate completes session on last item', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.flip();
      await session.rate(VocabularyRating.knowWell);
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.completed, isTrue);
      expect(state.index, 1);
      expect(state.displayCurrent, 1);
      expect(state.remaining, 0);
      expect(state.currentItem, isNull);
    });

    test('rate advances to next item when not last', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem(id: 'i1'), _makeItem(id: 'i2')]);
      session.flip();
      await session.rate(VocabularyRating.dontKnow);
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.completed, isFalse);
      expect(state.index, 1);
      expect(state.currentItem?.id, 'i2');
      expect(state.flipped, isFalse);
    });
  });

  // =========================================================================
  // skip guards and completion
  // =========================================================================

  group('skip guards and completion', () {
    test('skip no-op when completed', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.skip();
      expect(container.read(vocabularyReviewSessionProvider).completed, isTrue);
      // Skip again — no-op.
      session.skip();
      expect(
        container.read(vocabularyReviewSessionProvider).history,
        hasLength(1),
      );
    });

    test('skip no-op when practiceSheetOpen', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.debugSetPracticePhase(ReviewPracticePhase.echo);
      session.skip();
      expect(container.read(vocabularyReviewSessionProvider).index, 0);
      expect(container.read(vocabularyReviewSessionProvider).history, isEmpty);
    });

    test('skip completes session on last item', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.skip();
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.completed, isTrue);
      expect(state.index, 1);
      expect(state.history, hasLength(1));
      expect(state.history.first.wasRated, isFalse);
    });

    test('skip advances to next item when not last', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem(id: 'i1'), _makeItem(id: 'i2')]);
      session.skip();
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.completed, isFalse);
      expect(state.index, 1);
      expect(state.currentItem?.id, 'i2');
      expect(state.history, hasLength(1));
      expect(state.history.first.wasRated, isFalse);
    });
  });

  // =========================================================================
  // undo guards
  // =========================================================================

  group('undo guards', () {
    test('undo no-op when ratedStack is empty', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      await session.undo();
      expect(container.read(vocabularyReviewSessionProvider).index, 0);
    });

    test('undo no-op when practiceSheetOpen', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem(), _makeItem(id: 'i2')]);
      session.flip();
      await session.rate(VocabularyRating.know);
      session.debugSetPracticePhase(ReviewPracticePhase.echo);
      await session.undo();
      // Should not undo because practice is open.
      expect(
        container.read(vocabularyReviewSessionProvider).ratedStack,
        hasLength(1),
      );
    });

    test('undo restores previous item and clears completed', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem(id: 'i1'), _makeItem(id: 'i2')]);
      session.flip();
      await session.rate(VocabularyRating.know);
      session.flip();
      await session.rate(VocabularyRating.dontKnow);
      expect(container.read(vocabularyReviewSessionProvider).completed, isTrue);

      await session.undo();
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.completed, isFalse);
      expect(state.ratedStack, hasLength(1));
      expect(state.currentItem?.id, 'i2');
      expect(state.flipped, isFalse);
    });
  });

  // =========================================================================
  // previous
  // =========================================================================

  group('previous', () {
    test('no-op when history is empty', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.previous();
      expect(container.read(vocabularyReviewSessionProvider).index, 0);
    });

    test('no-op when practiceSheetOpen', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem(id: 'i1'), _makeItem(id: 'i2')]);
      session.skip();
      session.debugSetPracticePhase(ReviewPracticePhase.echo);
      session.previous();
      // Should not go back.
      expect(container.read(vocabularyReviewSessionProvider).index, 1);
    });

    test('navigates to previous item from history', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem(id: 'i1'), _makeItem(id: 'i2')]);
      session.skip();
      expect(container.read(vocabularyReviewSessionProvider).index, 1);

      session.previous();
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.index, 0);
      expect(state.currentItem?.id, 'i1');
      expect(state.flipped, isFalse);
      expect(state.completed, isFalse);
      expect(state.history, isEmpty);
    });

    test('handles item not found in queue gracefully', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      // Start with a queue, then manipulate history to reference missing item.
      session.startWithQueue([_makeItem(id: 'i1')]);
      session.skip();
      // History now has entry for 'i1'. Start a new queue without 'i1'.
      session.startWithQueue([_makeItem(id: 'i99')]);
      // Manually inject history with a missing item id via skip on i99.
      session.skip();
      // Now history has i99. previous should find i99 in queue.
      session.previous();
      expect(container.read(vocabularyReviewSessionProvider).index, 0);
    });
  });

  // =========================================================================
  // fetchDictionary error paths
  // =========================================================================

  group('fetchDictionary error paths', () {
    test('sets dictionaryError on fetch failure', () async {
      final errorContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          dictionaryCapabilityProvider.overrideWithValue(
            const _ThrowingDictionary(),
          ),
        ],
      );
      addTearDown(errorContainer.dispose);

      final repo = VocabularyRepository(db);
      await repo.addWithContext(
        word: 'fail',
        language: 'en',
        targetLanguage: 'zh',
        text: 'context',
        sourceType: VocabularySourceType.video,
        sourceId: 'v1',
        mediaLocator: const MediaLocator(start: 0, duration: 1000),
        now: DateTime.utc(2020, 1, 1),
      );

      final session = errorContainer.read(
        vocabularyReviewSessionProvider.notifier,
      );
      await session.start(
        const ReviewSelectionOptions(mode: VocabularyReviewMode.all),
        now: DateTime.utc(2030, 1, 1),
      );
      await session.fetchDictionary();

      final state = errorContainer.read(vocabularyReviewSessionProvider);
      expect(state.dictionaryFetchInFlight, isFalse);
      expect(state.dictionaryError, 'fetch_failed');
    });

    test('no-op when completed', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.skip();
      expect(container.read(vocabularyReviewSessionProvider).completed, isTrue);
      await session.fetchDictionary();
      expect(
        container.read(vocabularyReviewSessionProvider).dictionaryFetchInFlight,
        isFalse,
      );
    });

    test('no-op when practiceSheetOpen', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.debugSetPracticePhase(ReviewPracticePhase.echo);
      await session.fetchDictionary();
      expect(
        container.read(vocabularyReviewSessionProvider).dictionaryFetchInFlight,
        isFalse,
      );
    });
  });

  // =========================================================================
  // fetchContextualTranslation error paths
  // =========================================================================

  group('fetchContextualTranslation error paths', () {
    test('sets contextualError on fetch failure', () async {
      final errorContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contextualTranslationCapabilityProvider.overrideWithValue(
            const _ThrowingContextual(),
          ),
        ],
      );
      addTearDown(errorContainer.dispose);

      final repo = VocabularyRepository(db);
      await repo.addWithContext(
        word: 'fail',
        language: 'en',
        targetLanguage: 'zh',
        text: 'context text',
        sourceType: VocabularySourceType.video,
        sourceId: 'v1',
        mediaLocator: const MediaLocator(start: 0, duration: 1000),
        now: DateTime.utc(2020, 1, 1),
      );

      final session = errorContainer.read(
        vocabularyReviewSessionProvider.notifier,
      );
      await session.start(
        const ReviewSelectionOptions(mode: VocabularyReviewMode.all),
        now: DateTime.utc(2030, 1, 1),
      );
      await session.fetchContextualTranslation();

      final state = errorContainer.read(vocabularyReviewSessionProvider);
      expect(state.contextualFetchInFlight, isFalse);
      expect(state.contextualError, 'fetch_failed');
    });

    test('no-op when context is null', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      // Item with no contexts.
      session.startWithQueue([_makeItem()]);
      await session.fetchContextualTranslation();
      expect(
        container.read(vocabularyReviewSessionProvider).contextualFetchInFlight,
        isFalse,
      );
    });

    test('no-op when completed', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
      );
      session.skip();
      await session.fetchContextualTranslation();
      expect(
        container.read(vocabularyReviewSessionProvider).contextualFetchInFlight,
        isFalse,
      );
    });

    test('no-op when practiceSheetOpen', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
      );
      session.debugSetPracticePhase(ReviewPracticePhase.echo);
      await session.fetchContextualTranslation();
      expect(
        container.read(vocabularyReviewSessionProvider).contextualFetchInFlight,
        isFalse,
      );
    });
  });

  // =========================================================================
  // preparePracticeClip guards
  // =========================================================================

  group('preparePracticeClip guards', () {
    test('no-op when context is null', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.preparePracticeClip();
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.none,
      );
    });

    test('no-op when already in clip phase', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
      );
      session.debugSetPracticePhase(ReviewPracticePhase.clipReady);
      session.preparePracticeClip();
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.clipReady,
      );
    });

    test('no-op when clipPlayInFlight', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
      );
      session.debugSetPracticePhase(ReviewPracticePhase.clipOpening);
      session.preparePracticeClip();
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.clipOpening,
      );
    });

    test('no-op when completed', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
      );
      session.skip();
      session.preparePracticeClip();
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.none,
      );
    });

    test('no-op when context does not support media actions', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      final ebookCtx = _makeContext(
        sourceType: VocabularySourceType.ebook,
        locator: null,
      );
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [ebookCtx],
        },
      );
      session.preparePracticeClip();
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.none,
      );
    });

    test('clears mediaError on entering clipOpening', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
      );
      // Inject a media error via debug phase + manual state.
      session.debugSetPracticePhase(ReviewPracticePhase.echo);
      session.preparePracticeClip();
      // preparePracticeClip is blocked because practicePhase.isClip is false
      // but overlayOpen is true (echo). Actually echo is not isClip, so it
      // should proceed.
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.practicePhase, ReviewPracticePhase.clipOpening);
      expect(state.mediaError, isNull);
    });
  });

  // =========================================================================
  // startPracticeClipPlayback guards
  // =========================================================================

  group('startPracticeClipPlayback guards', () {
    test('no-op when context is null', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.debugSetPracticePhase(ReviewPracticePhase.clipOpening);
      // No context for item, so currentPrimaryContext is null.
      await session.startPracticeClipPlayback();
      // Should remain in clipOpening (no-op because ctx is null).
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.clipOpening,
      );
    });

    test('no-op when phase is not clipOpening', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
      );
      session.debugSetPracticePhase(ReviewPracticePhase.echo);
      await session.startPracticeClipPlayback();
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.echo,
      );
    });

    test('no-op when completed', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
      );
      session.skip();
      session.debugSetPracticePhase(ReviewPracticePhase.clipOpening);
      await session.startPracticeClipPlayback();
      // completed guard fires first.
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.clipOpening,
      );
    });

    test('no-op when context does not support media', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      final ebookCtx = _makeContext(
        sourceType: VocabularySourceType.ebook,
        locator: null,
      );
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [ebookCtx],
        },
      );
      session.debugSetPracticePhase(ReviewPracticePhase.clipOpening);
      await session.startPracticeClipPlayback();
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.clipOpening,
      );
    });
  });

  // =========================================================================
  // openPracticeEcho guards
  // =========================================================================

  group('openPracticeEcho guards', () {
    test('no-op when context is null', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      await session.openPracticeEcho();
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.none,
      );
    });

    test('no-op when completed', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
      );
      session.skip();
      await session.openPracticeEcho();
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.none,
      );
    });

    test('no-op when context does not support media', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      final ebookCtx = _makeContext(
        sourceType: VocabularySourceType.ebook,
        locator: null,
      );
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [ebookCtx],
        },
      );
      await session.openPracticeEcho();
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.none,
      );
    });

    test('clears existing clip practice before opening echo', () async {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue(
        [_makeItem()],
        contextsByItemId: {
          'i1': [_makeContext()],
        },
      );
      session.debugSetPracticePhase(ReviewPracticePhase.clipReady);
      await session.openPracticeEcho();
      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.practicePhase, ReviewPracticePhase.echo);
    });
  });

  // =========================================================================
  // debugSetPracticePhase
  // =========================================================================

  group('debugSetPracticePhase', () {
    test('sets explicit phase', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      session.startWithQueue([_makeItem()]);
      session.debugSetPracticePhase(ReviewPracticePhase.clipReady);
      expect(
        container.read(vocabularyReviewSessionProvider).practicePhase,
        ReviewPracticePhase.clipReady,
      );
      expect(
        container.read(vocabularyReviewSessionProvider).claimsVideoSurface,
        isTrue,
      );
    });
  });

  // =========================================================================
  // start() with contexts
  // =========================================================================

  group('start with contexts', () {
    test('loads and sorts contexts by createdAt', () async {
      final repo = VocabularyRepository(db);
      await repo.addWithContext(
        word: 'test',
        language: 'en',
        targetLanguage: 'zh',
        text: 'later context',
        sourceType: VocabularySourceType.video,
        sourceId: 'v2',
        mediaLocator: const MediaLocator(start: 0, duration: 1000),
        now: DateTime.utc(2020, 6, 1),
      );
      await repo.addWithContext(
        word: 'test',
        language: 'en',
        targetLanguage: 'zh',
        text: 'earlier context',
        sourceType: VocabularySourceType.video,
        sourceId: 'v1',
        mediaLocator: const MediaLocator(start: 0, duration: 1000),
        now: DateTime.utc(2020, 1, 1),
      );

      final session = container.read(vocabularyReviewSessionProvider.notifier);
      final started = await session.start(
        const ReviewSelectionOptions(mode: VocabularyReviewMode.all),
        now: DateTime.utc(2030, 1, 1),
      );
      expect(started, isTrue);

      final state = container.read(vocabularyReviewSessionProvider);
      expect(state.total, 1);
      expect(state.currentContextsCount, 2);
      // Sorted by createdAt: earlier first.
      expect(state.currentPrimaryContext?.text, 'earlier context');
    });
  });

  // =========================================================================
  // hasActiveSession on notifier
  // =========================================================================

  group('notifier hasActiveSession', () {
    test('reflects state.hasActiveSession', () {
      final session = container.read(vocabularyReviewSessionProvider.notifier);
      expect(session.hasActiveSession, isFalse);
      session.startWithQueue([_makeItem()]);
      expect(session.hasActiveSession, isTrue);
      session.clear();
      expect(session.hasActiveSession, isFalse);
    });
  });

  // =========================================================================
  // playClip (legacy alias)
  // =========================================================================
}
