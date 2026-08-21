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

  /// Muted-play body shared by [playScript] and [playOrPauseScript]. Mutes
  /// through the page player when possible so the page's own volume state
  /// stays consistent; falls back to element `muted` for pages without the
  /// player API.
  static const String _mutedPlayBody = '''
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
        try{
          if(typeof mp.mute==='function') mp.mute();
          else mp.setVolume(0);
        }catch(e){}
        try{mp.playVideo();}catch(e){}
      } else {
        v.muted=true;
        try{
          var result=v.play();
          if(result&&typeof result.catch==='function') result.catch(rejected);
        }catch(error){rejected(error);}
      }
  ''';

  static const String playScript =
      '''
    (function(){
      $_findVideoAndPlayer
      if(!v) return;
      $_mutedPlayBody
    })();
  ''';

  /// Atomic toggle based on the live `<video>` element — never trusts Dart
  /// [YoutubeSession.playing], which can lag DOM pauses by hundreds of ms.
  /// State changes are applied through the page player when available.
  static const String playOrPauseScript =
      '''
    (function(){
      $_findVideoAndPlayer
      if(!v) return;
      var paused=v.paused||v.ended;
      if(mp&&typeof mp.isPaused==='function'){
        try{paused=!!mp.isPaused();}catch(e){}
      }
      if(paused){
        $_mutedPlayBody
      } else {
        window.__enjoyYtPlayAttempt=(window.__enjoyYtPlayAttempt||0)+1;
        if(mp){try{mp.pauseVideo();}catch(e){}}
        else{v.pause();}
      }
    })();
  ''';

  static Future<void> play(InAppWebViewController? web) async {
    await web?.evaluateJavascript(source: playScript);
  }

  /// Play when the DOM video is paused/ended; pause when it is playing.
  static Future<void> playOrPause(InAppWebViewController? web) async {
    await web?.evaluateJavascript(source: playOrPauseScript);
  }

  static Future<void> pause(InAppWebViewController? web) async {
    await web?.evaluateJavascript(
      source:
          '''
        (function(){
          $_findVideoAndPlayer
          window.__enjoyYtPlayAttempt=(window.__enjoyYtPlayAttempt||0)+1;
          if(mp){try{mp.pauseVideo();}catch(e){}}
          else if(v){v.pause();}
        })();
      ''',
    );
  }

  static Future<void> pauseVideoElement(InAppWebViewController? web) async {
    await web?.evaluateJavascript(
      source:
          '''
        (function(){
          $_findVideoAndPlayer
          window.__enjoyYtPlayAttempt=(window.__enjoyYtPlayAttempt||0)+1;
          if(mp){try{mp.pauseVideo();}catch(e){}}
          else if(v){v.pause();}
        })();
      ''',
    );
  }

  static Future<void> seekToSeconds(
    InAppWebViewController? web,
    double seconds,
  ) async {
    await web?.evaluateJavascript(
      source:
          '''
        (function(){
          var p=document.querySelector('.html5-video-player');
          var v=p?p.querySelector('video'):null;
          if(!v) v=document.querySelector('video');
          if(v) v.currentTime=$seconds;
        })();
      ''',
    );
  }

  static Future<void> stop(InAppWebViewController? web) async {
    await web?.evaluateJavascript(
      source:
          '''
        (function(){
          $_findVideoAndPlayer
          window.__enjoyYtPlayAttempt=(window.__enjoyYtPlayAttempt||0)+1;
          if(mp){try{mp.pauseVideo();}catch(e){}}
          else if(v){v.pause();}
          if(v){v.currentTime=0;}
        })();
      ''',
    );
  }

  static Future<void> setPlaybackRate(
    InAppWebViewController? web,
    double speed,
  ) async {
    await web?.evaluateJavascript(
      source:
          '''
        (function(){
          var p=document.querySelector('.html5-video-player');
          var v=p?p.querySelector('video'):null;
          if(!v) v=document.querySelector('video');
          if(v) v.playbackRate=$speed;
        })();
      ''',
    );
  }

  /// Volume/mute script. Prefers the page player API (`unMute` / `mute` /
  /// `setVolume` 0-100) so unmute does not fight YouTube's gesture-gated
  /// autoplay policy; element mutation is only the no-API fallback.
  static String setVolumeScript(double volume) =>
      '''
        (function(){
          $_findVideoAndPlayer
          var vol=$volume;
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
      source: '''
        (function(){
          var p=document.querySelector('.html5-video-player');
          var v=p?p.querySelector('video'):null;
          if(!v) v=document.querySelector('video');
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
