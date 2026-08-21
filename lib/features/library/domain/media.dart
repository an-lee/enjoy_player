/// UI-facing media item (decoupled from persistence rows).
library;

enum MediaKind { audio, video }

extension MediaKindX on MediaKind {
  String get storageValue => switch (this) {
    MediaKind.audio => 'audio',
    MediaKind.video => 'video',
  };

  /// Weapp / Dexie `TargetType` string (`Video` | `Audio`).
  String get dexieTargetType => switch (this) {
    MediaKind.video => 'Video',
    MediaKind.audio => 'Audio',
  };

  static MediaKind fromStorage(String kind) {
    switch (kind) {
      case 'video':
        return MediaKind.video;
      default:
        return MediaKind.audio;
    }
  }
}

class Media {
  const Media({
    required this.id,
    required this.kind,
    required this.title,
    required this.sourceUri,
    this.thumbnailPath,
    required this.durationMs,
    required this.language,

    /// SHA-256 content id (`vid` for video, `aid` for audio in weapp terms).
    required this.contentHash,
    required this.fileSize,
    this.mediaUrl,
    this.source,
    this.provider = 'user',
    this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final MediaKind kind;
  final String title;
  final String sourceUri;
  final String? thumbnailPath;
  final int durationMs;
  final String language;
  final String contentHash;
  final int fileSize;
  final String? mediaUrl;
  final String? source;

  /// Row `provider` — e.g. `user`, `youtube`.
  final String provider;

  /// Sync status from the underlying Drift row (`pending` / `synced` /
  /// `local` / `null`). Drives the cloud-sync badge UI; see
  /// `resolveMediaCardSyncBadge` in
  /// `lib/core/theme/widgets/media_card/media_card_sync_badge.dart`.
  final String? syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Alias for weapp naming (`vid` / `aid`).
  String get vidOrAid => contentHash;

  String get dexieTargetType => kind.dexieTargetType;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Media &&
        other.id == id &&
        other.kind == kind &&
        other.title == title &&
        other.sourceUri == sourceUri &&
        other.thumbnailPath == thumbnailPath &&
        other.durationMs == durationMs &&
        other.language == language &&
        other.contentHash == contentHash &&
        other.fileSize == fileSize &&
        other.mediaUrl == mediaUrl &&
        other.source == source &&
        other.provider == provider &&
        other.syncStatus == syncStatus &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    title,
    sourceUri,
    thumbnailPath,
    durationMs,
    language,
    contentHash,
    fileSize,
    mediaUrl,
    source,
    provider,
    syncStatus,
    createdAt,
    updatedAt,
  );
}

extension MediaSourceKind on Media {
  /// Remote/streaming URL from sync (vs local file).
  bool get isLink => mediaUrl != null && mediaUrl!.isNotEmpty;

  /// Local file playback (no `mediaUrl`); may still need relocation on this device.
  bool get isLocal => !isLink;
}

extension MediaCoverSeed on Media {
  /// Whether a non-empty thumbnail path is stored (file may still be missing on disk).
  bool get hasThumbnailPath =>
      thumbnailPath != null && thumbnailPath!.trim().isNotEmpty;

  /// Stable seed for deterministic generative artwork (aligned with web `GenerativeCover`).
  String get coverSeed => contentHash.trim().isNotEmpty ? contentHash : id;
}
