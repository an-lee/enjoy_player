/// Ephemeral flashcard review session state for Vocabulary.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/ai/application/ai_services.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_providers.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_media.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_explanation_codec.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_review_practice.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_session_selection.dart';

final _log = logNamed('VocabularyReviewSession');

/// One step in the session navigation history (for ← previous).
final class ReviewHistoryEntry {
  const ReviewHistoryEntry({required this.itemId, required this.wasRated});

  final String itemId;
  final bool wasRated;
}

/// Mutable UI state for an active review run.
final class ReviewSessionState {
  const ReviewSessionState({
    required this.queue,
    this.index = 0,
    this.flipped = false,
    this.ratingInFlight = false,
    this.dictionaryFetchInFlight = false,
    this.contextualFetchInFlight = false,
    this.dictionaryError,
    this.contextualError,
    this.mediaError,
    this.ratedStack = const [],
    this.history = const [],
    this.completed = false,
    this.contextsByItemId = const {},
    this.activeContextIndexByItemId = const {},
    this.practicePhase = ReviewPracticePhase.none,
  });

  final List<VocabularyItem> queue;
  final int index;
  final bool flipped;
  final bool ratingInFlight;
  final bool dictionaryFetchInFlight;
  final bool contextualFetchInFlight;
  final String? dictionaryError;
  final String? contextualError;
  final String? mediaError;
  final List<String> ratedStack;
  final List<ReviewHistoryEntry> history;
  final bool completed;
  final Map<String, List<VocabularyContext>> contextsByItemId;
  final Map<String, int> activeContextIndexByItemId;
  final ReviewPracticePhase practicePhase;

  bool get hasActiveSession => queue.isNotEmpty;

  bool get canUndo => ratedStack.isNotEmpty && !ratingInFlight;

  ReviewPracticeMode get practiceMode => practicePhase.asMode;

  bool get practiceSheetOpen => practicePhase.overlayOpen;

  /// True while clip practice is open (suppress mini-bar).
  bool get practiceOwnsVideoStage => practicePhase.isClip;

  bool get clipPlayInFlight => practicePhase == ReviewPracticePhase.clipOpening;

  bool get claimsVideoSurface => practicePhase.claimsVideoSurface;

  VocabularyItem? get currentItem {
    if (completed || index < 0 || index >= queue.length) return null;
    return queue[index];
  }

  /// Active context for the current card (earliest by default; pager may change).
  VocabularyContext? get currentPrimaryContext {
    final item = currentItem;
    if (item == null) return null;
    return primaryContextFor(item.id);
  }

  List<VocabularyContext> contextsFor(String itemId) =>
      contextsByItemId[itemId] ?? const [];

  int activeContextIndexFor(String itemId) {
    final list = contextsFor(itemId);
    if (list.isEmpty) return 0;
    final raw = activeContextIndexByItemId[itemId] ?? 0;
    if (raw < 0) return 0;
    if (raw >= list.length) return list.length - 1;
    return raw;
  }

  int get currentContextsCount {
    final item = currentItem;
    if (item == null) return 0;
    return contextsFor(item.id).length;
  }

  int get currentActiveContextIndex {
    final item = currentItem;
    if (item == null) return 0;
    return activeContextIndexFor(item.id);
  }

  int get total => queue.length;

  int get displayCurrent => completed ? total : (index + 1).clamp(1, total);

  /// Cards left after the current one (0 when complete or on the last card).
  int get remaining => completed ? 0 : (total - displayCurrent).clamp(0, total);

  VocabularyContext? primaryContextFor(String itemId) {
    final list = contextsFor(itemId);
    if (list.isEmpty) return null;
    return list[activeContextIndexFor(itemId)];
  }

