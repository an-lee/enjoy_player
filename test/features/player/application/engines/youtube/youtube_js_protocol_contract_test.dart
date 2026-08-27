import 'package:enjoy_player/features/player/application/engines/youtube/youtube_page_inject.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_video_event.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the string protocol between the watch-page JavaScript and Dart
/// (issue #629, tier 1).
///
/// The JS side cannot be executed in a unit test (tier 2 tracks a runtime
/// harness), but the protocol *shape* can be pinned: every event name the
/// JS sources emit must be a name the Dart switch handles, and every handled
/// name must actually be emitted — otherwise a rename or a new name on one
/// side drifts silently into the switch's logged default branch.
void main() {
  // Every Dart-reachable JS source that can call `flutter_inappwebview
  // .callHandler`. The bridge's play scripts embed the shared
  // `_startPlaybackBody`, so `playRejected` is included via interpolation.
  final jsSources = [
    kYoutubeMobileWatchInjectScript,
    YoutubeWebViewBridge.playScript,
    YoutubeWebViewBridge.playOrPauseScript,
  ].join('\n===\n');

  /// All handler names the JS side calls, e.g. `callHandler('onVideoEvent',…)`.
  final jsCalledHandlers = RegExp(
    r"callHandler\(\s*'([A-Za-z]+)'",
  ).allMatches(jsSources).map((m) => m.group(1)!).toSet();

  /// Event names emitted with a literal second argument.
  final literalEventNames = RegExp(
    r"callHandler\(\s*'onVideoEvent'\s*,\s*'([a-zA-Z]+)'",
  ).allMatches(jsSources).map((m) => m.group(1)!).toSet();

  /// `hookVideo` emits through a variable: `var events=['play',…]` later
  /// forwarded as `callHandler('onVideoEvent',args[0],…)`.
  final arrayEventNames = RegExp(r'var events=\[([^\]]*)\]')
      .allMatches(jsSources)
      .expand((m) {
        return RegExp(
          r"'([a-zA-Z]+)'",
        ).allMatches(m.group(1)!).map((inner) => inner.group(1)!);
      })
      .toSet();

  test('every event name the JS emits is a name the Dart switch handles', () {
    final emitted = {...literalEventNames, ...arrayEventNames};
    // Sanity on the extraction itself: the known emission styles must all
    // have been found before the comparison means anything.
    expect(literalEventNames, containsAll(<String>['playRejected', 'ended']));
    expect(arrayEventNames, isNotEmpty);

    final unhandled = emitted.difference(YoutubeVideoEventName.all);
    expect(
      unhandled,
      isEmpty,
      reason:
          'JS emits ${unhandled.toList()} but the Dart switch has no case '
          '(it would hit the logged default and vanish).',
    );
  });

  test(
    'every event name the Dart switch handles is actually emitted by the JS',
    () {
      final emitted = {...literalEventNames, ...arrayEventNames};
      final dead = YoutubeVideoEventName.all.difference(emitted);
      expect(
        dead,
        isEmpty,
        reason:
            'Dart handles ${dead.toList()} but no JS source emits them — '
            'dead protocol entries.',
      );
    },
  );

  test('handler names called from JS match the handlers Dart registers', () {
    final unregistered = jsCalledHandlers.difference(YoutubeJsHandlerName.all);
    expect(
      unregistered,
      isEmpty,
      reason:
          'JS calls ${unregistered.toList()} but '
          'YoutubeWebViewController never registers them.',
    );
    final neverCalled = YoutubeJsHandlerName.all.difference(jsCalledHandlers);
    expect(
      neverCalled,
      isEmpty,
      reason: 'Dart registers ${neverCalled.toList()} but no JS calls them.',
    );
  });
}
