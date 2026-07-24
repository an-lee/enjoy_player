/// Upload local entities to Enjoy API (metadata only).
library;

import 'package:drift/drift.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/api/services/audio_api.dart';
import 'package:enjoy_player/data/api/services/recording_api.dart';
import 'package:enjoy_player/data/api/services/video_api.dart';
import 'package:enjoy_player/data/api/services/vocabulary_api.dart';
import 'package:enjoy_player/features/sync/data/sync_serializers.dart';

final _log = logNamed('sync.upload');

/// Thrown when a server upload response omits the required `updatedAt` field.
///
/// Without `updatedAt` we cannot trust [serverUpdatedAt] — defaulting to
/// `DateTime.now()` would silently make the local row appear newer than the
/// server and trigger spurious re-uploads that could clobber concurrent
/// server-side edits. The row is left untouched and the sync queue will retry.
class SyncMissingUpdatedAtError extends Error {
  SyncMissingUpdatedAtError(this.entity, this.id);

  final String entity;
  final String id;

  @override
  String toString() =>
      'SyncMissingUpdatedAtError($entity $id): server response missing updatedAt';
}

/// Server reported the entity already exists, but GET-by-id returned 404.
///
/// Retries will not recover (create keeps failing as duplicate; fetch keeps
/// 404). The sync engine marks the queue row permanently failed.
class SyncDuplicateMissingError extends Error {
  SyncDuplicateMissingError(this.entity, this.id);

  final String entity;
  final String id;

  @override
  String toString() =>
      'SyncDuplicateMissingError($entity $id): '
      'create said already exists but GET returned 404';
}

class SyncUploadService {
  SyncUploadService({
    required this._db,
    required this._audioApi,
    required this._videoApi,
    required this._recordingApi,
    required this._vocabularyApi,
  });

  final AppDatabase _db;
  final AudioApi _audioApi;
  final VideoApi _videoApi;
  final RecordingApi _recordingApi;
  final VocabularyApi _vocabularyApi;

  Future<void> uploadAudio(AudioRow row) async {
    Map<String, dynamic> inner;
    try {
      final response = await _audioApi.uploadAudio(prepareForSyncAudioMap(row));
      inner = unwrapEntity(response, 'audio');
    } on ApiException catch (e) {
      if (!e.isDuplicateEntity) rethrow;
      _log.fine('audio ${row.id} already on server; fetching existing row');
      try {
        final response = await _audioApi.audio(row.id);
        inner = unwrapEntity(response, 'audio');
      } on ApiException catch (fetchError) {
        if (fetchError.statusCode == 404) {
          throw SyncDuplicateMissingError('audio', row.id);
        }
        rethrow;
      }
    }
    final serverUpdated = _requireServerUpdated(
      inner,
      entity: 'audio',
      id: row.id,
    );
    await _db.audioDao.insertRow(
      row.copyWith(
        syncStatus: const Value('synced'),
        serverUpdatedAt: Value(serverUpdated),
        mediaUrl: Value(inner['mediaUrl'] as String? ?? row.mediaUrl),
        updatedAt: serverUpdated,
      ),
    );
  }

  Future<void> uploadVideo(VideoRow row) async {
    final inner = await _uploadVideoPayload(row);
    await _persistSyncedVideo(row, inner);
  }

  Future<Map<String, dynamic>> _uploadVideoPayload(VideoRow row) async {
    try {
      final response = await _videoApi.uploadVideo(prepareForSyncVideoMap(row));
      return unwrapEntity(response, 'video');
    } on ApiException catch (e) {
      if (!e.isDuplicateEntity) rethrow;
      // Mine create is membership upsert; on rare unique races, re-fetch mine.
      _log.fine('video ${row.id} already on server; fetching mine row');
      try {
        final response = await _videoApi.video(row.id);
        return unwrapEntity(response, 'video');
      } on ApiException catch (fetchError) {
        if (fetchError.statusCode == 404) {
          throw SyncDuplicateMissingError('video', row.id);
        }
        rethrow;
      }
    }
  }

  Future<void> _persistSyncedVideo(
    VideoRow row,
    Map<String, dynamic> inner,
  ) async {
    final serverUpdated = _requireServerUpdated(
      inner,
      entity: 'video',
      id: row.id,
    );
    await _db.videoDao.insertRow(
      row.copyWith(
        syncStatus: const Value('synced'),
        serverUpdatedAt: Value(serverUpdated),
        mediaUrl: Value(inner['mediaUrl'] as String? ?? row.mediaUrl),
        updatedAt: serverUpdated,
      ),
    );
  }

  Future<void> uploadRecording(RecordingRow row) async {
    final response = await _recordingApi.uploadRecording(
      prepareForSyncRecordingMap(row),
    );
    final inner = unwrapEntity(response, 'recording');
    final serverUpdated = _requireServerUpdated(
      inner,
      entity: 'recording',
      id: row.id,
    );
    await _db.recordingDao.insertRow(
      row.copyWith(
        syncStatus: const Value('synced'),
        serverUpdatedAt: Value(serverUpdated),
        audioUrl: Value(inner['audioUrl'] as String? ?? row.audioUrl),
        updatedAt: serverUpdated,
      ),
    );
  }