  ReviewSessionState copyWith({
    List<VocabularyItem>? queue,
    int? index,
    bool? flipped,
    bool? ratingInFlight,
    bool? dictionaryFetchInFlight,
    bool? contextualFetchInFlight,
    String? dictionaryError,
    bool clearDictionaryError = false,
    String? contextualError,
    bool clearContextualError = false,
    String? mediaError,
    bool clearMediaError = false,
    List<String>? ratedStack,
    List<ReviewHistoryEntry>? history,
    bool? completed,
    Map<String, List<VocabularyContext>>? contextsByItemId,
    Map<String, int>? activeContextIndexByItemId,
    ReviewPracticePhase? practicePhase,
  }) {
    return ReviewSessionState(
      queue: queue ?? this.queue,
      index: index ?? this.index,
      flipped: flipped ?? this.flipped,
      ratingInFlight: ratingInFlight ?? this.ratingInFlight,
      dictionaryFetchInFlight:
          dictionaryFetchInFlight ?? this.dictionaryFetchInFlight,
      contextualFetchInFlight:
          contextualFetchInFlight ?? this.contextualFetchInFlight,
      dictionaryError: clearDictionaryError
          ? null
          : (dictionaryError ?? this.dictionaryError),
      contextualError: clearContextualError
          ? null
          : (contextualError ?? this.contextualError),
      mediaError: clearMediaError ? null : (mediaError ?? this.mediaError),
      ratedStack: ratedStack ?? this.ratedStack,
      history: history ?? this.history,
      completed: completed ?? this.completed,
      contextsByItemId: contextsByItemId ?? this.contextsByItemId,
      activeContextIndexByItemId:
          activeContextIndexByItemId ?? this.activeContextIndexByItemId,
      practicePhase: practicePhase ?? this.practicePhase,
    );
  }
}

final vocabularyReviewSessionProvider =
    NotifierProvider<VocabularyReviewSession, ReviewSessionState>(
      VocabularyReviewSession.new,
    );

class VocabularyReviewSession extends Notifier<ReviewSessionState> {
  @override
  ReviewSessionState build() => const ReviewSessionState(queue: []);

  /// Whether a review queue is currently loaded (safe to read outside [build]).
  bool get hasActiveSession => state.hasActiveSession;

  /// Start a session from [options] against current book items.
  ///
  /// Returns `false` when the built queue is empty (caller shows a message).
  Future<bool> start(ReviewSelectionOptions options, {DateTime? now}) async {
    final repo = ref.read(vocabularyRepositoryProvider);
    final items = await repo.listAll();
    final queue = buildVocabularySessionQueue(
      items: items,
      options: options,
      now: now ?? DateTime.now(),
    );
    if (queue.isEmpty) {
      state = const ReviewSessionState(queue: []);
      return false;
    }

    final contextsByItemId = <String, List<VocabularyContext>>{};
    final activeIndex = <String, int>{};
    for (final item in queue) {
      final list = await repo.getContextsForItem(item.id);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      contextsByItemId[item.id] = list;
      activeIndex[item.id] = 0;
    }

    state = ReviewSessionState(
      queue: List<VocabularyItem>.from(queue),
      contextsByItemId: contextsByItemId,
      activeContextIndexByItemId: activeIndex,
    );
    return true;
  }

  /// Restore a previously built non-empty queue (tests / deep links).
  void startWithQueue(
    List<VocabularyItem> queue, {
    Map<String, List<VocabularyContext>> contextsByItemId = const {},
    Map<String, int> activeContextIndexByItemId = const {},
    Map<String, VocabularyContext> primaryContextByItemId = const {},
  }) {
    if (queue.isEmpty) {
      state = const ReviewSessionState(queue: []);
      return;
    }

    var contexts = Map<String, List<VocabularyContext>>.from(contextsByItemId);
    var indices = Map<String, int>.from(activeContextIndexByItemId);
    if (contexts.isEmpty && primaryContextByItemId.isNotEmpty) {
      for (final e in primaryContextByItemId.entries) {
        contexts[e.key] = [e.value];
        indices[e.key] = 0;
      }
    }

    state = ReviewSessionState(
      queue: List<VocabularyItem>.from(queue),
      contextsByItemId: contexts,
      activeContextIndexByItemId: indices,
    );
  }

  void clear() {
    final hadPractice = state.practiceSheetOpen;
    state = const ReviewSessionState(queue: []);
    if (hadPractice) {
      ref.read(echoModeProvider.notifier).deactivate();
      try {
        unawaited(
          ref.read(playerControllerProvider.notifier).activeEngine.pause(),
        );
      } catch (_) {}
    }
  }

