/// Riverpod wiring for [SyncEngine] dependencies.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/api/api_client_provider.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/data/api/services/api_providers.dart';
import 'package:enjoy_player/data/api/services/audio_api.dart';
import 'package:enjoy_player/data/api/services/recording_api.dart';
import 'package:enjoy_player/data/api/services/video_api.dart';
import 'package:enjoy_player/data/api/services/vocabulary_api.dart';
import 'package:enjoy_player/data/files/file_storage.dart';
import 'package:enjoy_player/features/craft/application/craft_audio_cloud_uploader.dart';
import 'package:enjoy_player/features/sync/application/queue_for_sync.dart';
import 'package:enjoy_player/features/sync/application/sync_engine.dart';
import 'package:enjoy_player/features/sync/data/recording_target_sync_service.dart';
import 'package:enjoy_player/features/sync/data/sync_download_service.dart';
import 'package:enjoy_player/features/sync/data/sync_queue_repository.dart';
import 'package:enjoy_player/features/sync/data/sync_upload_service.dart';
import 'package:enjoy_player/features/sync/domain/sync_types.dart';

part 'sync_providers.g.dart';

@Riverpod(keepAlive: true)
SyncQueueRepository syncQueueRepository(Ref ref) =>
    SyncQueueRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
Future<String?> syncLastFullSyncAt(Ref ref) => ref
    .watch(appDatabaseProvider)
    .settingsDao
    .getValue(SettingsKeys.syncLastFullSyncAt);

@Riverpod(keepAlive: true)
Stream<SyncQueueSnapshot> syncQueueSnapshot(Ref ref) =>
    ref.watch(syncQueueRepositoryProvider).watchSnapshot(detailLimit: 50);

@Riverpod(keepAlive: true)
CraftAudioCloudUploader craftAudioCloudUploader(Ref ref) =>
    CraftAudioCloudUploader(
      fileStorage: FileStorage(),
      directUploadsApi: ref.watch(directUploadsApiProvider),
    );

@Riverpod(keepAlive: true)
SyncUploadService syncUploadService(Ref ref) => SyncUploadService(
  db: ref.watch(appDatabaseProvider),
  audioApi: AudioApi(ref.watch(apiClientProvider)),
  videoApi: VideoApi(ref.watch(apiClientProvider)),
  recordingApi: RecordingApi(ref.watch(apiClientProvider)),
  vocabularyApi: VocabularyApi(ref.watch(apiClientProvider)),
  craftAudioCloudUploader: ref.watch(craftAudioCloudUploaderProvider),
);

@Riverpod(keepAlive: true)
SyncDownloadService syncDownloadService(Ref ref) => SyncDownloadService(
  db: ref.watch(appDatabaseProvider),
  audioApi: AudioApi(ref.watch(apiClientProvider)),
  videoApi: VideoApi(ref.watch(apiClientProvider)),
  recordingApi: RecordingApi(ref.watch(apiClientProvider)),
  vocabularyApi: VocabularyApi(ref.watch(apiClientProvider)),
);

@Riverpod(keepAlive: true)
RecordingTargetSyncService recordingTargetSyncService(Ref ref) =>
    RecordingTargetSyncService(
      db: ref.watch(appDatabaseProvider),
      recordingApi: RecordingApi(ref.watch(apiClientProvider)),
    );

@Riverpod(keepAlive: true)
SyncEngine syncEngine(Ref ref) => SyncEngine(
  db: ref.watch(appDatabaseProvider),
  queue: ref.watch(syncQueueRepositoryProvider),
  upload: ref.watch(syncUploadServiceProvider),
  download: ref.watch(syncDownloadServiceProvider),
);

@Riverpod(keepAlive: true)
SyncEnqueueFn syncEnqueue(Ref ref) {
  final queue = ref.watch(syncQueueRepositoryProvider);
  final engine = ref.watch(syncEngineProvider);
  return (type, id, action) =>
      enqueuePendingSync(ref, queue, engine, type, id, action);
}
