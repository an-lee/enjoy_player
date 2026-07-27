/// Coordinates download + upload queue processing.
library;

import 'dart:async';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/sync/data/sync_download_service.dart';
import 'package:enjoy_player/features/sync/data/sync_queue_repository.dart';
import 'package:enjoy_player/features/sync/data/sync_upload_service.dart';
import 'package:enjoy_player/features/sync/domain/sync_types.dart';

final _log = logNamed('sync');

const int _kMaxRetries = 5;
const int _kRetryBaseMs = 1000;

bool shouldRetryQueueItem(SyncQueueRow item) {
  if (item.retryCount >= _kMaxRetries) return false;
  if (item.lastAttempt == null) return true;
  final delayMs = _kRetryBaseMs * (1 << item.retryCount);
  final elapsed = DateTime.now().difference(item.lastAttempt!).inMilliseconds;
  return elapsed >= delayMs;
}

/// Prefer deletes before creates/updates for the same entity so a
/// delete-then-reimport cannot race cloud DELETE with POST.
int syncActionProcessOrder(String action) => switch (action) {
  'delete' => 0,
  'update' => 1,
  'create' => 2,
  _ => 3,
};

void sortSyncQueueWork(List<SyncQueueRow> work) {
  work.sort((a, b) {
    final typeCmp = a.entityType.compareTo(b.entityType);
    if (typeCmp != 0) return typeCmp;
    final idCmp = a.entityId.compareTo(b.entityId);
    if (idCmp != 0) return idCmp;
    final actionCmp = syncActionProcessOrder(
      a.action,
    ).compareTo(syncActionProcessOrder(b.action));
    if (actionCmp != 0) return actionCmp;
    return a.createdAt.compareTo(b.createdAt);
  });
}

class SyncEngine {
  SyncEngine({
    required this._db,
    required this._queue,
    required this._upload,
    required this._download,
  });

  final AppDatabase _db;
  final SyncQueueRepository _queue;
  final SyncUploadService _upload;
  final SyncDownloadService _download;

  Completer<SyncResult>? _drainGate;
  var _drainAgain = false;
  var _resetFailedPending = false;

  Future<SyncResult> fullSync(SyncOptions options) async {
    // Local-first: do not mirror remote audios/videos/recordings into the
    // library (ADR-0013). Vocabulary is an intentional exception — a
    // cross-device word book, not local-path media — so it pulls on every
    // signed-in sync alongside the outbound queue drain (ADR-0054).
    //
    // processQueue and pullVocabulary don't share state — run them
    // concurrently (issue #481).
    final results = await Future.wait([
      processQueue(options),
      pullVocabulary(),
    ]);
    return results[0].merge(results[1]);
  }

  /// Pulls vocabulary items + contexts (ADR-0054 auto-pull exception).
  ///
  /// Items + contexts are independent — fetched concurrently (issue #481).
  Future<SyncResult> pullVocabulary() async {
    final results = await Future.wait([
      _download.downloadVocabularyItems(),
      _download.downloadVocabularyContexts(),
    ]);
    return results[0].merge(results[1]);
  }

  /// Drains the outbound sync queue.
  ///
  /// Concurrent callers coalesce onto one in-flight drain (plus one follow-up
  /// pass if enqueue happened while draining).
  Future<SyncResult> processQueue(SyncOptions options) async {
    if (options.resetFailed) {
      _resetFailedPending = true;
    }

    final existing = _drainGate;
    if (existing != null) {
      _drainAgain = true;
      return existing.future;
    }

    final gate = Completer<SyncResult>();
    _drainGate = gate;

    try {
      SyncResult? last;
      do {
        _drainAgain = false;
        final resetFailed = _resetFailedPending;
        _resetFailedPending = false;
        last = await _drainOnce(SyncOptions(resetFailed: resetFailed));
      } while (_drainAgain);
      gate.complete(last);
      return last;
    } catch (e, st) {
      if (!gate.isCompleted) {
        gate.completeError(e, st);
      }
      rethrow;
    } finally {
      _drainGate = null;
    }
  }