  /// Pauses lesson media, clears the playback session, and closes practice UI.
  ///
  /// Does **not** clear the review queue — the flashcard stays mounted.
  Future<void> clearPractice() async {
    if (state.practicePhase == ReviewPracticePhase.none) return;
    final wasClip = state.practicePhase.isClip;
    ref.read(echoModeProvider.notifier).deactivate();
    if (wasClip) {
      final player = ref.read(playerControllerProvider.notifier);
      final hasSession = ref.read(playerControllerProvider) != null;
      if (hasSession) {
        try {
          await player.activeEngine.pause();
        } catch (_) {
          // Best-effort pause when the engine is not ready.
        }
        // Drop the playback session so the mini-bar does not appear after dismiss.
        try {
          await player.clear(keepVideoSurface: true);
        } catch (_) {}
      }
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      practicePhase: ReviewPracticePhase.none,
      clearMediaError: true,
    );
  }

  /// Selects the active context index for the current item (clamped; no wrap).
  Future<void> selectContext(int index) async {
    final item = state.currentItem;
    if (item == null || state.completed) return;
    final list = state.contextsFor(item.id);
    if (list.isEmpty) return;
    final clamped = index.clamp(0, list.length - 1);
    if (state.practiceSheetOpen) {
      await clearPractice();
    }
    final indices = Map<String, int>.from(state.activeContextIndexByItemId);
    indices[item.id] = clamped;
    state = state.copyWith(
      activeContextIndexByItemId: indices,
      clearMediaError: true,
    );
  }

  Future<void> selectPreviousContext() async {
    final item = state.currentItem;
    if (item == null) return;
    final i = state.activeContextIndexFor(item.id);
    if (i <= 0) return;
    await selectContext(i - 1);
  }

  Future<void> selectNextContext() async {
    final item = state.currentItem;
    if (item == null) return;
    final list = state.contextsFor(item.id);
    final i = state.activeContextIndexFor(item.id);
    if (i >= list.length - 1) return;
    await selectContext(i + 1);
  }

  void flip() {
    final item = state.currentItem;
    if (item == null ||
        state.completed ||
        state.ratingInFlight ||
        state.practiceSheetOpen) {
      return;
    }
    state = state.copyWith(flipped: true);
  }

  void unflip() {
    final item = state.currentItem;
    if (item == null ||
        state.completed ||
        state.ratingInFlight ||
        !state.flipped ||
        state.practiceSheetOpen) {
      return;
    }
    state = state.copyWith(flipped: false);
  }

  void toggleFlip() {
    if (state.flipped) {
      unflip();
    } else {
      flip();
    }
  }

  Future<void> rate(VocabularyRating rating) async {
    final item = state.currentItem;
    if (item == null ||
        !state.flipped ||
        state.ratingInFlight ||
        state.completed ||
        state.practiceSheetOpen) {
      return;
    }

    state = state.copyWith(ratingInFlight: true);
    try {
      final repo = ref.read(vocabularyRepositoryProvider);
      final updated = await repo.markReviewed(itemId: item.id, rating: rating);
      final queue = List<VocabularyItem>.from(state.queue);
      if (updated != null) {
        queue[state.index] = updated;
      }
      final ratedStack = [...state.ratedStack, item.id];
      final history = [
        ...state.history,
        ReviewHistoryEntry(itemId: item.id, wasRated: true),
      ];
      final nextIndex = state.index + 1;
      if (nextIndex >= queue.length) {
        state = state.copyWith(
          queue: queue,
          ratedStack: ratedStack,
          history: history,
          ratingInFlight: false,
          completed: true,
          flipped: false,
          index: queue.length,
          practicePhase: ReviewPracticePhase.none,
        );
      } else {
        state = state.copyWith(
          queue: queue,
          index: nextIndex,
          flipped: false,
          ratingInFlight: false,
          ratedStack: ratedStack,
          history: history,
          practicePhase: ReviewPracticePhase.none,
        );
      }
    } catch (_) {
      state = state.copyWith(ratingInFlight: false);
      rethrow;
    }
  }

