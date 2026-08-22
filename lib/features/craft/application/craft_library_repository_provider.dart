/// Riverpod access to [CraftLibraryRepository].
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/db/app_database_provider.dart';
import '../../../data/files/file_storage.dart';
import '../../sync/application/sync_providers.dart';
import '../data/craft_library_repository.dart';

part 'craft_library_repository_provider.g.dart';

@Riverpod(keepAlive: true)
CraftLibraryRepository craftLibraryRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return CraftLibraryRepository(
    db,
    FileStorage(),
    enqueueSync: ref.read(syncEnqueueProvider),
  );
}