  Future<SyncResult> _drainOnce(SyncOptions options) async {
    if (options.resetFailed) {
      final n = await _queue.resetFailed();
      if (n > 0) {
        _log.info('reset $n failed sync queue items');
      }
    }

    final pending = await _queue.pendingItems();
    final work = pending
        .where((row) => SyncEntityTypeWire.tryParse(row.entityType) != null)
        .where(shouldRetryQueueItem)
        .toList();
    sortSyncQueueWork(work);

    var synced = 0;
    var failed = 0;

    // Sequential: avoids parallel DELETE/POST for the same entityId when a
    // user deletes then re-imports the same local file (deterministic ids).
    for (final item in work) {
      final ok = await _processOne(item);
      if (ok) {
        synced++;
      } else {
        failed++;
      }
    }

    return SyncResult(success: failed == 0, synced: synced, failed: failed);
  }

  Future<bool> _processOne(SyncQueueRow item) async {
    final type = SyncEntityTypeWire.tryParse(item.entityType);
    final action = SyncActionWire.tryParse(item.action);
    if (type == null || action == null) {
      await _queue.removeById(item.id);
      return true;
    }

    try {
      if (action == SyncAction.delete) {
        switch (type) {
          case SyncEntityType.audio:
            await _upload.deleteAudio(item.entityId);
          case SyncEntityType.video:
            await _upload.deleteVideo(item.entityId);
          case SyncEntityType.recording:
            await _upload.deleteRecording(item.entityId);
          case SyncEntityType.youtubeSubscription:
            break; // subscription deletion is local-only
          case SyncEntityType.vocabularyItem:
            await _upload.deleteVocabularyItem(item.entityId);
          case SyncEntityType.vocabularyContext:
            await _upload.deleteVocabularyContext(item.entityId);
        }
        await _queue.removeById(item.id);
        return true;
      }

      switch (type) {
        case SyncEntityType.audio:
          final row = await _db.audioDao.getById(item.entityId);
          if (row == null) {
            _log.warning(
              'sync audio ${item.entityId}: missing locally, drop queue row',
            );
            await _queue.removeById(item.id);
            return true;
          }
          await _upload.uploadAudio(row);
        case SyncEntityType.video:
          final row = await _db.videoDao.getById(item.entityId);
          if (row == null) {
            _log.warning(
              'sync video ${item.entityId}: missing locally, drop queue row',
            );
            await _queue.removeById(item.id);
            return true;
          }
          await _upload.uploadVideo(row);
        case SyncEntityType.recording:
          final row = await _db.recordingDao.getById(item.entityId);
          if (row == null) {
            _log.warning(
              'sync recording ${item.entityId}: missing locally, drop queue row',
            );
            await _queue.removeById(item.id);
            return true;
          }
          await _upload.uploadRecording(row);
        case SyncEntityType.youtubeSubscription:
          // Subscription sync deferred — server API not yet ready.
          // Queue row is retained so it will sync when support is added.
          break;
        case SyncEntityType.vocabularyItem:
          final row = await _db.vocabularyItemDao.getById(item.entityId);
          if (row == null) {
            _log.warning(
              'sync vocabulary item ${item.entityId}: missing locally, drop queue row',
            );
            await _queue.removeById(item.id);
            return true;
          }
          await _upload.uploadVocabularyItem(row);
        case SyncEntityType.vocabularyContext:
          final row = await _db.vocabularyContextDao.getById(item.entityId);
          if (row == null) {
            _log.warning(
              'sync vocabulary context ${item.entityId}: missing locally, drop queue row',
            );
            await _queue.removeById(item.id);
            return true;
          }
          await _upload.uploadVocabularyContext(row);
      }

      await _queue.removeById(item.id);
      return true;
    } on SyncDuplicateMissingError catch (e, st) {
      _log.warning(
        'sync permanently failed ${item.entityType}:${item.entityId} '
        '${item.action} (duplicate create but GET 404)',
        e,
        st,
      );
      try {
        await _queue.markPermanentlyFailed(item.id, error: '$e');
      } catch (markError, markSt) {
        _log.warning(
          'sync markPermanentlyFailed failed for queue ${item.id}',
          markError,
          markSt,
        );
      }
      return false;
    } catch (e, st) {
      _log.warning(
        'sync failed ${item.entityType}:${item.entityId} ${item.action}',
        e,
        st,
      );
      try {
        await _queue.markAttempted(item.id, error: '$e');
      } catch (markError, markSt) {
        _log.warning(
          'sync markAttempted failed for queue ${item.id}',
          markError,
          markSt,
        );
      }
      return false;
    }
  }
}
