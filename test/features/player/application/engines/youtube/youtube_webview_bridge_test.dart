import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YoutubeWebViewBridge URI helpers', () {
    test('idleUri is about:blank', () {
      expect(YoutubeWebViewBridge.idleUri.toString(), 'about:blank');
    });

    test('watchUri builds m.youtube.com watch URL', () {
      expect(
        YoutubeWebViewBridge.watchUri('dQw4w9WgXcQ').toString(),
        'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    });

    test('watchUri preserves special characters in videoId', () {
      expect(
        YoutubeWebViewBridge.watchUri('abc-_123').toString(),
        'https://m.youtube.com/watch?v=abc-_123',
      );
    });

    test('watchUri with empty videoId', () {
      expect(
        YoutubeWebViewBridge.watchUri('').toString(),
        'https://m.youtube.com/watch?v=',
      );
    });
  });

  group('kYoutubeMobileChromeUserAgent', () {
    test('contains Mobile Safari and Chrome', () {
      expect(kYoutubeMobileChromeUserAgent, contains('Chrome'));
      expect(kYoutubeMobileChromeUserAgent, contains('Mobile Safari'));
      expect(kYoutubeMobileChromeUserAgent, contains('Android 14'));
    });

    test('starts with Mozilla/5.0', () {
      expect(kYoutubeMobileChromeUserAgent, startsWith('Mozilla/5.0'));
    });
  });

  group('YoutubeWebViewBridge JS snippets', () {
    test('playScript contains video.play() invocation', () {
      expect(YoutubeWebViewBridge.playScript, contains('v.play()'));
    });

    test('playScript reports rejection via onVideoEvent handler', () {
      expect(YoutubeWebViewBridge.playScript, contains("'onVideoEvent'"));
      expect(YoutubeWebViewBridge.playScript, contains('playRejected'));
    });

    test('playScript sets muted=true before play', () {
      // The script mutes first to bypass autoplay gesture requirements.
      expect(YoutubeWebViewBridge.playScript, contains('v.muted=true'));
    });

    test(
      'playScript uses __enjoyYtPlayAttempt counter for stale rejection',
      () {
        expect(
          YoutubeWebViewBridge.playScript,
          contains('__enjoyYtPlayAttempt'),
        );
      },
    );
  });
}
