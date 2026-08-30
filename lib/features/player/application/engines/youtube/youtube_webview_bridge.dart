/// JS snippets and URL helpers for [YouTubePlayerEngine].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Shared by player + login WebViews — Google/YouTube reject default WKWebView UAs.
const String kYoutubeMobileChromeUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/134.0.0.0 Mobile Safari/537.36';

/// WebView settings for YouTube player and sign-in (keep UA aligned).
class YoutubeWebViewSettings {
  YoutubeWebViewSettings._();

  static InAppWebViewSettings forPlayer() {
    return InAppWebViewSettings(
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      allowsPictureInPictureMediaPlayback:
          defaultTargetPlatform == TargetPlatform.iOS ? false : null,
      javaScriptEnabled: true,
      transparentBackground: true,
      useWideViewPort: true,
      loadWithOverviewMode: true,
      userAgent: kYoutubeMobileChromeUserAgent,
      thirdPartyCookiesEnabled: true,
      // Required on Android/iOS/macOS/Windows for [shouldOverrideUrlLoading] (ADR-0025).
      useShouldOverrideUrlLoading: true,
      // Android: allow listening for renderer crashes (reload watch page).
      useOnRenderProcessGone: defaultTargetPlatform == TargetPlatform.android
          ? true
          : null,
    );
  }

  static InAppWebViewSettings forLogin() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      thirdPartyCookiesEnabled: true,
      userAgent: kYoutubeMobileChromeUserAgent,
      useShouldOverrideUrlLoading: true,
    );
  }
}

class YoutubeWebViewBridge {
  YoutubeWebViewBridge._();

  static WebUri get idleUri => WebUri('about:blank');

  static WebUri watchUri(String videoId) =>
      WebUri('https://m.youtube.com/watch?v=$videoId');

  /// Locates the `<video>` element and YouTube's own page player object.
  ///
  /// Transport and volume commands must go through the page player
  /// (`mp.playVideo()` / `mp.unMute()` / …) whenever it is available:
  /// mutating the raw element (especially `video.muted`) behind the page's
  /// back lets its autoplay-policy/state machine re-pause the element shortly
  /// after playback starts — the play-then-pause symptom.
  static const String _findVideoAndPlayer = '''
      var p=document.querySelector('.html5-video-player');
      var v=p?p.querySelector('video'):null;
      if(!v) v=document.querySelector('video');
      var mp=document.querySelector('#movie_player')||p;
      if(!mp||typeof mp.playVideo!=='function') mp=null;
  ''';

  /// Playback-start body shared by [playScript] and [playOrPauseScript].
  ///
  /// Never muting here is the play-then-pause fix: Chromium gives each media
  /// element a gesture lock that muted starts bypass, and unmuting later
  /// without fresh user activation pauses the element ("Unmuting failed and
  /// the element was paused instead"). Every forced mute here used to be
  /// followed by a programmatic unmute in the volume-restore path, tripping
  /// exactly that rule. Starts must preserve the current audible state; only
  /// the per-document volume restore may flip audibility (see
  /// [YoutubeWebViewEvents]).
  static const String _startPlaybackBody = '''
      var attempt=(window.__enjoyYtPlayAttempt||0)+1;
      window.__enjoyYtPlayAttempt=attempt;
      function rejected(error){
        if(window.__enjoyYtPlayAttempt!==attempt) return;
        var name=error&&error.name?error.name:'UnknownError';
        var message=error&&error.message?error.message:'';
        var bridge=window.flutter_inappwebview;
        if(bridge&&typeof bridge.callHandler==='function'){
          bridge.callHandler(
            'onVideoEvent','playRejected',name+(message?': '+message:''));
        }
      }
      if(mp){
        try{mp.playVideo();}catch(e){}
      } else {
        try{
          var result=v.play();
          if(result&&typeof result.catch==='function') result.catch(rejected);
        }catch(error){rejected(error);}
      }
  ''';

  /// Pause body shared by [pauseScript], [stopScript], and the pause branch
  /// of [playOrPauseScript]. Bumping `__enjoyYtPlayAttempt` invalidates any
  /// in-flight play attempt's rejection callback (see [_startPlaybackBody]),
  /// so a stale play error cannot surface after the pause already won.
  static const String _pauseBody = '''
      window.__enjoyYtPlayAttempt=(window.__enjoyYtPlayAttempt||0)+1;
      if(mp){try{mp.pauseVideo();}catch(e){}}
      else if(v){v.pause();}
  ''';

  static const String playScript =
      '''
    (function(){
      $_findVideoAndPlayer
      if(!v) return;
      $_startPlaybackBody
    })();
  ''';

