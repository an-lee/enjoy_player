/// Last practiced library item for Home Continue (UI-free).
library;

import 'package:enjoy_player/features/library/domain/media.dart';

/// Single resume target derived from `echo_sessions` + library media.
///
/// Equality ignores [Media.updatedAt] and [lastActiveAt] so library recents
/// ticks and persister heartbeats do not rebuild the Home hero (P-1).
class PracticeResume {
  const PracticeResume({
    required this.media,
    required this.positionMs,
    required this.echoActive,
    required this.lastActiveAt,
    required this.sessionId,
  });

  final Media media;
  final int positionMs;
  final bool echoActive;
  final DateTime lastActiveAt;
  final String sessionId;

  /// `position / duration` in `[0, 1]`, or `null` when duration is unknown.
  double? get progress {
    final duration = media.durationMs;
    if (duration <= 0) return null;
    final fraction = positionMs / duration;
    if (fraction.isNaN || fraction.isInfinite) return null;
    return fraction.clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PracticeResume &&
        other.sessionId == sessionId &&
        other.positionMs == positionMs &&
        other.echoActive == echoActive &&
        _mediaVisualEquals(other.media, media);
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    positionMs,
    echoActive,
    media.id,
    media.title,
    media.durationMs,
    media.language,
    media.thumbnailPath,
    media.provider,
    media.source,
    media.kind,
    media.contentHash,
  );
}

bool _mediaVisualEquals(Media a, Media b) {
  return a.id == b.id &&
      a.kind == b.kind &&
      a.title == b.title &&
      a.durationMs == b.durationMs &&
      a.language == b.language &&
      a.thumbnailPath == b.thumbnailPath &&
      a.provider == b.provider &&
      a.source == b.source &&
      a.contentHash == b.contentHash &&
      a.mediaUrl == b.mediaUrl;
}