  Future<void> uploadVocabularyItem(VocabularyItemRow row) async {
    Map<String, dynamic> inner;
    try {
      final response = await _vocabularyApi.uploadVocabularyItem(
        prepareForSyncVocabularyItemMap(row),
      );
      inner = await _ensureUpdatedAt(
        unwrapEntity(response, 'vocabularyItem'),
        entity: 'vocabulary_item',
        id: row.id,
        fetchById: () => _vocabularyApi.vocabularyItem(row.id),
        envelopeKey: 'vocabularyItem',
      );
    } on ApiException catch (e) {
      if (!e.isDuplicateEntity) rethrow;
      _log.fine(
        'vocabulary item ${row.id} already on server; fetching existing row',
      );
      try {
        final response = await _vocabularyApi.vocabularyItem(row.id);
        inner = unwrapEntity(response, 'vocabularyItem');
      } on ApiException catch (fetchError) {
        if (fetchError.statusCode == 404) {
          throw SyncDuplicateMissingError('vocabulary_item', row.id);
        }
        rethrow;
      }
    }
    final serverUpdated = _requireServerUpdated(
      inner,
      entity: 'vocabulary_item',
      id: row.id,
    );
    await _db.vocabularyItemDao.updateRow(
      row.copyWith(
        syncStatus: const Value('synced'),
        serverUpdatedAt: Value(serverUpdated),
        updatedAt: serverUpdated,
      ),
    );
  }

  Future<void> uploadVocabularyContext(VocabularyContextRow row) async {
    Map<String, dynamic> inner;
    try {
      final response = await _vocabularyApi.uploadVocabularyContext(
        prepareForSyncVocabularyContextMap(row),
      );
      inner = await _ensureUpdatedAt(
        unwrapEntity(response, 'vocabularyContext'),
        entity: 'vocabulary_context',
        id: row.id,
        fetchById: () => _vocabularyApi.vocabularyContext(row.id),
        envelopeKey: 'vocabularyContext',
      );
    } on ApiException catch (e) {
      if (!e.isDuplicateEntity) rethrow;
      _log.fine(
        'vocabulary context ${row.id} already on server; fetching existing row',
      );
      try {
        final response = await _vocabularyApi.vocabularyContext(row.id);
        inner = unwrapEntity(response, 'vocabularyContext');
      } on ApiException catch (fetchError) {
        if (fetchError.statusCode == 404) {
          throw SyncDuplicateMissingError('vocabulary_context', row.id);
        }
        rethrow;
      }
    }
    final serverUpdated = _requireServerUpdated(
      inner,
      entity: 'vocabulary_context',
      id: row.id,
    );
    await _db.vocabularyContextDao.updateRow(
      row.copyWith(
        syncStatus: const Value('synced'),
        serverUpdatedAt: Value(serverUpdated),
        updatedAt: serverUpdated,
      ),
    );
  }

  /// Older mine vocabulary create endpoints returned `{ success: true }`
  /// without the row. Refetch by id so sync can stamp [serverUpdatedAt].
  Future<Map<String, dynamic>> _ensureUpdatedAt(
    Map<String, dynamic> inner, {
    required String entity,
    required String id,
    required Future<Map<String, dynamic>> Function() fetchById,
    required String envelopeKey,
  }) async {
    if (parseIsoDate(inner['updatedAt']) != null) return inner;
    _log.info(
      '$entity $id: upload ok but response missing updatedAt; fetching row',
    );
    final response = await fetchById();
    return unwrapEntity(response, envelopeKey);
  }

  DateTime _requireServerUpdated(
    Map<String, dynamic> inner, {
    required String entity,
    required String id,
  }) {
    final parsed = parseIsoDate(inner['updatedAt']);
    if (parsed == null) {
      _log.warning(
        'server response missing updatedAt for $entity $id; refusing to write',
      );
      throw SyncMissingUpdatedAtError(entity, id);
    }
    return parsed;
  }

  Future<void> deleteAudio(String id) =>
      _deleteWith404Guard(() => _audioApi.deleteAudio(id));

  Future<void> deleteVideo(String id) =>
      _deleteWith404Guard(() => _videoApi.deleteVideo(id));

  Future<void> deleteRecording(String id) =>
      _deleteWith404Guard(() => _recordingApi.deleteRecording(id));

  Future<void> deleteVocabularyItem(String id) =>
      _deleteWith404Guard(() => _vocabularyApi.deleteVocabularyItem(id));

  Future<void> deleteVocabularyContext(String id) =>
      _deleteWith404Guard(() => _vocabularyApi.deleteVocabularyContext(id));

  /// Runs a server delete, treating a `404` response as success (the entity
  /// was already gone on the server). Any other [ApiException] is rethrown so
  /// the sync queue can retry or fail the row.
  Future<void> _deleteWith404Guard(Future<void> Function() delete) async {
    try {
      await delete();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return;
      rethrow;
    }
  }
}
