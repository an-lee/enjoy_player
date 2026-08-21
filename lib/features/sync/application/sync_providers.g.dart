// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(syncQueueRepository)
final syncQueueRepositoryProvider = SyncQueueRepositoryProvider._();

final class SyncQueueRepositoryProvider
    extends
        $FunctionalProvider<
          SyncQueueRepository,
          SyncQueueRepository,
          SyncQueueRepository
        >
    with $Provider<SyncQueueRepository> {
  SyncQueueRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncQueueRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncQueueRepositoryHash();

  @$internal
  @override
  $ProviderElement<SyncQueueRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncQueueRepository create(Ref ref) {
    return syncQueueRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncQueueRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncQueueRepository>(value),
    );
  }
}

String _$syncQueueRepositoryHash() =>
    r'13004c01d63849f75b9590e23f906e1432377d69';

@ProviderFor(syncLastFullSyncAt)
final syncLastFullSyncAtProvider = SyncLastFullSyncAtProvider._();

final class SyncLastFullSyncAtProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  SyncLastFullSyncAtProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncLastFullSyncAtProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncLastFullSyncAtHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return syncLastFullSyncAt(ref);
  }
}

String _$syncLastFullSyncAtHash() =>
    r'75ffa58beec95c48c8729915ab4888a656f566eb';

@ProviderFor(syncQueueSnapshot)
final syncQueueSnapshotProvider = SyncQueueSnapshotProvider._();

final class SyncQueueSnapshotProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncQueueSnapshot>,
          SyncQueueSnapshot,
          Stream<SyncQueueSnapshot>
        >
    with
        $FutureModifier<SyncQueueSnapshot>,
        $StreamProvider<SyncQueueSnapshot> {
  SyncQueueSnapshotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncQueueSnapshotProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncQueueSnapshotHash();

  @$internal
  @override
  $StreamProviderElement<SyncQueueSnapshot> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SyncQueueSnapshot> create(Ref ref) {
    return syncQueueSnapshot(ref);
  }
}

String _$syncQueueSnapshotHash() => r'f584b6e742df5204218c7e3306e22a500c637000';

@ProviderFor(craftAudioCloudUploader)
final craftAudioCloudUploaderProvider = CraftAudioCloudUploaderProvider._();

final class CraftAudioCloudUploaderProvider
    extends
        $FunctionalProvider<
          CraftAudioCloudUploader,
          CraftAudioCloudUploader,
          CraftAudioCloudUploader
        >
    with $Provider<CraftAudioCloudUploader> {
  CraftAudioCloudUploaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'craftAudioCloudUploaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$craftAudioCloudUploaderHash();

  @$internal
  @override
  $ProviderElement<CraftAudioCloudUploader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CraftAudioCloudUploader create(Ref ref) {
    return craftAudioCloudUploader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CraftAudioCloudUploader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CraftAudioCloudUploader>(value),
    );
  }
}

String _$craftAudioCloudUploaderHash() =>
    r'0bbf571e3adc0eaea6ae16b115279013046ebc7f';

@ProviderFor(syncUploadService)
final syncUploadServiceProvider = SyncUploadServiceProvider._();

final class SyncUploadServiceProvider
    extends
        $FunctionalProvider<
          SyncUploadService,
          SyncUploadService,
          SyncUploadService
        >
    with $Provider<SyncUploadService> {
  SyncUploadServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncUploadServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncUploadServiceHash();

  @$internal
  @override
  $ProviderElement<SyncUploadService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncUploadService create(Ref ref) {
    return syncUploadService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncUploadService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncUploadService>(value),
    );
  }
}

String _$syncUploadServiceHash() => r'75e54e3904e9fe76d8335a69405eade2a7be84d9';

@ProviderFor(syncDownloadService)
final syncDownloadServiceProvider = SyncDownloadServiceProvider._();

final class SyncDownloadServiceProvider
    extends
        $FunctionalProvider<
          SyncDownloadService,
          SyncDownloadService,
          SyncDownloadService
        >
    with $Provider<SyncDownloadService> {
  SyncDownloadServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncDownloadServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncDownloadServiceHash();

  @$internal
  @override
  $ProviderElement<SyncDownloadService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncDownloadService create(Ref ref) {
    return syncDownloadService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncDownloadService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncDownloadService>(value),
    );
  }
}

String _$syncDownloadServiceHash() =>
    r'f38c5b04cddd594bf81ae50c4f66879e0ef755c7';

@ProviderFor(recordingTargetSyncService)
final recordingTargetSyncServiceProvider =
    RecordingTargetSyncServiceProvider._();

final class RecordingTargetSyncServiceProvider
    extends
        $FunctionalProvider<
          RecordingTargetSyncService,
          RecordingTargetSyncService,
          RecordingTargetSyncService
        >
    with $Provider<RecordingTargetSyncService> {
  RecordingTargetSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingTargetSyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingTargetSyncServiceHash();

  @$internal
  @override
  $ProviderElement<RecordingTargetSyncService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecordingTargetSyncService create(Ref ref) {
    return recordingTargetSyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecordingTargetSyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecordingTargetSyncService>(value),
    );
  }
}

String _$recordingTargetSyncServiceHash() =>
    r'd596b59f534f9b57dc71eb94ac8340ca361a2514';

@ProviderFor(syncEngine)
final syncEngineProvider = SyncEngineProvider._();

final class SyncEngineProvider
    extends $FunctionalProvider<SyncEngine, SyncEngine, SyncEngine>
    with $Provider<SyncEngine> {
  SyncEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncEngineHash();

  @$internal
  @override
  $ProviderElement<SyncEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncEngine create(Ref ref) {
    return syncEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncEngine>(value),
    );
  }
}

String _$syncEngineHash() => r'70bd781209e364951120a0af7c86c112d5f02f24';

@ProviderFor(syncEnqueue)
final syncEnqueueProvider = SyncEnqueueProvider._();

final class SyncEnqueueProvider
    extends $FunctionalProvider<SyncEnqueueFn, SyncEnqueueFn, SyncEnqueueFn>
    with $Provider<SyncEnqueueFn> {
  SyncEnqueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncEnqueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncEnqueueHash();

  @$internal
  @override
  $ProviderElement<SyncEnqueueFn> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncEnqueueFn create(Ref ref) {
    return syncEnqueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncEnqueueFn value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncEnqueueFn>(value),
    );
  }
}

String _$syncEnqueueHash() => r'828d8bec4c564e653e7812646bba1b8ac4c0c0c8';
