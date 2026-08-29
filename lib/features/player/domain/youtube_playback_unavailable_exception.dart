/// Thrown when [YoutubePlayerEngine] cannot run on this platform (ADR-0048).
library;

/// YouTube playback is opted out on Linux for v1: `flutter_inappwebview`
/// ships no Linux backend, so the WebView host can never mount (ADR-0048,
/// R1 / R6). The player surfaces a localized "coming soon" message for this
/// exception instead of the generic open-failure body.
class YouTubePlaybackUnavailableException implements Exception {
  const YouTubePlaybackUnavailableException(this.message);

  /// The canonical ADR-0048 opt-out failure, shared by the open coordinator's
  /// pre-swap gate and [YoutubePlayerEngine.open]'s own guard so the two
  /// cannot drift.
  const YouTubePlaybackUnavailableException.linuxOptedOut()
    : message =
          'YouTube is not yet available on Linux — coming soon '
          '(ADR-0048, R1 / R6: webview2gtk-4.0 dependency).';

  /// Human-readable description (already safe to log).
  final String message;

  @override
  String toString() => 'YouTubePlaybackUnavailableException: $message';
}
