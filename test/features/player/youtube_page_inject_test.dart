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

  // Issue #662: the enforcement used to be a `setInterval(enforce, 300)`
  // rewrite of ~40 !important properties over a DOM that settles a second
  // after load. These pin the replacement — reactive enforcement with a
  // write-once early exit — and the invariants the rewrite must not lose.
  group('kYoutubeMobileWatchInjectScript enforcement cadence', () {
    final script = kYoutubeMobileWatchInjectScript;

    test('does not rewrite the layout on a 300 ms interval', () {
      expect(script, isNot(contains('setInterval(enforce,300)')));
      // The only interval left is the documented safety net. setup()'s
      // `setTimeout(setup,300)` retry is not an interval.
      expect(RegExp(r'setInterval\(').allMatches(script), hasLength(1));
      expect(script, contains('setInterval(enforce,1000)'));
    });

    test('re-enforces reactively from a MutationObserver', () {
      expect(script, contains('new MutationObserver(scheduleEnforce)'));
      // Structural churn anywhere in the document: injected overlays, caption
      // windows, a rebuilt player, new siblings for the ancestor scan.
      expect(script, contains('childList:true,subtree:true'));
      // Attribute churn on the pinned elements only — subtree:false keeps the
      // per-frame progress-bar/spinner style writes from scheduling sweeps.
      expect(script, contains("attributeFilter:['class','style']"));
      expect(script, contains('function observeLayoutTargets()'));
      // The observer follows a video swap onto the new element.
      final enforceBody = script.substring(
        script.indexOf('function enforce(){'),
        script.indexOf('function setup(){'),
      );
      expect(enforceBody, contains('observeLayoutTargets();'));
    });

    test('coalesces a mutation burst into a single sweep', () {
      expect(script, contains('function scheduleEnforce()'));
      expect(script, contains('if(enforcePending||reloading) return;'));
    });

    test('each element is written at most once (bounded invocations)', () {
      // The write-once guard is what bounds a reactive sweep: a stamped
      // element costs one sentinel property read per sweep, not a re-write of
      // its whole block. `mark` is the sentinel — it also lets a sweep notice
      // a block the page overwrote and re-assert it once.
      expect(script, contains('function styleOnce(el,props,mark)'));
      expect(script, contains('if(el[STAMP]){\n      if(!mark) return;'));
      expect(
        RegExp(r'getPropertyValue\(mark\)').allMatches(script),
        hasLength(1),
      );
      expect(RegExp(r'function styleOnce\(').allMatches(script), hasLength(1));
      // The only `setProperty` in the script is the one inside that guard — a
      // write outside it would reintroduce an unbounded rewrite path.
      final styleOnceBody = script.substring(
        script.indexOf('function styleOnce('),
        script.indexOf('  // Re-apply inline hide'),
      );
      expect(
        RegExp(r'\.style\.setProperty\(').allMatches(script),
        hasLength(1),
      );
      expect(styleOnceBody, contains('.style.setProperty('));
      // The heavy layout pass is a separate function the sweep calls.
      expect(script, contains('function applyLayout()'));
      expect(script, contains('applyLayout();'));
    });

    test(
      'ad transitions are derived from the observer, not a poll cadence',
      () {
        // `ad-showing` is a class on the player container, which the attribute
        // observation covers — so the ad-reload flow no longer depends on a
        // 300 ms class check.
        expect(script, contains("player.classList.contains('ad-showing')"));
        // ...and the reload flow it drives is intact, including the position
        // hand-off. `timeupdate` keeps `savedTime` fresh now that the interval
        // that sampled it is gone — but it must stay page-local, so it is NOT
        // in the `events` array the Dart transport switch consumes.
        expect(script, contains("callHandler('onAdReload',savedTime)"));
        expect(script, contains("video.addEventListener('timeupdate'"));
        final eventsArray = RegExp(
          r'var events=\[([^\]]*)\]',
        ).firstMatch(script)!.group(1)!;
        expect(eventsArray, isNot(contains('timeupdate')));
      },
    );

    test(
      'single-inject guard, focus pin and syncState hand-off are intact',
      () {
        expect(script, contains('if(window.__enjoyYtMwc){return;}'));
        expect(script, contains('document.hasFocus=function(){return true;}'));
        expect(script, contains('function syncState(video)'));
        expect(script, contains('setTimeout(function(){syncState(v);},200);'));
      },
    );
  });
}
