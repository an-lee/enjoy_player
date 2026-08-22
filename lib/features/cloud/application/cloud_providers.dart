/// Riverpod wiring for Cloud index (manual providers — avoids extra codegen).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/data/api/api_client_provider.dart';
import 'package:enjoy_player/data/api/services/audio_api.dart';
import 'package:enjoy_player/data/api/services/video_api.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/cloud/application/cloud_add_to_library.dart';
import 'package:enjoy_player/features/cloud/data/cloud_index_repository.dart';

final cloudIndexRepositoryProvider = Provider<CloudIndexRepository>((ref) {
  return CloudIndexRepository(
    audioApi: AudioApi(ref.watch(apiClientProvider)),
    videoApi: VideoApi(ref.watch(apiClientProvider)),
  );
});

final cloudAddToLibraryProvider = Provider<CloudAddToLibrary>((ref) {
  return CloudAddToLibrary(ref.watch(appDatabaseProvider));
});
