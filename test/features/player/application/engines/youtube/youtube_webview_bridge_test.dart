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

    test('playOrPauseScript plays when paused and pauses when playing', () {
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('v.paused'));
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('v.ended'));
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('v.muted=true'));
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('v.play()'));
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('v.pause()'));
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('playRejected'));
    });

    test('play scripts route through the page player API when available', () {
      // Mutating the raw element behind the page's back lets YouTube's
      // autoplay policy re-pause the video; the page player object must win.
      for (final script in [
        YoutubeWebViewBridge.playScript,
        YoutubeWebViewBridge.playOrPauseScript,
      ]) {
        expect(script, contains('#movie_player'));
        expect(script, contains('.html5-video-player'));
        expect(script, contains('mp.playVideo()'));
        expect(script, contains('mp.mute()'));
      }
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('mp.pauseVideo'));
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('mp.isPaused'));
    });
  });

  group('setVolumeScript', () {
    test('unmute prefers the page player API over element muted=false', () {
      final script = YoutubeWebViewBridge.setVolumeScript(1.0);
      expect(script, contains('mp.unMute'));
      expect(script, contains('mp.setVolume(Math.round(vol*100))'));
      // Element mutation remains only as the no-API fallback.
      expect(script, contains('v.muted=(vol<=0.001)'));
    });

    test('zero volume mutes through the page player API', () {
      final script = YoutubeWebViewBridge.setVolumeScript(0);
      expect(script, contains('mp.mute'));
      expect(script, contains('mp.setVolume(0)'));
    });

    test('interpolates the requested volume', () {
      expect(
        YoutubeWebViewBridge.setVolumeScript(0.25),
        contains('var vol=0.25;'),
      );
    });
  });
}
