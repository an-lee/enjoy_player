/// Injected on each YouTube mobile watch [onLoadStop] to hide chrome and hook events.
library;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String kYoutubeMobileWatchInjectScript = r'''
(function(){
  // [onLoadStop] can run more than once (OAuth return, soft reloads). A second
  // inject stacks intervals + duplicate media listeners → spurious pause/sync.
  if(window.__enjoyYtMwc){return;}
  window.__enjoyYtMwc=1;

  function mainVideo(){
    var p=document.querySelector('.html5-video-player');
    if(!p) return document.querySelector('video');
    return p.querySelector('video')||document.querySelector('video');
  }

  var v=null;       // current hooked <video>
  var player=null;  // .html5-video-player container
  var mids=[];      // elements between player and <video>
  var chain=[];     // ancestors from player up to <html>
  var curVid=(new URL(location.href)).searchParams.get('v')||'';

  // --- Ad tracking ---
  var wasAd=false;        // was ad showing last cycle?
  var savedTime=0;        // last known main-video position
  var reloading=false;    // are we in the middle of a reload?

  // --- Utility ---
  function isAd(){
    return player && player.classList.contains('ad-showing');
  }

  function enableInlinePlayback(video){
    video.setAttribute('playsinline','');
    video.setAttribute('webkit-playsinline','');
    video.playsInline=true;
    if(typeof video.webkitSetPresentationMode==='function'){
      try{video.webkitSetPresentationMode('inline');}catch(e){}
    }
  }

  function installInlineGuards(){
    if(window.__enjoyYtInlineGuards){return;}
    window.__enjoyYtInlineGuards=1;
    var style=document.createElement('style');
    style.id='__enjoyYtInlineStyle';
    style.textContent=[
      '.ytp-fullscreen-button,.ytp-size-button,.fullscreen-icon',
      '{display:none!important;pointer-events:none!important;}',
      'button[aria-label*="Fullscreen"],button[aria-label*="全屏"]',
      '{display:none!important;pointer-events:none!important;}',
      // Captions must never render — app transcripts are the only caption
      // source (see docs/features/youtube.md). YouTube toggles these on by
      // default for some videos (auto-captions / saved viewer prefs), and
      // since the native control bar is hidden there is no way to turn them
      // off from the page itself.
      '.ytp-caption-window-container,.caption-window,',
      '.ytp-caption-window-bottom,.ytp-caption-window-top,',
      '.ytp-caption-window-rollup,.ytp-caption-segment,',
      '.player-captions-container,.captions-text',
      '{display:none!important;visibility:hidden!important;',
      'pointer-events:none!important;opacity:0!important;}'
    ].join('');
    document.head.appendChild(style);
  }

  // --- Never let native <track>-based captions render either ---
  function disableTextTracks(video){
    if(!video||!video.textTracks) return;
    try{
      for(var i=0;i<video.textTracks.length;i++){
        video.textTracks[i].mode='disabled';
      }
    }catch(e){}
  }

  var captionSel='.ytp-caption-window-container,.caption-window,'+
    '.ytp-caption-window-bottom,.ytp-caption-window-top,'+
    '.ytp-caption-window-rollup,.ytp-caption-segment,'+
    '.player-captions-container,.captions-text';

  // Re-apply inline hide — YouTube sometimes sets competing inline styles
  // that outrank a one-shot <style> rule after track changes.
  function hideCaptionDom(){
    var root=player||document;
    var nodes=root.querySelectorAll
      ? root.querySelectorAll(captionSel)
      : [];
    for(var i=0;i<nodes.length;i++){
      nodes[i].style.setProperty('display','none','important');
      nodes[i].style.setProperty('visibility','hidden','important');
      nodes[i].style.setProperty('opacity','0','important');
      nodes[i].style.setProperty('pointer-events','none','important');
    }
  }

  // Turn off YouTube's own captions module when the player API is available
  // (watch-page #movie_player / .html5-video-player). CSS alone can miss
  // transient overlays / language pickers that sit outside caption nodes.
  // Only hit the player API when caption DOM is present so we do not spam
  // unloadModule every enforce tick.
  function disableYoutubeCaptions(){
    if(isAd()) return;
    var p=player||document.querySelector('.html5-video-player');
    if(!p) return;
    var hasCaptionDom=!!(
      p.querySelector(captionSel)||
      document.querySelector('.ytp-caption-window-container,.caption-window')
    );
    if(!hasCaptionDom && typeof p.getOption!=='function') return;
    if(!hasCaptionDom){
      try{
        var track=p.getOption('captions','track');
        if(!track||!track.languageCode) return;
      }catch(e){return;}
    }
    try{
      if(typeof p.unloadModule==='function'){
        p.unloadModule('captions');
        p.unloadModule('cc');
      }
    }catch(e){}
    try{
      if(typeof p.setOption==='function'){
        p.setOption('captions','track',{});
        p.setOption('cc','track',{});
      }
    }catch(e){}
  }

  // --- Attach event hooks to a <video> element ---
  function hookVideo(video){
    enableInlinePlayback(video);
    disableTextTracks(video);
    disableYoutubeCaptions();
    video.addEventListener('webkitbeginfullscreen',function(){
      if(typeof video.webkitSetPresentationMode==='function'){
        try{video.webkitSetPresentationMode('inline');}catch(e){}
      }
    },true);
    var events=['play','playing','pause','ended',
                'waiting','canplay','error','loadedmetadata'];
    events.forEach(function(e){
      video.addEventListener(e,function(){
        // Ad playback must not drive Dart transport (playing/pause/polling).
        if(isAd()) return;
        var args=[e];
        if(e==='loadedmetadata') args.push(video.duration||0);
        if(e==='pause') args.push(pauseContext(video));
        window.flutter_inappwebview.callHandler(
          'onVideoEvent',args[0],args.length>1?args[1]:null);
      });
    });
  }

  // Page-side state at the moment of a pause — the Dart side cannot ask the
  // page WHY it paused (a DOM pause carries no initiator), so every pause
  // ships its context for diagnostic logs: page-corrected pauses (the
  // play-then-pause bug class) correlate with hidden/unfocused documents or
  // a specific page-player state.
  function pauseContext(video){
    var ps='?';
    try{
      var p=document.querySelector('#movie_player');
      if(p&&typeof p.getPlayerState==='function') ps=p.getPlayerState();
    }catch(e){}
    var vis='?';
    try{vis=document.visibilityState;}catch(e){}
    var foc='?';
    try{foc=document.hasFocus()?'1':'0';}catch(e){}
    var muted='?';
    try{muted=video.muted?'1':'0';}catch(e){}
    return 'vis='+vis+' foc='+foc+' muted='+muted+' pstate='+ps;
  }

  // --- Sync current video state to Dart ---
  function syncState(video){
    if(!video||isAd()) return;
    if(video.readyState>=1){
      window.flutter_inappwebview.callHandler(
        'onVideoEvent','loadedmetadata',video.duration||0);
    }
    if(!video.paused && !video.ended){
      window.flutter_inappwebview.callHandler('onVideoEvent','playing');
    }else if(video.ended){
      window.flutter_inappwebview.callHandler('onVideoEvent','ended');
    }else{
      window.flutter_inappwebview.callHandler(
        'onVideoEvent','pause',pauseContext(video));
    }
  }

  // --- Rebuild mids array for current video ---
  function rebuildMids(){
    mids=[];
    if(!v||!player) return;
    var tmp=v.parentElement;
    while(tmp && tmp!==player){mids.push(tmp);tmp=tmp.parentElement;}
  }

  // --- Enforce layout + detect video swap + ad transition ---
  function enforce(){
    if(reloading) return;

    var adNow=isAd();
    if(!adNow && v && isFinite(v.currentTime) && v.currentTime>0){
      savedTime=v.currentTime;
    }

    if(!wasAd && adNow){
      wasAd=true;
    } else if(wasAd && !adNow){
      wasAd=false;
      reloading=true;
      window.flutter_inappwebview.callHandler('onAdReload',savedTime);
      window.flutter_inappwebview.callHandler('onVideoEvent','waiting');
      var url='https://m.youtube.com/watch?v='+curVid+(Math.floor(savedTime)>0?'&t='+Math.floor(savedTime)+'s':'');
      location.href=url;
      return;
    }

    var currentV=mainVideo();
    if(currentV && currentV!==v){
      v=currentV;
      hookVideo(v);
      rebuildMids();
      enableInlinePlayback(v);
      v.autoplay=false;
      v.removeAttribute('autoplay');
      v.loop=false;
      setTimeout(function(){syncState(v);},200);
    }
    if(!v) return;

    enableInlinePlayback(v);
    disableTextTracks(v);
    hideCaptionDom();
    disableYoutubeCaptions();

    var de=document.documentElement;
    de.style.setProperty('overflow','hidden','important');
    de.style.setProperty('background','#000','important');
    var b=document.body;
    b.style.setProperty('margin','0','important');
    b.style.setProperty('padding','0','important');
    b.style.setProperty('overflow','hidden','important');
    b.style.setProperty('background','#000','important');

    if(player){
      player.style.setProperty('position','fixed','important');
      player.style.setProperty('top','0','important');
      player.style.setProperty('left','0','important');
      player.style.setProperty('width','100vw','important');
      player.style.setProperty('height','100vh','important');
      player.style.setProperty('z-index','999999','important');
      player.style.setProperty('overflow','hidden','important');
      player.style.setProperty('background','#000','important');
      player.style.setProperty('margin','0','important');
      player.style.setProperty('padding','0','important');
      player.style.setProperty('transform','none','important');
      player.style.setProperty('display','block','important');
      player.style.setProperty('visibility','visible','important');
      player.style.setProperty('opacity','1','important');
    }

    mids.forEach(function(el){
      el.style.setProperty('width','100%','important');
      el.style.setProperty('height','100%','important');
      el.style.setProperty('display','block','important');
      el.style.setProperty('visibility','visible','important');
      el.style.setProperty('opacity','1','important');
      el.style.setProperty('position','absolute','important');
      el.style.setProperty('top','0','important');
      el.style.setProperty('left','0','important');
      el.style.setProperty('overflow','hidden','important');
      el.style.setProperty('max-height','none','important');
      el.style.setProperty('max-width','none','important');
      el.style.setProperty('min-height','0','important');
      el.style.setProperty('margin','0','important');
      el.style.setProperty('padding','0','important');
      el.style.setProperty('transform','none','important');
      el.style.setProperty('background','#000','important');
    });

    v.style.setProperty('width','100%','important');
    v.style.setProperty('height','100%','important');
    v.style.setProperty('position','absolute','important');
    v.style.setProperty('top','0','important');
    v.style.setProperty('left','0','important');
    v.style.setProperty('display','block','important');
    v.style.setProperty('visibility','visible','important');
    v.style.setProperty('object-fit','contain','important');
    v.style.setProperty('margin','0','important');
    v.style.setProperty('padding','0','important');
    v.style.setProperty('transform','none','important');
    v.style.setProperty('background','#000','important');

    for(var i=0;i<chain.length;i++){
      var parent=chain[i].parentElement;
      if(!parent) continue;
      Array.from(parent.children).forEach(function(sib){
        if(sib===chain[i]) return;
        var tag=sib.tagName;
        if(tag==='STYLE'||tag==='SCRIPT'||tag==='LINK'
           ||tag==='META'||tag==='HEAD') return;
        sib.style.setProperty('display','none','important');
      });
    }
  }

  function setup(){
    v=mainVideo();
    if(!v){setTimeout(setup,300);return;}

    player=v.closest('.html5-video-player')||v.parentElement;
    rebuildMids();

    chain=[];
    var tmp=player;
    while(tmp){chain.push(tmp);tmp=tmp.parentElement;}

    installInlineGuards();
    enforce();
    setInterval(enforce,300);

    v.autoplay=false;
    v.removeAttribute('autoplay');
    v.loop=false;

    hookVideo(v);

    var origPush=history.pushState.bind(history);
    var origReplace=history.replaceState.bind(history);
    history.pushState=function(s,t,u){
      if(u && typeof u==='string' && u.indexOf('/watch')>=0){
        try{
          var nv=(new URL(u,location.href)).searchParams.get('v');
          if(nv && nv!==curVid) return;
        }catch(e){}
      }
      origPush(s,t,u);
    };
    history.replaceState=function(s,t,u){
      if(u && typeof u==='string' && u.indexOf('/watch')>=0){
        try{
          var nv=(new URL(u,location.href)).searchParams.get('v');
          if(nv && nv!==curVid) return;
        }catch(e){}
      }
      origReplace(s,t,u);
    };

    syncState(v);
  }
  setup();
})();
''';

Future<void> injectYoutubeMobileWatchPage(InAppWebViewController controller) {
  return controller.evaluateJavascript(source: kYoutubeMobileWatchInjectScript);
}
