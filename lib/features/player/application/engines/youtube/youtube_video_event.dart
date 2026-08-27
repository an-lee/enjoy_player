/// Canonical string protocol between the watch-page JavaScript and Dart.
///
/// The Dart↔JS seam is stringly-typed by necessity (one-way
/// `callHandler` messages out of the page). These constants are the single
/// spelling of that protocol on the Dart side: the JS sources emit exactly
/// these names, and [YoutubeWebViewEvents] handles exactly these names.
/// `youtube_js_protocol_contract_test.dart` pins both directions so a name
/// added on one side without the other fails CI instead of vanishing into
/// the (logged) default branch.
library;

/// Event names carried on the `onVideoEvent` handler.
abstract final class YoutubeVideoEventName {
  /// Optimistic play request (may still be followed by a DOM `pause`).
  static const String play = 'play';

  /// Playback actually started (`<video>` `playing`).
  static const String playing = 'playing';

  /// DOM pause (transport waits for poll-streak confirmation).
  static const String pause = 'pause';

  /// A programmatic play promise rejected (autoplay policy).
  static const String playRejected = 'playRejected';

  /// End of media.
  static const String ended = 'ended';

  /// Buffering (`<video>` `waiting`).
  static const String waiting = 'waiting';

  /// Enough data to play (`<video>` `canplay`).
  static const String canplay = 'canplay';

  /// Metadata known; second arg carries the duration in seconds.
  static const String loadedmetadata = 'loadedmetadata';

  /// Element error.
  static const String error = 'error';

  /// Every name the Dart side switches over — must match the set the JS
  /// sources emit (see the contract test).
  static const Set<String> all = {
    play,
    playing,
    pause,
    playRejected,
    ended,
    waiting,
    canplay,
    loadedmetadata,
    error,
  };
}

/// Handler names registered by [YoutubeWebViewController] via
/// `addJavaScriptHandler` and called from the page via
/// `flutter_inappwebview.callHandler`.
abstract final class YoutubeJsHandlerName {
  static const String onVideoEvent = 'onVideoEvent';
  static const String onAdReload = 'onAdReload';

  static const Set<String> all = {onVideoEvent, onAdReload};
}
