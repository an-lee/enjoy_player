/// JSON preparation + server merge helpers for sync.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:enjoy_player/core/utils/remote_thumbnail_url.dart';
import 'package:enjoy_player/core/utils/youtube_video_identity.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/youtube_subscription_source.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_item_conflict.dart';

export 'package:enjoy_player/core/utils/remote_thumbnail_url.dart'
    show isRemoteThumbnailUrl, remoteThumbnailForCard;

DateTime? parseIsoDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

DateTime requireIsoDate(dynamic value, DateTime fallback) =>
    parseIsoDate(value) ?? fallback;

int durationSecondsFromJson(Map<String, dynamic> json) {
  final v = json['durationSeconds'] ?? json['duration'];
  if (v is int) return v;
  if (v is num) return v.round();
  return 0;
}

/// Recording API `duration` / `referenceStart` / `referenceDuration` are ms (web/extension contract).
int _recordingWireMsFromJson(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return 0;
}

/// Payload for [AudioApi.uploadAudio] body (`audio` key added by API).
///
/// When [signedId] is non-null and non-empty, it is included so the server
/// attaches the previously-uploaded blob (via Rails Active Storage) to the
/// audio model and populates `mediaUrl` in the response. The web app sends
/// the same field via `attachMediaBlobToPayload`. Only the Crafted Audio
/// Cloud Sync flow sends a non-null [signedId].
Map<String, dynamic> prepareForSyncAudioMap(AudioRow row, {String? signedId}) {
  return <String, dynamic>{
    'id': row.id,
    'aid': row.aid,
    'provider': row.provider,
    'title': row.title,
    if (row.description != null) 'description': row.description,
    if (isRemoteThumbnailUrl(row.thumbnailUrl))
      'thumbnailUrl': row.thumbnailUrl!,
    'duration': row.durationSeconds,
    'language': row.language,
    if (row.translationKey != null) 'translationKey': row.translationKey,
    if (row.sourceText != null) 'sourceText': row.sourceText,
    if (row.voice != null) 'voice': row.voice,
    if (row.source != null) 'source': row.source,
    if (row.md5 != null) 'md5': row.md5,
    if (row.size != null) 'size': row.size,
    if (row.mediaUrl != null) 'mediaUrl': row.mediaUrl,
    if (signedId != null && signedId.isNotEmpty) 'signedId': signedId,
    'createdAt': row.createdAt.toUtc().toIso8601String(),
    'updatedAt': row.updatedAt.toUtc().toIso8601String(),
  };
}

Map<String, dynamic> prepareForSyncVideoMap(VideoRow row) {
  return <String, dynamic>{
    'id': row.id,
    'vid': row.vid,
    'provider': row.provider,
    'title': row.title,
    if (row.description != null) 'description': row.description,
    if (isRemoteThumbnailUrl(row.thumbnailUrl))
      'thumbnailUrl': row.thumbnailUrl!,
    'duration': row.durationSeconds,
    'language': row.language,
    if (row.source != null) 'source': row.source,
    if (row.md5 != null) 'md5': row.md5,
    if (row.size != null) 'size': row.size,
    if (row.mediaUrl != null) 'mediaUrl': row.mediaUrl,
    'createdAt': row.createdAt.toUtc().toIso8601String(),
    'updatedAt': row.updatedAt.toUtc().toIso8601String(),
  };
}

Map<String, dynamic> prepareForSyncRecordingMap(RecordingRow row) {
  return <String, dynamic>{
    'id': row.id,
    'targetId': row.targetId,
    'targetType': row.targetType,
    'duration': row.duration,
    if (row.md5 != null) 'md5': row.md5,
    'referenceText': row.referenceText,
    'referenceStart': row.referenceStart,
    'referenceDuration': row.referenceDuration,
    'language': row.language,
    if (row.audioUrl != null) 'audioUrl': row.audioUrl,
    if (row.pronunciationScore != null)
      'pronunciationScore': row.pronunciationScore,
    if (row.assessmentJson != null) 'assessmentJson': row.assessmentJson,
    'createdAt': row.createdAt.toUtc().toIso8601String(),
    'updatedAt': row.updatedAt.toUtc().toIso8601String(),
  };
}

