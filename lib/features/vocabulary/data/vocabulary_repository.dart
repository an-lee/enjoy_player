/// Local vocabulary repository (Drift DAOs + SRS) with optional cloud sync
/// enqueue (ADR-0054). Review audits are never enqueued.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:enjoy_player/core/ids/enjoy_ids.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/sync/domain/sync_types.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_cta_state.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_locator_json.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_normalize.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_srs.dart';

class VocabularyRepository {
  VocabularyRepository(this._db, {this.enqueueSync});

  final AppDatabase _db;

  /// Optional cloud sync enqueue (ADR-0054). Null in unit tests.
  final SyncEnqueueFn? enqueueSync;

  // ignore: prefer_const_constructors — Uuid() has no const constructor
  static final Uuid _uuid = Uuid();

  Future<AddVocabularyResult> addWithContext({
    required String word,
    required String language,
    required String targetLanguage,
    required String text,
    required VocabularySourceType sourceType,
    required String sourceId,
    MediaLocator? mediaLocator,
    EbookLocator? ebookLocator,
    DateTime? now,
  }) async {
    if (mediaLocator == null && ebookLocator == null) {
      throw ArgumentError('mediaLocator or ebookLocator is required');
    }
    final at = now ?? DateTime.now();
    final normalized = normalizeWord(word);

    return _db.transaction(() async {
      final existing = await _db.vocabularyItemDao.getByWordLanguageTarget(
        word: normalized,
        language: language,
        targetLanguage: targetLanguage,
      );

      late VocabularyItem item;
      final isNewItem = existing == null;

      if (isNewItem) {
        final id = enjoyVocabularyItemId(
          normalizedWord: normalized,
          language: language,
          targetLanguage: targetLanguage,
        );
        final row = VocabularyItemRow(
          id: id,
          word: normalized,
          language: language,
          targetLanguage: targetLanguage,
          status: VocabularyStatus.new_.wire,
          easeFactor: kDefaultEaseFactor,
          interval: 0,
          nextReviewAt: newItemNextReviewAt(at),
          reviewsCount: 0,
          lastReviewedAt: null,
          contextsCount: 1,
          explanation: null,
          syncStatus: 'local',
          serverUpdatedAt: null,
          createdAt: at,
          updatedAt: at,
        );
        await _db.vocabularyItemDao.insertRow(row);
        await enqueueSync?.call(
          SyncEntityType.vocabularyItem,
          id,
          SyncAction.create,
        );
        item = _itemFromRow(row);
      } else {
        item = _itemFromRow(existing);
      }

      final existingContexts = await _db.vocabularyContextDao
          .getByItemAndSource(
            vocabularyItemId: item.id,
            sourceType: sourceType.wire,
            sourceId: sourceId,
          );

      final duplicate = _findDuplicateContext(
        existingContexts,
        mediaLocator: mediaLocator,
        ebookLocator: ebookLocator,
      );
      if (duplicate != null) {
        return AddVocabularyResult(
          item: item,
          context: _contextFromRow(duplicate),
          isNewContext: false,
        );
      }

      final locatorJson = encodeLocatorForDb(
        media: mediaLocator,
        ebook: ebookLocator,
      );
      final stableJson = mediaLocator != null
          ? stableLocatorJson(mediaLocator)
          : stableEbookLocatorJson(ebookLocator!);
      final contextId = enjoyVocabularyContextId(
        vocabularyItemId: item.id,
        sourceType: sourceType.wire,
        sourceId: sourceId,
        text: text,
        stableLocatorJson: stableJson,
      );
      final contextRow = VocabularyContextRow(
        id: contextId,
        vocabularyItemId: item.id,
        contextText: text,
        sourceType: sourceType.wire,
        sourceId: sourceId,
        locatorJson: locatorJson,
        explanation: null,
        syncStatus: 'local',
        serverUpdatedAt: null,
        createdAt: at,
        updatedAt: at,
      );
      await _db.vocabularyContextDao.insertRow(contextRow);
      await enqueueSync?.call(
        SyncEntityType.vocabularyContext,
        contextId,
        SyncAction.create,
      );

      if (!isNewItem) {
        final fresh = await _db.vocabularyItemDao.getById(item.id);
        if (fresh != null) {
          final updated = fresh.copyWith(
            contextsCount: fresh.contextsCount + 1,
            updatedAt: at,
          );
          await _db.vocabularyItemDao.updateRow(updated);
          await enqueueSync?.call(
            SyncEntityType.vocabularyItem,
            item.id,
            SyncAction.update,
          );
          item = _itemFromRow(updated);
        }
      }

      return AddVocabularyResult(
        item: item,
        context: _contextFromRow(contextRow),
        isNewContext: true,
      );
    });
  }