  void skip() {
    final item = state.currentItem;
    if (item == null ||
        state.ratingInFlight ||
        state.completed ||
        state.practiceSheetOpen) {
      return;
    }
    final history = [
      ...state.history,
      ReviewHistoryEntry(itemId: item.id, wasRated: false),
    ];
    final nextIndex = state.index + 1;
    if (nextIndex >= state.queue.length) {
      state = state.copyWith(
        history: history,
        completed: true,
        flipped: false,
        index: state.queue.length,
        practicePhase: ReviewPracticePhase.none,
      );
    } else {
      state = state.copyWith(
        index: nextIndex,
        flipped: false,
        history: history,
        practicePhase: ReviewPracticePhase.none,
      );
    }
  }

  Future<void> undo() async {
    if (!state.canUndo || state.practiceSheetOpen) return;
    final itemId = state.ratedStack.last;
    state = state.copyWith(ratingInFlight: true);
    try {
      final repo = ref.read(vocabularyRepositoryProvider);
      final restored = await repo.undoLatestReview(itemId);
      final queue = List<VocabularyItem>.from(state.queue);
      final idx = queue.indexWhere((i) => i.id == itemId);
      if (restored != null && idx >= 0) {
        queue[idx] = restored;
      }
      final ratedStack = List<String>.from(state.ratedStack)..removeLast();
      final history = List<ReviewHistoryEntry>.from(state.history);
      while (history.isNotEmpty) {
        final last = history.removeLast();
        if (last.itemId == itemId && last.wasRated) break;
      }
      final restoreIndex = idx >= 0 ? idx : state.index;
      state = state.copyWith(
        queue: queue,
        index: restoreIndex,
        flipped: false,
        ratingInFlight: false,
        ratedStack: ratedStack,
        history: history,
        completed: false,
      );
    } catch (_) {
      state = state.copyWith(ratingInFlight: false);
      rethrow;
    }
  }

  void previous() {
    if (state.history.isEmpty ||
        state.ratingInFlight ||
        state.practiceSheetOpen) {
      return;
    }
    final history = List<ReviewHistoryEntry>.from(state.history);
    final last = history.removeLast();
    final idx = state.queue.indexWhere((i) => i.id == last.itemId);
    if (idx < 0) {
      state = state.copyWith(history: history);
      return;
    }
    state = state.copyWith(
      history: history,
      index: idx,
      flipped: false,
      completed: false,
      practicePhase: ReviewPracticePhase.none,
    );
  }

  Future<void> fetchDictionary() async {
    final item = state.currentItem;
    if (item == null ||
        state.dictionaryFetchInFlight ||
        state.completed ||
        state.practiceSheetOpen) {
      return;
    }
    state = state.copyWith(
      dictionaryFetchInFlight: true,
      clearDictionaryError: true,
    );
    try {
      final result = await ref
          .read(dictionaryServiceProvider)
          .lookup(
            word: item.word,
            sourceLanguage: item.language,
            targetLanguage: item.targetLanguage,
          );
      final json = encodeDictionaryExplanation(result);
      final updated = await ref
          .read(vocabularyRepositoryProvider)
          .updateItemExplanation(itemId: item.id, explanation: json);
      if (updated == null) {
        state = state.copyWith(
          dictionaryFetchInFlight: false,
          dictionaryError: 'persist_failed',
        );
        return;
      }
      final queue = List<VocabularyItem>.from(state.queue);
      final idx = queue.indexWhere((i) => i.id == item.id);
      if (idx >= 0) queue[idx] = updated;
      state = state.copyWith(
        queue: queue,
        dictionaryFetchInFlight: false,
        clearDictionaryError: true,
      );
    } on CreditsFailure catch (failure, st) {
      _log.warning('Dictionary fetch rejected: credits', failure, st);
      state = state.copyWith(
        dictionaryFetchInFlight: false,
        dictionaryError: 'credits',
      );
    } catch (e, st) {
      _log.warning('Dictionary fetch failed', e, st);
      state = state.copyWith(
        dictionaryFetchInFlight: false,
        dictionaryError: 'fetch_failed',
      );
    }
  }

