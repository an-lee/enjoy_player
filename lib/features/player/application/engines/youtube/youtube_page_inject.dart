/// Injected on each YouTube mobile watch [onLoadStop] to hide chrome and hook events.
library;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String kYoutubeMobileWatchInjectScript = r'''
(function(){
  // [onLoadStop] can run more than once (OAuth return, soft reloads). A second
  // inject stacks intervals + duplicate media listeners → spurious pause/sync.
  if(window.__enjoyYtMwc){return;}
  window.__enjoyYtMwc=1;

  // --- Focus pin ---
  // The embedding app parks this WebView off-corner for overlays (ADR-0066)
  // by translation only (size is preserved — a 320×180 shrink was itself
  // a pause stimulus). Android can still clear the view's focus in ways
  // the app cannot restore (the webview plugin exposes clearFocus but no
  // requestFocus). When the document reports itself unfocused, m.youtube.com's
  // player "corrects" programmatic playback back to paused within ~300-700 ms.
  // This page is an embedded, chrome-less player; nothing here legitimately
  // needs a focus signal, so pin it focused and dispatch a synthetic focus
  // event for page code that cached an unfocused flag from an earlier blur.
  // Dart re-asserts this on a real stage-size change and before each
  // automatic play retry (see YoutubeWebViewBridge.focusWindowScript).
  try{document.hasFocus=function(){return true;};}catch(e){}
  try{window.dispatchEvent(new Event('focus'));}catch(e){}

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

  // --- Reactive enforcement ---
  var enforcePending=false;  // a coalesced sweep is already queued

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

  // --- Write-once styling (issue #662) ---
  // Every element this script styles is stamped, and a stamped element is
  // never re-written unless its block has actually been undone: the property
  // blocks below are constants, so re-writing an intact one only invalidates
  // layout. This is what makes a reactive sweep cheap — a settled DOM costs a
  // handful of expando + CSS reads instead of ~40 !important property writes.
  var STAMP='__enjoyYtStyled';

  // [mark] is one property of the block, read back on later sweeps. Our
  // declarations are !important, so a page write to the same property loses
  // the cascade; only a removal or a wholesale style-attribute rewrite can
  // undo us, and that is exactly what a cleared [mark] detects. One property
  // read per element per sweep replaces the old 300 ms unconditional rewrite.
  function styleOnce(el,props,mark){
    if(!el) return;
    if(el[STAMP]){
      if(!mark) return;
      try{
        if(el.style.getPropertyValue(mark)===props[mark]) return;
      }catch(e){return;}
    }
    el[STAMP]=1;
    for(var k in props){
      if(Object.prototype.hasOwnProperty.call(props,k)){
        el.style.setProperty(k,props[k],'important');
      }
    }
  }

  // Re-apply inline hide — YouTube sometimes sets competing inline styles
  // that outrank a one-shot <style> rule after track changes. Fresh caption
  // nodes are unstamped, so each new window is hidden on the sweep that
  // observes it. The <style> rule in [installInlineGuards] is the other
  // backstop.
  function hideCaptionDom(){
    var root=player||document;
    var nodes=root.querySelectorAll
      ? root.querySelectorAll(captionSel)
      : [];
    for(var i=0;i<nodes.length;i++){
      styleOnce(nodes[i],{
        display:'none',
        visibility:'hidden',
        opacity:'0',
        'pointer-events':'none'
      },'display');
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
    // Position sampler for the ad hand-off (issue #662): [savedTime] used to
    // be refreshed by the same 300 ms tick that ran the layout pass, so with
    // that tick gone it needs a driver of its own. `timeupdate` (~4 Hz while
    // playing) is free — page-local, no Dart round-trip. Deliberately NOT in
    // [events]: it must never reach the Dart transport switch.
    video.addEventListener('timeupdate',function(){
      if(isAd()) return;
      if(isFinite(video.currentTime)&&video.currentTime>0){
        savedTime=video.currentTime;
      }
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
    // Starvation evidence (field round 5): a page pause with pstate=3
    // (buffering), readyState < 3 and ~0 s buffered ahead is buffer
    // exhaustion, not a policy pause — the retries must wait for data.
    var rs='?';
    try{rs=video.readyState;}catch(e){}
    var buf='?';
    try{
      buf='0';
      for(var i=0;i<video.buffered.length;i++){
        if(video.buffered.start(i)<=video.currentTime&&
           video.currentTime<video.buffered.end(i)){
          buf=(video.buffered.end(i)-video.currentTime).toFixed(1);
          break;
        }
      }
    }catch(e){}
    var vol='?';
    try{vol=(video.volume==null?'?':video.volume);}catch(e){}
    return 'vis='+vis+' foc='+foc+' muted='+muted+' vol='+vol+
           ' pstate='+ps+' rs='+rs+' buf='+buf;
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

  // --- Reactive layout enforcement (issue #662) ---
  // The heavy pass below used to run on a 300 ms interval for as long as the
  // document lived: ~40 !important property writes across document / body /
  // player / mids / video, a querySelectorAll sweep and the ancestor sibling
  // scan — against a DOM that is settled a second after load. That is
  // continuous style + layout invalidation inside the WebView for a whole
  // session, for zero information. The pass now runs once per DOM shape and
  // is re-run reactively (see [installLayoutObservers]); [STAMP] is the
  // idempotence early-exit that keeps each reactive sweep cheap.

  // Structural churn anywhere in the document: YouTube injecting overlays,
  // caption windows or a rebuilt player, and any new sibling that the
  // ancestor scan must hide.
  // Attribute churn is watched on the pinned elements ONLY (subtree:false):
  // the progress bar and spinner inside the player rewrite style every
  // frame and must never schedule a sweep. `ad-showing` is a class on the
  // player container, so an ad transition rides this same record — the
  // ad-detection cadence is the observer, not a timer.
  var mo=null;

  function observeLayoutTargets(){
    if(!mo) return;
    mo.disconnect();
    try{
      mo.observe(document.documentElement,
                 {childList:true,subtree:true,attributes:false});
    }catch(e){}
    var pinned=[];
    if(player) pinned.push(player);
    if(v) pinned.push(v);
    for(var i=0;i<mids.length;i++){pinned.push(mids[i]);}
    for(i=0;i<pinned.length;i++){
      try{
        mo.observe(pinned[i],{
          childList:false,
          subtree:false,
          attributes:true,
          attributeFilter:['class','style']
        });
      }catch(e){}
    }
  }

  function installLayoutObservers(){
    if(typeof MutationObserver!=='function') return;
    try{mo=new MutationObserver(scheduleEnforce);}catch(e){mo=null;return;}
    observeLayoutTargets();
  }

  // Coalesce a mutation burst into one sweep. A plain short timer, not
  // requestAnimationFrame: rAF stops firing for a hidden/backgrounded view,
  // and this page is exactly the surface that gets parked (ADR-0066) — the
  // ad transition it would delay is the one we least want to miss.
  function scheduleEnforce(){
    if(enforcePending||reloading) return;
    enforcePending=true;
    setTimeout(function(){
      enforcePending=false;
      enforce();
    },50);
  }

  function applyLayout(){
    styleOnce(document.documentElement,
              {overflow:'hidden',background:'#000'},'overflow');
    styleOnce(document.body,
              {margin:'0',padding:'0',overflow:'hidden',background:'#000'},
              'margin');

    if(player){
      styleOnce(player,{
        position:'fixed',
        top:'0',
        left:'0',
        width:'100vw',
        height:'100vh',
        'z-index':'999999',
        overflow:'hidden',
        background:'#000',
        margin:'0',
        padding:'0',
        transform:'none',
        display:'block',
        visibility:'visible',
        opacity:'1'
      },'position');
    }

    mids.forEach(function(el){
      styleOnce(el,{
        width:'100%',
        height:'100%',
        display:'block',
        visibility:'visible',
        opacity:'1',
        position:'absolute',
        top:'0',
        left:'0',
        overflow:'hidden',
        'max-height':'none',
        'max-width':'none',
        'min-height':'0',
        margin:'0',
        padding:'0',
        transform:'none',
        background:'#000'
      },'min-height');
    });

    if(v){
      styleOnce(v,{
        width:'100%',
        height:'100%',
        position:'absolute',
        top:'0',
        left:'0',
        display:'block',
        visibility:'visible',
        'object-fit':'contain',
        margin:'0',
        padding:'0',
        transform:'none',
        background:'#000'
      },'object-fit');
    }

    for(var i=0;i<chain.length;i++){
      var parent=chain[i].parentElement;
      if(!parent) continue;
      Array.from(parent.children).forEach(function(sib){
        if(sib===chain[i]) return;
        var tag=sib.tagName;
        if(tag==='STYLE'||tag==='SCRIPT'||tag==='LINK'
           ||tag==='META'||tag==='HEAD') return;
        styleOnce(sib,{display:'none'},'display');
      });
    }
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
      // The swapped <video> and its wrappers are new elements: re-point the
      // attribute observer at them before the next sweep.
      observeLayoutTargets();
      setTimeout(function(){syncState(v);},200);
    }
    if(!v) return;

    enableInlinePlayback(v);
    disableTextTracks(v);
    hideCaptionDom();
    disableYoutubeCaptions();

    applyLayout();
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
    installLayoutObservers();

    // Belt-and-braces only — the observers carry enforcement (see
    // [installLayoutObservers]). One sweep a second costs a pass of expando
    // reads because of [STAMP], where the 300 ms full rewrite this replaced
    // invalidated layout for the whole session. It is also the only driver
    // on a WebView without MutationObserver, and the last resort for a style
    // overwrite on an element the attribute observer does not pin.
    setInterval(enforce,1000);

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
