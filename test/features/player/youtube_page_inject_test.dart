import 'package:enjoy_player/features/player/application/engines/youtube/youtube_page_inject.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YoutubeWebViewBridge play script', () {
    test('preserves audible state and reports rejected play promises', () {
      // Forced muted starts are banned: the later programmatic unmute trips
      // Chromium's gesture lock and pauses playback (play-then-pause).
      expect(
        YoutubeWebViewBridge.playScript,
        isNot(matches(RegExp('mute', caseSensitive: false))),
      );
      expect(
        YoutubeWebViewBridge.playScript,
        contains("'onVideoEvent','playRejected'"),
      );
      expect(YoutubeWebViewBridge.playScript, contains('.catch(rejected)'));
    });
  });

  group('kYoutubeMobileWatchInjectScript playback', () {
    test('does not force unmute before playback is confirmed', () {
      expect(kYoutubeMobileWatchInjectScript, isNot(contains('muted=false')));
      expect(kYoutubeMobileWatchInjectScript, isNot(contains('volume=1')));
    });
  });

  group('kYoutubeMobileWatchInjectScript captions', () {
    test('force-hides YouTube native caption/subtitle DOM via CSS', () {
      expect(
        kYoutubeMobileWatchInjectScript,
        contains('.ytp-caption-window-container'),
      );
      expect(
        kYoutubeMobileWatchInjectScript,
        contains('display:none!important;visibility:hidden!important;'),
      );
    });

    test('disables native <track>-based textTracks on hook and enforce', () {
      expect(
        kYoutubeMobileWatchInjectScript,
        contains('function disableTextTracks(video)'),
      );
      expect(
        kYoutubeMobileWatchInjectScript,
        contains("video.textTracks[i].mode='disabled';"),
      );

      final hookVideoBody = kYoutubeMobileWatchInjectScript.substring(
        kYoutubeMobileWatchInjectScript.indexOf('function hookVideo(video){'),
        kYoutubeMobileWatchInjectScript.indexOf('function syncState(video){'),
      );
      expect(hookVideoBody, contains('disableTextTracks(video);'));

      final enforceBody = kYoutubeMobileWatchInjectScript.substring(
        kYoutubeMobileWatchInjectScript.indexOf('function enforce(){'),
        kYoutubeMobileWatchInjectScript.indexOf('function setup(){'),
      );
      expect(enforceBody, contains('disableTextTracks(v);'));
    });

    test('unloads YouTube captions/cc modules via player API', () {
      expect(
        kYoutubeMobileWatchInjectScript,
        contains('function disableYoutubeCaptions()'),
      );
      expect(
        kYoutubeMobileWatchInjectScript,
        contains("p.unloadModule('captions')"),
      );
      expect(
        kYoutubeMobileWatchInjectScript,
        contains("p.setOption('captions','track',{})"),
      );

      final enforceBody = kYoutubeMobileWatchInjectScript.substring(
        kYoutubeMobileWatchInjectScript.indexOf('function enforce(){'),
        kYoutubeMobileWatchInjectScript.indexOf('function setup(){'),
      );
      expect(enforceBody, contains('hideCaptionDom();'));
      expect(enforceBody, contains('disableYoutubeCaptions();'));
    });
  });
}