  Future<void> deleteItem(String id) async {
    await _db.transaction(() async {
      // Local cascade first; review audits never sync, and the server is
      // expected to cascade its own contexts on item delete (ADR-0054).
      await _db.vocabularyReviewDao.deleteByItemId(id);
      await _db.vocabularyContextDao.deleteByItemId(id);
      await _db.vocabularyItemDao.deleteById(id);
      await enqueueSync?.call(
        SyncEntityType.vocabularyItem,
        id,
        SyncAction.delete,
      );
    });
  }

  Future<VocabularyItem?> markReviewed({
    required String itemId,
    required VocabularyRating rating,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    return _db.transaction(() async {
      final row = await _db.vocabularyItemDao.getById(itemId);
      if (row == null) return null;

      final updates = calculateNextReview(
        easeFactor: row.easeFactor,
        interval: row.interval,
        reviewsCount: row.reviewsCount,
        status: VocabularyStatus.fromWire(row.status),
        rating: rating,
        now: at,
      );

      final reviewRow = VocabularyReviewRow(
        id: _uuid.v4(),
        vocabularyItemId: itemId,
        rating: rating.value,
        at: at,
        easeFactorBefore: row.easeFactor,
        intervalBefore: row.interval,
        statusBefore: row.status,
        reviewsCountBefore: row.reviewsCount,
        nextReviewAtBefore: row.nextReviewAt,
        lastReviewedAtBefore: row.lastReviewedAt,
        syncStatus: 'local',
        createdAt: at,
        updatedAt: at,
      );
      await _db.vocabularyReviewDao.insertRow(reviewRow);

      final updated = row.copyWith(
        status: updates.status.wire,
        easeFactor: updates.easeFactor,
        interval: updates.interval,
        nextReviewAt: updates.nextReviewAt,
        reviewsCount: updates.reviewsCount,
        lastReviewedAt: Value(updates.lastReviewedAt),
        updatedAt: at,
      );
      await _db.vocabularyItemDao.updateRow(updated);
      // Review audits (`vocabularyReviewDao`) are device-local undo history
      // only and are never enqueued — only the resulting item update syncs.
      await enqueueSync?.call(
        SyncEntityType.vocabularyItem,
        itemId,
        SyncAction.update,
      );
      return _itemFromRow(updated);
    });
  }

  /// Restores the pre-image from the latest audit row for [itemId].
  ///
  /// Returns the restored item, or `null` if there was nothing to undo.
  Future<VocabularyItem?> undoLatestReview(String itemId) async {
    return _db.transaction(() async {
      final review = await _db.vocabularyReviewDao.latestForItem(itemId);
      if (review == null) return null;

      final row = await _db.vocabularyItemDao.getById(itemId);
      if (row == null) {
        await _db.vocabularyReviewDao.deleteById(review.id);
        return null;
      }

      final restoredRow = row.copyWith(
        easeFactor: review.easeFactorBefore,
        interval: review.intervalBefore,
        status: review.statusBefore,
        reviewsCount: review.reviewsCountBefore,
        nextReviewAt: review.nextReviewAtBefore,
        lastReviewedAt: Value(review.lastReviewedAtBefore),
        updatedAt: DateTime.now(),
      );
      await _db.vocabularyItemDao.updateRow(restoredRow);
      await _db.vocabularyReviewDao.deleteById(review.id);
      await enqueueSync?.call(
        SyncEntityType.vocabularyItem,
        itemId,
        SyncAction.update,
      );
      return _itemFromRow(restoredRow);
    });
  }

  Future<VocabularyItem?> getItem(String id) async {
    final row = await _db.vocabularyItemDao.getById(id);
    return row == null ? null : _itemFromRow(row);
  }

  /// Persists dictionary JSON on the item. Does not change SRS fields.
  Future<VocabularyItem?> updateItemExplanation({
    required String itemId,
    required String? explanation,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final row = await _db.vocabularyItemDao.getById(itemId);
    if (row == null) return null;
    final updated = row.copyWith(
      explanation: Value(explanation),
      updatedAt: at,
    );
    await _db.vocabularyItemDao.updateRow(updated);
    await enqueueSync?.call(
      SyncEntityType.vocabularyItem,
      itemId,
      SyncAction.update,
    );
    return _itemFromRow(updated);
  }

  /// Persists contextual-translation JSON on one context. Sibling contexts unchanged.
  Future<VocabularyContext?> updateContextExplanation({
    required String contextId,
    required String? explanation,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final row = await _db.vocabularyContextDao.getById(contextId);
    if (row == null) return null;
    final updated = row.copyWith(
      explanation: Value(explanation),
      updatedAt: at,
    );
    await _db.vocabularyContextDao.updateRow(updated);
    await enqueueSync?.call(
      SyncEntityType.vocabularyContext,
      contextId,
      SyncAction.update,
    );
    return _contextFromRow(updated);
  }

  Future<VocabularyItem?> findByWord({
    required String word,
    required String language,
    required String targetLanguage,
  }) async {
    final row = await _db.vocabularyItemDao.getByWordLanguageTarget(
      word: normalizeWord(word),
      language: language,
      targetLanguage: targetLanguage,
    );
    return row == null ? null : _itemFromRow(row);
  }

  Future<List<VocabularyContext>> getContextsForItem(String itemId) async {
    final rows = await _db.vocabularyContextDao.getByItemId(itemId);
    return rows.map(_contextFromRow).toList();
  }

  Future<List<VocabularyItem>> listDue({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final rows = await _db.vocabularyItemDao.listDue(at);
    return rows.map(_itemFromRow).toList();
  }

  Future<List<VocabularyItem>> listAll() async {
    final rows = await _db.vocabularyItemDao.listAll();
    return rows.map(_itemFromRow).toList();
  }

  /// Items + contexts for Anki export (caller applies filters).
  ///
  /// Contexts are fetched in a single `WHERE vocabulary_item_id IN (…)`
  /// query instead of one query per item (issue #468).
  Future<
    ({
      List<VocabularyItem> items,
      Map<String, List<VocabularyContext>> contextsByItemId,
    })
  >
  loadExportBundle() async {
    final items = await listAll();
    final allContexts = await _db.vocabularyContextDao.getByItemIds(
      items.map((e) => e.id),
    );
    final contextsByItemId = <String, List<VocabularyContext>>{};
    for (final row in allContexts) {
      final ctx = _contextFromRow(row);
      (contextsByItemId[row.vocabularyItemId] ??= []).add(ctx);
    }
    return (items: items, contextsByItemId: contextsByItemId);
  }

  Stream<List<VocabularyItem>> watchAll() => _db.vocabularyItemDao
      .watchAll()
      .map((rows) => rows.map(_itemFromRow).toList());

  /// Resolves lookup CTA kind for [word] + language pair + media locator.
  Future<({VocabularyCtaKind kind, VocabularyItem? item})> resolveCtaState({
    required String word,
    required String language,
    required String targetLanguage,
    required VocabularySourceType sourceType,
    required String sourceId,
    required MediaLocator mediaLocator,
  }) async {
    final normalized = normalizeWord(word);
    if (normalized.isEmpty) {
      return (kind: VocabularyCtaKind.notInBook, item: null);
    }
    final item = await findByWord(
      word: normalized,
      language: language,
      targetLanguage: targetLanguage,
    );
    if (item == null) {
      return (kind: VocabularyCtaKind.notInBook, item: null);
    }
    final existing = await _db.vocabularyContextDao.getByItemAndSource(
      vocabularyItemId: item.id,
      sourceType: sourceType.wire,
      sourceId: sourceId,
    );
    final dup = _findDuplicateContext(existing, mediaLocator: mediaLocator);
    if (dup != null) {
      return (kind: VocabularyCtaKind.alreadyInVocabulary, item: item);
    }
    return (kind: VocabularyCtaKind.addContext, item: item);
  }

  VocabularyContextRow? _findDuplicateContext(
    List<VocabularyContextRow> existing, {
    MediaLocator? mediaLocator,
    EbookLocator? ebookLocator,
  }) {
    for (final ctx in existing) {
      final decoded = decodeLocatorFromDb(ctx.locatorJson);
      if (mediaLocator != null && decoded.media != null) {
        if (decoded.media!.start == mediaLocator.start &&
            decoded.media!.duration == mediaLocator.duration) {
          return ctx;
        }
      }
      if (ebookLocator != null && decoded.ebook != null) {
        if (stableEbookLocatorJson(decoded.ebook!) ==
            stableEbookLocatorJson(ebookLocator)) {
          return ctx;
        }
      }
    }
    return null;
  }

  VocabularyItem _itemFromRow(VocabularyItemRow row) => VocabularyItem(
    id: row.id,
    word: row.word,
    language: row.language,
    targetLanguage: row.targetLanguage,
    status: VocabularyStatus.fromWire(row.status),
    easeFactor: row.easeFactor,
    interval: row.interval,
    nextReviewAt: row.nextReviewAt,
    reviewsCount: row.reviewsCount,
    lastReviewedAt: row.lastReviewedAt,
    contextsCount: row.contextsCount,
    explanation: row.explanation,
    syncStatus: row.syncStatus,
    serverUpdatedAt: row.serverUpdatedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  VocabularyContext _contextFromRow(VocabularyContextRow row) {
    final decoded = decodeLocatorFromDb(row.locatorJson);
    return VocabularyContext(
      id: row.id,
      vocabularyItemId: row.vocabularyItemId,
      text: row.contextText,
      sourceType: VocabularySourceType.fromWire(row.sourceType),
      sourceId: row.sourceId,
      locator: decoded.media,
      ebookLocator: decoded.ebook,
      explanation: row.explanation,
      syncStatus: row.syncStatus,
      serverUpdatedAt: row.serverUpdatedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