  Future<void> fetchContextualTranslation() async {
    final item = state.currentItem;
    final ctx = state.currentPrimaryContext;
    if (item == null ||
        ctx == null ||
        state.contextualFetchInFlight ||
        state.completed ||
        state.practiceSheetOpen) {
      return;
    }
    state = state.copyWith(
      contextualFetchInFlight: true,
      clearContextualError: true,
    );
    try {
      final result = await ref
          .read(contextualTranslationServiceProvider)
          .translate(
            text: ctx.text,
            sourceLanguage: item.language,
            targetLanguage: item.targetLanguage,
            context: item.word,
          );
      final json = encodeContextualExplanation(result);
      final updated = await ref
          .read(vocabularyRepositoryProvider)
          .updateContextExplanation(contextId: ctx.id, explanation: json);
      if (updated == null) {
        state = state.copyWith(
          contextualFetchInFlight: false,
          contextualError: 'persist_failed',
        );
        return;
      }
      final contexts = Map<String, List<VocabularyContext>>.from(
        state.contextsByItemId,
      );
      final list = List<VocabularyContext>.from(contexts[item.id] ?? const []);
      final i = list.indexWhere((c) => c.id == updated.id);
      if (i >= 0) {
        list[i] = updated;
      }
      contexts[item.id] = list;
      state = state.copyWith(
        contextsByItemId: contexts,
        contextualFetchInFlight: false,
        clearContextualError: true,
      );
    } on CreditsFailure catch (failure, st) {
      _log.warning('Contextual translation rejected: credits', failure, st);
      state = state.copyWith(
        contextualFetchInFlight: false,
        contextualError: 'credits',
      );
    } catch (e, st) {
      _log.warning('Contextual translation fetch failed', e, st);
      state = state.copyWith(
        contextualFetchInFlight: false,
        contextualError: 'fetch_failed',
      );
    }
  }

  /// Shows clip practice overlay in the opening phase (no surface claim yet).
  void preparePracticeClip() {
    final ctx = state.currentPrimaryContext;
    if (ctx == null ||
        state.clipPlayInFlight ||
        state.completed ||
        state.practicePhase.isClip ||
        !vocabularyContextSupportsMediaActions(ctx)) {
      return;
    }
    state = state.copyWith(
      practicePhase: ReviewPracticePhase.clipOpening,
      clearMediaError: true,
    );
  }

  /// Opens media on the permanent surface, seeks the clip window, then plays.
  Future<void> startPracticeClipPlayback() async {
    final ctx = state.currentPrimaryContext;
    if (ctx == null ||
        state.completed ||
        state.practicePhase != ReviewPracticePhase.clipOpening ||
        !vocabularyContextSupportsMediaActions(ctx)) {
      return;
    }
    try {
      await playVocabularyClip(
        player: ref.read(playerControllerProvider.notifier),
        echo: ref.read(echoModeProvider.notifier),
        context: ctx,
      );
      if (ref.mounted &&
          state.practicePhase == ReviewPracticePhase.clipOpening) {
        state = state.copyWith(practicePhase: ReviewPracticePhase.clipReady);
      }
    } catch (e, st) {
      _log.warning('Clip play failed', e, st);
      if (ref.mounted) {
        state = state.copyWith(
          practicePhase: ReviewPracticePhase.none,
          mediaError: 'play_failed',
        );
        try {
          await ref
              .read(playerControllerProvider.notifier)
              .clear(keepVideoSurface: true);
        } catch (_) {}
      }
    }
  }

  /// Opens clip practice (sets opening phase then plays).
  Future<void> openPracticeClip() async {
    preparePracticeClip();
    await startPracticeClipPlayback();
  }

  /// Opens echo practice as a recorder-only overlay (no player session).
  Future<void> openPracticeEcho() async {
    final ctx = state.currentPrimaryContext;
    if (ctx == null ||
        state.completed ||
        !vocabularyContextSupportsMediaActions(ctx)) {
      return;
    }
    if (state.practicePhase.isClip) {
      await clearPractice();
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      practicePhase: ReviewPracticePhase.echo,
      clearMediaError: true,
    );
  }

  /// Legacy name — opens clip practice (overlay host owns chrome).
  Future<void> playClip() => openPracticeClip();

  /// Test helper to simulate an open practice sheet without media APIs.
  @visibleForTesting
  void debugSetPracticeMode(ReviewPracticeMode mode) {
    state = state.copyWith(practicePhase: mode.toPhase());
  }

  /// Test helper for explicit practice phases.
  @visibleForTesting
  void debugSetPracticePhase(ReviewPracticePhase phase) {
    state = state.copyWith(practicePhase: phase);
  }
}
