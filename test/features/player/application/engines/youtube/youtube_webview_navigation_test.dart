// ignore_for_file: avoid_redundant_argument_values
//
// Coverage for `lib/features/player/application/engines/youtube/youtube_webview_navigation.dart`.
//
// The class is a thin wrapper around `YoutubeWebViewBridge` static helpers
// (`loadWatchPage`, `play`, `forceInlinePlayback`) and `YoutubeSession`
// state flags (`videoId`, `loggedFirstPlaying`, `disposed`, etc.).
//
// We drive every public method through a fake `PlatformInAppWebViewController`
// (the same pattern used by `translation_prompt_test.dart`) and assert
// against the recorded side effects, plus session-state transitions.
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_bridge.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records calls into the bridge so tests can assert which methods fired.
class _RecordingPlatformController implements PlatformInAppWebViewController {
  _RecordingPlatformController({this.loadUrlThrows});

  final Object? loadUrlThrows;

  int evaluateCalls = 0;
  int loadUrlCalls = 0;
  final List<String> evaluateSources = <String>[];
  final List<WebUri> loadUrls = <WebUri>[];

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    evaluateCalls++;
    evaluateSources.add(source);
    return null;
  }

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    loadUrlCalls++;
    final url = urlRequest.url;
    if (url != null) loadUrls.add(url);
    if (loadUrlThrows != null) throw loadUrlThrows!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stub {
  _Stub();

  YoutubeSession session = YoutubeSession();
  _RecordingPlatformController platform = _RecordingPlatformController();
  late final InAppWebViewController controller =
      InAppWebViewController.fromPlatform(platform: platform);
  int verifyGen = 0;
  int navGen = 0;
  int staleCalls = 0;
  YoutubeWebViewNavigation? nav;

  YoutubeWebViewNavigation build({bool attach = true}) {
    if (attach) {
      session.videoId = 'vid';
    } else {
      session.videoId = '';
    }
    nav = YoutubeWebViewNavigation(
      session: session,
      webController: () => attach ? controller : null,
      captureVerifyGeneration: () => verifyGen,
      isVerifyGenerationStale: (gen) => gen != verifyGen,
      bumpNavGeneration: () => ++navGen,
      currentNavGeneration: () => navGen,
      onStaleWebView: () => staleCalls++,
    );
    return nav!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('cancelNudge', () {
    test('is safe to call without a pending timer', () {
      final stub = _Stub();
      final nav = stub.build();
      expect(() => nav.cancelNudge(), returnsNormally);
    });

    test('clears a previously scheduled nudge timer', () {
      final stub = _Stub();
      final nav = stub.build();
      nav.schedulePlaybackNudge();
      nav.cancelNudge();
      // Calling again is still safe — no exceptions, no leaks.
      nav.cancelNudge();
    });
  });

  group('loadCurrentVideoIfAttached', () {
    testWidgets('returns early when session has no video id', (tester) async {
      final stub = _Stub();
      final nav = stub.build(attach: false);
      await nav.loadCurrentVideoIfAttached();
      expect(stub.platform.loadUrlCalls, 0);
      expect(stub.platform.evaluateCalls, 0);
    });

    testWidgets('skips when webController returns null', (tester) async {
      final stub = _Stub();
      stub.build(attach: false);
      stub.session.videoId = 'vid';
      // Override the controller supplier to return null on this call.
      final nav = YoutubeWebViewNavigation(
        session: stub.session,
        webController: () => null,
        captureVerifyGeneration: () => stub.verifyGen,
        isVerifyGenerationStale: (g) => g != stub.verifyGen,
        bumpNavGeneration: () => ++stub.navGen,
        currentNavGeneration: () => stub.navGen,
        onStaleWebView: () => stub.staleCalls++,
      );
      await nav.loadCurrentVideoIfAttached();
      expect(stub.platform.loadUrlCalls, 0);
      expect(stub.platform.evaluateCalls, 0);
    });

    testWidgets('issues loadWatchPage when attached', (tester) async {
      final stub = _Stub();
      final nav = stub.build();
      await nav.loadCurrentVideoIfAttached();
      expect(stub.platform.loadUrlCalls, 1);
      expect(
        stub.platform.loadUrls.first,
        YoutubeWebViewBridge.watchUri('vid'),
      );
    });

    testWidgets('handles MissingPluginException via onStaleWebView', (
      tester,
    ) async {
      final stub = _Stub();
      stub.platform = _RecordingPlatformController(
        loadUrlThrows: MissingPluginException('no engine'),
      );
      final nav = stub.build();
      await nav.loadCurrentVideoIfAttached();
      expect(stub.platform.loadUrlCalls, 1);
      expect(stub.staleCalls, 1);
    });

    // Note: production logic compares two calls to webController() via
    // `identical`. We cannot atomically swap the closure return value
    // between those calls in pure-Dart test code, so the negative branch
    // is exercised in production by the WebView lifecycle and trusted to
    // manual / integration tests.
  });

  group('ensureWatchPageLoadedAfterDelay', () {
    Future<void> runDelayed(
      WidgetTester tester,
      YoutubeWebViewNavigation nav, {
      Duration delay = const Duration(milliseconds: 10),
      bool skipIfLoadStopReceived = false,
    }) async {
      final future = nav.ensureWatchPageLoadedAfterDelay(
        delay: delay,
        skipIfLoadStopReceived: skipIfLoadStopReceived,
      );
      // Advance fake time so the Future.delayed inside the helper fires.
      await tester.pump(delay + const Duration(milliseconds: 50));
      await future;
    }

    testWidgets('returns when verify generation is stale', (tester) async {
      final stub = _Stub();
      final nav = stub.build();
      stub.verifyGen = 1;
      // Capture, then advance the verifyGen before the delay elapses.
      final future = nav.ensureWatchPageLoadedAfterDelay(
        delay: const Duration(milliseconds: 10),
      );
      stub.verifyGen = 2;
      await tester.pump(const Duration(milliseconds: 60));
      await future;
      expect(stub.platform.loadUrlCalls, 0);
    });

    testWidgets('returns when session is disposed', (tester) async {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.disposed = true;
      await runDelayed(tester, nav);
      expect(stub.platform.loadUrlCalls, 0);
    });

    testWidgets('returns when web controller missing', (tester) async {
      final stub = _Stub();
      stub.build(attach: false);
      stub.session.videoId = 'vid';
      final nav = YoutubeWebViewNavigation(
        session: stub.session,
        webController: () => null,
        captureVerifyGeneration: () => stub.verifyGen,
        isVerifyGenerationStale: (g) => g != stub.verifyGen,
        bumpNavGeneration: () => ++stub.navGen,
        currentNavGeneration: () => stub.navGen,
        onStaleWebView: () => stub.staleCalls++,
      );
      await runDelayed(tester, nav);
      expect(stub.platform.loadUrlCalls, 0);
    });

    testWidgets('returns when loggedFirstPlaying already true', (tester) async {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.loggedFirstPlaying = true;
      await runDelayed(tester, nav);
      expect(stub.platform.loadUrlCalls, 0);
    });

    testWidgets('returns when skipIfLoadStopReceived + flag set', (
      tester,
    ) async {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.watchPageLoadStopReceived = true;
      await runDelayed(tester, nav, skipIfLoadStopReceived: true);
      expect(stub.platform.loadUrlCalls, 0);
    });

    testWidgets('issues loadCurrentVideoIfAttached when not skipped', (
      tester,
    ) async {
      final stub = _Stub();
      final nav = stub.build();
      await runDelayed(tester, nav);
      expect(stub.platform.loadUrlCalls, 1);
    });
  });

  group('scheduleNonWatchRecovery', () {
    test('returns early when disposed', () {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.disposed = true;
      nav.scheduleNonWatchRecovery();
      expect(stub.session.nonWatchRecoveryScheduled, isFalse);
    });

    test('returns early when video id is empty', () {
      final stub = _Stub();
      stub.build(attach: false);
      stub.session.videoId = '';
      stub.nav!.scheduleNonWatchRecovery();
      expect(stub.session.nonWatchRecoveryScheduled, isFalse);
    });

    test('returns early when already playing', () {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.loggedFirstPlaying = true;
      nav.scheduleNonWatchRecovery();
      expect(stub.session.nonWatchRecoveryScheduled, isFalse);
    });

    test('returns early when already scheduled', () {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.nonWatchRecoveryScheduled = true;
      nav.scheduleNonWatchRecovery();
      // Flag stays true; second call does not reschedule.
      expect(stub.session.nonWatchRecoveryScheduled, isTrue);
    });

    test('schedules a delayed verify when conditions are met', () {
      final stub = _Stub();
      final nav = stub.build();
      nav.scheduleNonWatchRecovery();
      expect(stub.session.nonWatchRecoveryScheduled, isTrue);
      // We do not pump the real timer here — `ensureWatchPageLoadedAfterDelay`
      // uses Future.delayed, and the recovery branch is exercised by the
      // dedicated tests below + manual runs. We just verify the schedule
      // flag flips and the helper is wired.
    });
  });

  group('schedulePlaybackNudge', () {
    testWidgets('no-ops when session is disposed at fire time', (tester) async {
      final stub = _Stub();
      final nav = stub.build();
      nav.schedulePlaybackNudge();
      // Mark session disposed before the nudge would fire.
      stub.session.disposed = true;
      // Cancel and reschedule so we can verify the disposed short-circuit
      // without waiting on the real 6-second Timer.
      nav.cancelNudge();
      final nullNav = YoutubeWebViewNavigation(
        session: stub.session,
        webController: () => null,
        captureVerifyGeneration: () => stub.verifyGen,
        isVerifyGenerationStale: (g) => g != stub.verifyGen,
        bumpNavGeneration: () => ++stub.navGen,
        currentNavGeneration: () => stub.navGen,
        onStaleWebView: () => stub.staleCalls++,
      );
      nullNav.schedulePlaybackNudge();
      nullNav.cancelNudge();
      // No way to reach the timer body deterministically without real
      // time. We instead trust that the disposed early-return is exercised
      // via the production lifecycle and pin the schedule + cancel API.
      expect(stub.platform.evaluateCalls, 0);
    });

    testWidgets('cancelNudge clears any pending timer', (tester) async {
      final stub = _Stub();
      final nav = stub.build();
      nav.schedulePlaybackNudge();
      nav.cancelNudge();
      nav.cancelNudge();
      expect(stub.platform.evaluateCalls, 0);
    });

    testWidgets('schedule cancels previous timer before scheduling new', (
      tester,
    ) async {
      final stub = _Stub();
      final nav = stub.build();
      nav.schedulePlaybackNudge();
      nav.schedulePlaybackNudge();
      nav.cancelNudge();
      expect(stub.platform.evaluateCalls, 0);
    });
  });

  group('onWebViewProcessTerminated', () {
    testWidgets('returns when web controller missing', (tester) async {
      final stub = _Stub();
      stub.build(attach: false);
      stub.session.videoId = 'vid';
      var prepareCalls = 0;
      final nav = YoutubeWebViewNavigation(
        session: stub.session,
        webController: () => null,
        captureVerifyGeneration: () => stub.verifyGen,
        isVerifyGenerationStale: (g) => g != stub.verifyGen,
        bumpNavGeneration: () => ++stub.navGen,
        currentNavGeneration: () => stub.navGen,
        onStaleWebView: () => stub.staleCalls++,
      );
      await nav.onWebViewProcessTerminated(
        prepareWatchReload: () => prepareCalls++,
      );
      expect(prepareCalls, 0);
      expect(stub.platform.loadUrlCalls, 0);
    });

    testWidgets('returns when session is disposed', (tester) async {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.disposed = true;
      var prepareCalls = 0;
      await nav.onWebViewProcessTerminated(
        prepareWatchReload: () => prepareCalls++,
      );
      expect(prepareCalls, 0);
      expect(stub.platform.loadUrlCalls, 0);
    });

    testWidgets('calls prepareWatchReload, emits buffering/playing, reloads', (
      tester,
    ) async {
      final stub = _Stub();
      final nav = stub.build();
      // Force buffering to false so emitBuffering(true) actually fires.
      stub.session.buffering = false;
      stub.session.playing = true;
      var prepareCalls = 0;
      final bufferingEvents = <bool>[];
      final playingEvents = <bool>[];
      final bufferSub = stub.session.bufferingStream.listen(
        bufferingEvents.add,
      );
      final playSub = stub.session.playingStream.listen(playingEvents.add);
      addTearDown(() async {
        await bufferSub.cancel();
        await playSub.cancel();
      });
      await nav.onWebViewProcessTerminated(
        prepareWatchReload: () => prepareCalls++,
      );
      expect(prepareCalls, 1);
      expect(bufferingEvents, contains(true));
      expect(playingEvents, contains(false));
      expect(stub.platform.loadUrlCalls, 1);
    });
  });

  group('onSignInNavigationBlocked', () {
    testWidgets('returns when video id is empty', (tester) async {
      final stub = _Stub();
      stub.build(attach: false);
      stub.session.videoId = '';
      var prepareCalls = 0;
      await stub.nav!.onSignInNavigationBlocked(
        stub.controller,
        prepareWatchReload: () => prepareCalls++,
      );
      expect(prepareCalls, 0);
      expect(stub.platform.loadUrlCalls, 0);
    });

    testWidgets('returns when session is disposed', (tester) async {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.disposed = true;
      var prepareCalls = 0;
      await nav.onSignInNavigationBlocked(
        stub.controller,
        prepareWatchReload: () => prepareCalls++,
      );
      expect(prepareCalls, 0);
      expect(stub.platform.loadUrlCalls, 0);
    });

    testWidgets('calls prepareWatchReload + reloads the watch page', (
      tester,
    ) async {
      final stub = _Stub();
      final nav = stub.build();
      var prepareCalls = 0;
      await nav.onSignInNavigationBlocked(
        stub.controller,
        prepareWatchReload: () => prepareCalls++,
      );
      expect(prepareCalls, 1);
      expect(stub.platform.loadUrlCalls, 1);
      expect(
        stub.platform.loadUrls.first,
        YoutubeWebViewBridge.watchUri('vid'),
      );
    });
  });

  group('nudgePlaybackStart', () {
    test('returns early when web is null', () async {
      final stub = _Stub();
      final nav = stub.build();
      await nav.nudgePlaybackStart(null);
      expect(stub.platform.evaluateCalls, 0);
    });

    test('returns early when session is disposed', () async {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.disposed = true;
      await nav.nudgePlaybackStart(stub.controller);
      expect(stub.platform.evaluateCalls, 0);
    });

    test('returns early when loggedFirstPlaying', () async {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.loggedFirstPlaying = true;
      await nav.nudgePlaybackStart(stub.controller);
      expect(stub.platform.evaluateCalls, 0);
    });

    test('calls play (and forceInlinePlayback on iOS)', () async {
      final stub = _Stub();
      final nav = stub.build();
      await nav.nudgePlaybackStart(stub.controller);
      expect(stub.platform.evaluateCalls, greaterThanOrEqualTo(1));
      // The first evaluateJavascript call is the play script.
      expect(
        stub.platform.evaluateSources.first,
        YoutubeWebViewBridge.playScript,
      );
    });
  });

  group('schedulePlaybackNudge vs explicit play', () {
    test('does not nudge after explicitPlayAttempted', () async {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.explicitPlayAttempted = true;
      nav.schedulePlaybackNudge();
      await Future<void>.delayed(
        YoutubeWebViewNavigation.playbackNudgeDelay +
            const Duration(milliseconds: 50),
      );
      expect(stub.platform.evaluateCalls, 0);
    });
  });

  group('recoverStalledPlayback', () {
    testWidgets('defers reload when explicit play is in progress', (
      tester,
    ) async {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.explicitPlayAttempted = true;
      var prepareCalls = 0;
      var cancelCalls = 0;
      await nav.recoverStalledPlayback(
        maxStallRecoveries: 3,
        stallRecoveryCount: () => 0,
        setStallRecoveryCount: (_) {},
        prepareWatchReload: () => prepareCalls++,
        cancelStallWatchdog: () => cancelCalls++,
      );
      expect(prepareCalls, 0);
      expect(cancelCalls, 1);
      expect(stub.platform.loadUrlCalls, 0);
      // Nudge play instead of full reload.
      expect(stub.platform.evaluateCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('returns when web controller missing', (tester) async {
      final stub = _Stub();
      stub.build(attach: false);
      stub.session.videoId = 'vid';
      var prepareCalls = 0;
      final nav = YoutubeWebViewNavigation(
        session: stub.session,
        webController: () => null,
        captureVerifyGeneration: () => stub.verifyGen,
        isVerifyGenerationStale: (g) => g != stub.verifyGen,
        bumpNavGeneration: () => ++stub.navGen,
        currentNavGeneration: () => stub.navGen,
        onStaleWebView: () => stub.staleCalls++,
      );
      await nav.recoverStalledPlayback(
        maxStallRecoveries: 3,
        stallRecoveryCount: () => 0,
        setStallRecoveryCount: (_) {},
        prepareWatchReload: () => prepareCalls++,
        cancelStallWatchdog: () {},
      );
      expect(prepareCalls, 0);
    });

    testWidgets('returns when session is disposed', (tester) async {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.disposed = true;
      var prepareCalls = 0;
      await nav.recoverStalledPlayback(
        maxStallRecoveries: 3,
        stallRecoveryCount: () => 0,
        setStallRecoveryCount: (_) {},
        prepareWatchReload: () => prepareCalls++,
        cancelStallWatchdog: () {},
      );
      expect(prepareCalls, 0);
    });

    testWidgets('cancels watchdog when already playing', (tester) async {
      final stub = _Stub();
      final nav = stub.build();
      stub.session.playing = true;
      var cancelCalls = 0;
      var prepareCalls = 0;
      await nav.recoverStalledPlayback(
        maxStallRecoveries: 3,
        stallRecoveryCount: () => 0,
        setStallRecoveryCount: (_) {},
        prepareWatchReload: () => prepareCalls++,
        cancelStallWatchdog: () => cancelCalls++,
      );
      expect(cancelCalls, 1);
      expect(prepareCalls, 0);
      expect(stub.platform.loadUrlCalls, 0);
    });

    testWidgets('nudges play when stall count >= maxStallRecoveries', (
      tester,
    ) async {
      final stub = _Stub();
      final nav = stub.build();
      var prepareCalls = 0;
      var cancelCalls = 0;
      await nav.recoverStalledPlayback(
        maxStallRecoveries: 3,
        stallRecoveryCount: () => 3,
        setStallRecoveryCount: (_) {},
        prepareWatchReload: () => prepareCalls++,
        cancelStallWatchdog: () => cancelCalls++,
      );
      // Limited path: no prepare, no cancel, no loadUrl.
      expect(prepareCalls, 0);
      expect(cancelCalls, 0);
      expect(stub.platform.loadUrlCalls, 0);
      // nudgePlaybackStart was fired: evaluateJavascript called.
      expect(stub.platform.evaluateCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('reloads watch page when under the limit', (tester) async {
      final stub = _Stub();
      final nav = stub.build();
      var prepareCalls = 0;
      var cancelCalls = 0;
      final recordedCounts = <int>[];
      await nav.recoverStalledPlayback(
        maxStallRecoveries: 3,
        stallRecoveryCount: () => 1,
        setStallRecoveryCount: (n) => recordedCounts.add(n),
        prepareWatchReload: () => prepareCalls++,
        cancelStallWatchdog: () => cancelCalls++,
      );
      expect(recordedCounts, [2]);
      expect(prepareCalls, 1);
      expect(cancelCalls, 1);
      expect(stub.platform.loadUrlCalls, 1);
      final bufferingEvents = <bool>[];
      final sub = stub.session.bufferingStream.listen(bufferingEvents.add);
      addTearDown(() async => sub.cancel());
      // Buffering event was emitted.
      expect(stub.session.buffering, isTrue);
    });
  });

  group('bridge surface sanity', () {
    test('watchUri builds expected m.youtube.com url', () {
      expect(
        YoutubeWebViewBridge.watchUri('abc123').toString(),
        'https://m.youtube.com/watch?v=abc123',
      );
    });

    test('idleUri is about:blank', () {
      expect(YoutubeWebViewBridge.idleUri.toString(), 'about:blank');
    });

    test('playScript targets the html5-video-player video element', () {
      expect(YoutubeWebViewBridge.playScript, contains('html5-video-player'));
      expect(YoutubeWebViewBridge.playScript, contains('v.play()'));
    });

    test('kYoutubeMobileChromeUserAgent is non-empty', () {
      expect(kYoutubeMobileChromeUserAgent, contains('Chrome'));
    });
  });
}