AudioRow audioRowFromServerJson(Map<String, dynamic> json) {
  final now = DateTime.now();
  final updatedAt = requireIsoDate(json['updatedAt'], now);
  final createdAt = requireIsoDate(json['createdAt'], updatedAt);
  return AudioRow(
    id: json['id'] as String,
    aid: json['aid'] as String? ?? json['id'] as String,
    provider: json['provider'] as String? ?? 'user',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    durationSeconds: durationSecondsFromJson(json),
    language: json['language'] as String? ?? 'und',
    translationKey: json['translationKey'] as String?,
    sourceText: json['sourceText'] as String?,
    voice: json['voice'] as String?,
    source: json['source'] as String?,
    localUri: null,
    md5: json['md5'] as String?,
    size: json['size'] as int?,
    mediaUrl: json['mediaUrl'] as String?,
    syncStatus: json['syncStatus'] as String? ?? 'synced',
    serverUpdatedAt: parseIsoDate(json['serverUpdatedAt']),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

VideoRow videoRowFromServerJson(Map<String, dynamic> json) {
  final now = DateTime.now();
  final updatedAt = requireIsoDate(json['updatedAt'], now);
  final createdAt = requireIsoDate(json['createdAt'], updatedAt);
  final vid = json['vid'] as String? ?? json['id'] as String;
  final mediaUrl = json['mediaUrl'] as String?;
  final source = json['source'] as String?;
  final provider = normalizeServerVideoProviderFields(
    rawProvider: json['provider'] as String?,
    vid: vid,
    mediaUrl: mediaUrl,
    source: source,
  );
  return VideoRow(
    id: json['id'] as String,
    vid: vid,
    provider: provider,
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    durationSeconds: durationSecondsFromJson(json),
    language: json['language'] as String? ?? 'und',
    source: json['source'] as String?,
    localUri: null,
    md5: json['md5'] as String?,
    size: json['size'] as int?,
    mediaUrl: json['mediaUrl'] as String?,
    syncStatus: json['syncStatus'] as String? ?? 'synced',
    serverUpdatedAt: parseIsoDate(json['serverUpdatedAt']),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

RecordingRow recordingRowFromServerJson(Map<String, dynamic> json) {
  final now = DateTime.now();
  final updatedAt = requireIsoDate(json['updatedAt'], now);
  final createdAt = requireIsoDate(json['createdAt'], updatedAt);

  return RecordingRow(
    id: json['id'] as String,
    targetType: json['targetType'] as String? ?? 'Audio',
    targetId: json['targetId'] as String? ?? '',
    referenceStart: _recordingWireMsFromJson(json['referenceStart']),
    referenceDuration: _recordingWireMsFromJson(json['referenceDuration']),
    referenceText: json['referenceText'] as String? ?? '',
    language: json['language'] as String? ?? 'und',
    duration: _recordingWireMsFromJson(json['duration']),
    md5: json['md5'] as String?,
    audioUrl: json['audioUrl'] as String?,
    pronunciationScore: json['pronunciationScore'] as int?,
    assessmentJson: json['assessmentJson'] as String?,
    localPath: null,
    syncStatus: json['syncStatus'] as String? ?? 'synced',
    serverUpdatedAt: parseIsoDate(json['serverUpdatedAt']),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

/// Server wins on ties (`>=`), matching web `resolveConflict`.
AudioRow mergeAudioLastWriteWins({
  required AudioRow? local,
  required Map<String, dynamic> server,
}) {
  final serverRow = audioRowFromServerJson(server);
  if (local == null) return serverRow;
  if (local.updatedAt.isAfter(serverRow.updatedAt)) return local;
  return serverRow.copyWith(
    localUri: Value(local.localUri),
    localMtimeMs: Value(local.localMtimeMs),
  );
}

VideoRow mergeVideoLastWriteWins({
  required VideoRow? local,
  required Map<String, dynamic> server,
}) {
  final serverRow = videoRowFromServerJson(server);
  if (local == null) return serverRow;
  if (local.updatedAt.isAfter(serverRow.updatedAt)) return local;
  return serverRow.copyWith(
    localUri: Value(local.localUri),
    localMtimeMs: Value(local.localMtimeMs),
  );
}

RecordingRow mergeRecordingLastWriteWins({
  required RecordingRow? local,
  required Map<String, dynamic> server,
}) {
  final serverRow = recordingRowFromServerJson(server);
  if (local == null) return serverRow;
  if (local.updatedAt.isAfter(serverRow.updatedAt)) return local;
  return serverRow.copyWith(localPath: Value(local.localPath));
}

/// Payload for [VocabularyApi.uploadVocabularyItem] body (`vocabularyItem`
/// key added by API). Review audits never leave the device (ADR-0054).
Map<String, dynamic> prepareForSyncVocabularyItemMap(VocabularyItemRow row) {
  return <String, dynamic>{
    'id': row.id,
    'word': row.word,
    'language': row.language,
    'targetLanguage': row.targetLanguage,
    'status': row.status,
    'easeFactor': row.easeFactor,
    'interval': row.interval,
    'nextReviewAt': row.nextReviewAt.toUtc().toIso8601String(),
    'reviewsCount': row.reviewsCount,
    if (row.lastReviewedAt != null)
      'lastReviewedAt': row.lastReviewedAt!.toUtc().toIso8601String(),
    'contextsCount': row.contextsCount,
    if (row.explanation != null) 'explanation': row.explanation,
    'createdAt': row.createdAt.toUtc().toIso8601String(),
    'updatedAt': row.updatedAt.toUtc().toIso8601String(),
  };
}

/// Payload for [VocabularyApi.uploadVocabularyContext] body
/// (`vocabularyContext` key added by API).
Map<String, dynamic> prepareForSyncVocabularyContextMap(
  VocabularyContextRow row,
) {
  return <String, dynamic>{
    'id': row.id,
    'vocabularyItemId': row.vocabularyItemId,
    'text': row.contextText,
    'sourceType': row.sourceType,
    'sourceId': row.sourceId,
    'locator': jsonDecode(row.locatorJson),
    if (row.explanation != null) 'explanation': row.explanation,
    'createdAt': row.createdAt.toUtc().toIso8601String(),
    'updatedAt': row.updatedAt.toUtc().toIso8601String(),
  };
}

VocabularyItemRow vocabularyItemRowFromServerJson(Map<String, dynamic> json) {
  final now = DateTime.now();
  final updatedAt = requireIsoDate(json['updatedAt'], now);
  final createdAt = requireIsoDate(json['createdAt'], updatedAt);
  return VocabularyItemRow(
    id: json['id'] as String,
    word: json['word'] as String? ?? '',
    language: json['language'] as String? ?? 'und',
    targetLanguage: json['targetLanguage'] as String? ?? 'und',
    status: json['status'] as String? ?? 'new',
    easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
    interval: (json['interval'] as num?)?.toInt() ?? 0,
    nextReviewAt: requireIsoDate(json['nextReviewAt'], updatedAt),
    reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? 0,
    lastReviewedAt: parseIsoDate(json['lastReviewedAt']),
    contextsCount: (json['contextsCount'] as num?)?.toInt() ?? 0,
    explanation: json['explanation'] as String?,
    syncStatus: json['syncStatus'] as String? ?? 'synced',
    serverUpdatedAt: parseIsoDate(json['serverUpdatedAt']),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

VocabularyContextRow vocabularyContextRowFromServerJson(
  Map<String, dynamic> json,
) {
  final now = DateTime.now();
  final updatedAt = requireIsoDate(json['updatedAt'], now);
  final createdAt = requireIsoDate(json['createdAt'], updatedAt);
  final locator = json['locator'];
  final locatorJson = locator == null
      ? '{}'
      : (locator is String ? locator : jsonEncode(locator));
  return VocabularyContextRow(
    id: json['id'] as String,
    vocabularyItemId: json['vocabularyItemId'] as String? ?? '',
    contextText: json['text'] as String? ?? '',
    sourceType: json['sourceType'] as String? ?? 'Video',
    sourceId: json['sourceId'] as String? ?? '',
    locatorJson: locatorJson,
    explanation: json['explanation'] as String?,
    syncStatus: json['syncStatus'] as String? ?? 'synced',
    serverUpdatedAt: parseIsoDate(json['serverUpdatedAt']),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

/// SRS-preserving merge (ADR-0054): keeps local SRS fields when local review
/// activity is fresher than the server's; otherwise takes the server row.
VocabularyItemRow mergeVocabularyItemConflict({
  required VocabularyItemRow? local,
  required Map<String, dynamic> server,
}) {
  final serverRow = vocabularyItemRowFromServerJson(server);
  if (local == null) return serverRow;

  final resolved = resolveVocabularyItemConflict(
    local: VocabularyItemConflictSide(
      word: local.word,
      status: local.status,
      easeFactor: local.easeFactor,
      interval: local.interval,
      nextReviewAt: local.nextReviewAt,
      reviewsCount: local.reviewsCount,
      lastReviewedAt: local.lastReviewedAt,
      explanation: local.explanation,
      contextsCount: local.contextsCount,
      updatedAt: local.updatedAt,
    ),
    server: VocabularyItemConflictSide(
      word: serverRow.word,
      status: serverRow.status,
      easeFactor: serverRow.easeFactor,
      interval: serverRow.interval,
      nextReviewAt: serverRow.nextReviewAt,
      reviewsCount: serverRow.reviewsCount,
      lastReviewedAt: serverRow.lastReviewedAt,
      explanation: serverRow.explanation,
      contextsCount: serverRow.contextsCount,
      updatedAt: serverRow.updatedAt,
    ),
  );

  return local.copyWith(
    word: resolved.word,
    status: resolved.status,
    easeFactor: resolved.easeFactor,
    interval: resolved.interval,
    nextReviewAt: resolved.nextReviewAt,
    reviewsCount: resolved.reviewsCount,
    lastReviewedAt: Value(resolved.lastReviewedAt),
    explanation: Value(resolved.explanation),
    contextsCount: resolved.contextsCount,
    syncStatus: const Value('synced'),
    serverUpdatedAt: Value(resolved.serverUpdatedAt),
    updatedAt: resolved.updatedAt,
  );
}

/// Server wins on ties (`>=`), matching web `resolveConflict`. Context
/// conflicts have no local-only columns to preserve (ADR-0054).
VocabularyContextRow mergeVocabularyContextLastWriteWins({
  required VocabularyContextRow? local,
  required Map<String, dynamic> server,
}) {
  final serverRow = vocabularyContextRowFromServerJson(server);
  if (local == null) return serverRow;
  if (local.updatedAt.isAfter(serverRow.updatedAt)) return local;
  return serverRow;
}

Map<String, dynamic> unwrapEntity(Map<String, dynamic> response, String key) {
  final inner = response[key];
  if (inner is Map<String, dynamic>) return inner;
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return response;
}

/// Serializes a YouTube subscription for cloud sync.
Map<String, dynamic> prepareForSyncSubscriptionMap(
  YoutubeChannelSubscriptionRow row,
) {
  return <String, dynamic>{
    'channelId': row.channelId,
    'displayName': row.displayName,
    if (row.thumbnailUrl != null) 'thumbnailUrl': row.thumbnailUrl,
    'source': row.source.name,
    'sourceType': row.sourceType.name,
    if (row.feedUrl != null) 'feedUrl': row.feedUrl,
    'language': row.language,
    'subscribedAt': row.subscribedAt.toUtc().toIso8601String(),
    if (row.lastFetchedAt != null)
      'lastFetchedAt': row.lastFetchedAt!.toUtc().toIso8601String(),
  };
}

/// Deserializes a YouTube subscription from server sync JSON.
YoutubeChannelSubscriptionRow subscriptionRowFromServerJson(
  Map<String, dynamic> json,
) {
  final now = DateTime.now();
  final subscribedAt = requireIsoDate(json['subscribedAt'], now);
  final lastFetchedAt = parseIsoDate(json['lastFetchedAt']);
  return YoutubeChannelSubscriptionRow(
    channelId: json['channelId'] as String,
    displayName: json['displayName'] as String? ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String?,
    source: YoutubeSubscriptionSource.values.firstWhere(
      (e) => e.name == json['source'],
      orElse: () => YoutubeSubscriptionSource.user,
    ),
    sourceType: YoutubeSourceType.values.firstWhere(
      (e) => e.name == json['sourceType'],
      orElse: () => YoutubeSourceType.channel,
    ),
    feedUrl: json['feedUrl'] as String?,
    language: json['language'] as String? ?? 'und',
    subscribedAt: subscribedAt,
    lastFetchedAt: lastFetchedAt,
  );
}