  /// Atomic toggle based on the live `<video>` element — never trusts Dart
  /// [YoutubeSession.playing], which can lag DOM pauses by hundreds of ms.
  /// State changes are applied through the page player when available.
  ///
  /// Reports the direction the DOM actually took — `'play'` / `'pause'`, or
  /// `null` when no `<video>` was found — so the caller classifies the
  /// toggle's intent from DOM truth, not from stale session state (which
  /// lags the very pause the toggle may be reacting to).
  static const String playOrPauseScript =
      '''
    (function(){
      $_findVideoAndPlayer
      if(!v) return null;
      var paused=v.paused||v.ended;
      if(mp&&typeof mp.isPaused==='function'){
        try{paused=!!mp.isPaused();}catch(e){}
      }
      if(paused){
        $_startPlaybackBody
        return 'play';
      } else {
        $_pauseBody
        return 'pause';
      }
    })();
  ''';

  /// Pause script — routes through the page player when available, falling
  /// back to the raw element (see [_findVideoAndPlayer]).
  static const String pauseScript =
      '''
    (function(){
      $_findVideoAndPlayer
      $_pauseBody
    })();
  ''';

  /// [pauseScript] plus a position reset to the start of the video.
  static const String stopScript =
      '''
    (function(){
      $_findVideoAndPlayer
      $_pauseBody
      if(v){v.currentTime=0;}
    })();
  ''';

  static Future<void> play(InAppWebViewController? web) async {
    await web?.evaluateJavascript(source: playScript);
  }

  /// Play when the DOM video is paused/ended; pause when it is playing.
  /// Returns the DOM-decided direction (`'play'` / `'pause'`) or `null`
  /// when no video was found (see [playOrPauseScript]).
  static Future<String?> playOrPause(InAppWebViewController? web) async {
    final result = await web?.evaluateJavascript(source: playOrPauseScript);
    return result is String ? result : null;
  }

  static Future<void> pause(InAppWebViewController? web) async {
    await web?.evaluateJavascript(source: pauseScript);
  }

  static Future<void> seekToSeconds(
    InAppWebViewController? web,
    double seconds,
  ) async {
    await web?.evaluateJavascript(
      source:
          '''
        (function(){
          $_findVideoAndPlayer
          if(v) v.currentTime=$seconds;
        })();
      ''',
    );
  }

  static Future<void> stop(InAppWebViewController? web) async {
    await web?.evaluateJavascript(source: stopScript);
  }

  static Future<void> setPlaybackRate(
    InAppWebViewController? web,
    double speed,
  ) async {
    await web?.evaluateJavascript(
      source:
          '''
        (function(){
          $_findVideoAndPlayer
          if(v) v.playbackRate=$speed;
        })();
      ''',
    );
  }

  /// Volume/mute script. Prefers the page player API (`unMute` / `mute` /
  /// `setVolume` 0-100) so unmute does not fight YouTube's gesture-gated
  /// autoplay policy; element mutation is only the no-API fallback.
  ///
  /// Idempotent: when the element already matches the requested state the
  /// script exits without touching anything. Every skipped `muted=false`
  /// mutation is one fewer chance for Chromium's gesture lock to pause an
  /// autoplaying-muted video ("Unmuting failed and the element was paused").
  static String setVolumeScript(double volume) =>
      '''
        (function(){
          $_findVideoAndPlayer
          var vol=$volume;
          if(v){
            var wantMuted=(vol<=0.001);
            var volDelta=(typeof v.volume==='number')?Math.abs(v.volume-vol):1;
            var stateMatches=wantMuted?(v.muted===true):(v.muted===false&&volDelta<=0.001);
            if(stateMatches) return;
          }
          if(mp){
            try{
              if(vol<=0.001){
                if(typeof mp.mute==='function'){mp.mute();}
                else{mp.setVolume(0);}
              }else{
                if(typeof mp.unMute==='function'){mp.unMute();}
                mp.setVolume(Math.round(vol*100));
              }
            }catch(e){}
            return;
          }
          if(v){v.volume=vol;v.muted=(vol<=0.001);}
        })();
      ''';

  static Future<void> setVolume(
    InAppWebViewController? web,
    double volume,
  ) async {
    await web?.evaluateJavascript(source: setVolumeScript(volume));
  }

  static Future<void> loadWatchPage(
    InAppWebViewController? web,
    String videoId,
  ) async {
    await web?.loadUrl(urlRequest: URLRequest(url: watchUri(videoId)));
  }

  static Future<void> loadIdlePage(InAppWebViewController? web) async {
    await web?.loadUrl(urlRequest: URLRequest(url: idleUri));
  }

  /// Re-applies `playsinline` on the active `<video>` (iOS WKWebView safety net).
  static Future<void> forceInlinePlayback(InAppWebViewController? web) async {
    await web?.evaluateJavascript(
      source:
          '''
        (function(){
          $_findVideoAndPlayer
          if(!v) return;
          v.setAttribute('playsinline','');
          v.setAttribute('webkit-playsinline','');
          v.playsInline=true;
          if(typeof v.webkitSetPresentationMode==='function'){
            try{v.webkitSetPresentationMode('inline');}catch(e){}
          }
        })();
      ''',
    );
  }
}
