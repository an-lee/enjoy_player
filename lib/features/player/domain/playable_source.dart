/// Resolved playback binding for a library row (local file, remote URL, or YouTube id).
library;

/// Source passed to [PlayerEngine.open].
sealed class PlayableSource {
  const PlayableSource();
}

/// `file://` or absolute path string accepted by media_kit.
///
/// On the sandboxed macOS build, [uri] may be backed by a security-scoped
/// bookmark (see ADR-0060). When [scopeToken] is non-null, the host engine
/// MUST pair it with a `SecurityScopedBookmarkChannel.releaseBookmark` call
/// before opening a different source or disposing. When [scopeToken] is
/// null, the file is either not on a sandboxed platform, was copied into
/// app-managed `media/` storage, or is a legacy row predating ADR-0060.
final class LocalFilePlayableSource extends PlayableSource {
  const LocalFilePlayableSource(this.uri, {this.scopeToken});

  final String uri;

  /// Opaque integer handle for a started
  /// `startAccessingSecurityScopedResource()` grant. See
  /// `SecurityScopedBookmarkChannel.resolveBookmark` / `releaseBookmark`.
  final int? scopeToken;
}

/// HTTP(S) or other remote URI accepted by media_kit.
final class RemoteUrlPlayableSource extends PlayableSource {
  const RemoteUrlPlayableSource(this.uri);
  final String uri;
}

/// YouTube 11-character video id (see [YoutubePlayableSource] vs table `vid`).
final class YoutubePlayableSource extends PlayableSource {
  const YoutubePlayableSource(this.videoId);
  final String videoId;
}
