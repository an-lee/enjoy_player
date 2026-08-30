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

    test(
      'play scripts never touch mute state (play-then-pause regression guard)',
      () {
        // Chromium's autoplay gesture lock pauses an element that becomes
        // audible without user activation. A forced muted start here is
        // always followed by a programmatic unmute in the volume-restore
        // path — the exact play→pause sequence. Play must preserve the
        // current audible state; only setVolumeScript may flip audibility.
        for (final script in [
          YoutubeWebViewBridge.playScript,
          YoutubeWebViewBridge.playOrPauseScript,
        ]) {
          expect(script, isNot(matches(RegExp('mute', caseSensitive: false))));
        }
      },
    );

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
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('v.play()'));
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('v.pause()'));
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('playRejected'));
    });

    test(
      'playOrPauseScript reports the DOM-decided direction (D9 contract)',
      () {
        // The engine classifies toggle intent from this return value — never
        // from stale session playing state. A dropped or renamed return
        // silently reverts intent classification to a guess.
        expect(
          YoutubeWebViewBridge.playOrPauseScript,
          contains("return 'play';"),
        );
        expect(
          YoutubeWebViewBridge.playOrPauseScript,
          contains("return 'pause';"),
        );
        expect(
          YoutubeWebViewBridge.playOrPauseScript,
          contains('if(!v) return null;'),
        );
      },
    );

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
      }
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('mp.pauseVideo'));
      expect(YoutubeWebViewBridge.playOrPauseScript, contains('mp.isPaused'));
    });
  });

  group('playWhenReadyScript', () {
    test('gates the play on data readiness with a bounded wait', () {
      // Buffer exhaustion was the dominant immediate-pause cause (field
      // rounds 3–5: pause ctx pstate=3, decoder input ~10× slower than
      // realtime); an unconditional re-play just re-exhausts the buffer.
      final script = YoutubeWebViewBridge.playWhenReadyScript;
      expect(script, contains('v.readyState>=3'));
      expect(script, contains('ahead()>=1'));
      expect(script, contains('tries++>20'));
      // Superseded by any newer transport command (stale-guard protocol).
      expect(script, contains('__enjoyYtPlayAttempt'));
      // Routes through the page player when available.
      expect(script, contains('mp.playVideo()'));
    });
  });

  group('focusWindowScript', () {
    test('pins document focus and dispatches a synthetic focus event', () {
      // The page player pauses programmatic playback while the document
      // reports unfocused (field: every wedge pause carries ctx foc=0 with
      // vis=visible). Parking (ADR-0066) can clear the WebView's view
      // focus and the plugin has no requestFocus — the page signal is the
      // only lever. A dropped patch or event silently re-opens the
      // play-then-pause wedge.
      final script = YoutubeWebViewBridge.focusWindowScript;
      expect(script, contains('document.hasFocus=function(){return true;}'));
      expect(script, contains("window.dispatchEvent(new Event('focus'))"));
    });
  });

  group('pauseScript / stopScript', () {
    test('pause routes through the page player with element fallback', () {
      expect(YoutubeWebViewBridge.pauseScript, contains('#movie_player'));
      expect(YoutubeWebViewBridge.pauseScript, contains('mp.pauseVideo()'));
      expect(YoutubeWebViewBridge.pauseScript, contains('v.pause()'));
    });

    test('pause bumps the play-attempt counter (stale rejection guard)', () {
      // A pause must invalidate any in-flight play attempt's rejection
      // callback, or a late play error could surface after the pause won.
      expect(
        YoutubeWebViewBridge.pauseScript,
        contains('__enjoyYtPlayAttempt'),
      );
    });

    test('stop is the pause body plus a position reset', () {
      expect(YoutubeWebViewBridge.stopScript, contains('mp.pauseVideo()'));
      expect(YoutubeWebViewBridge.stopScript, contains('v.currentTime=0;'));
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

    test('exits without mutation when element state already matches', () {
      // Redundant unMutes are pause triggers under the autoplay gesture
      // lock; the script must early-return on a no-op request.
      final script = YoutubeWebViewBridge.setVolumeScript(1.0);
      expect(script, contains('stateMatches'));
      expect(script, contains('if(stateMatches) return;'));
    });
  });
}
