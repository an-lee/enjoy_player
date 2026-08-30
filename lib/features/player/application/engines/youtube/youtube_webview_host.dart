/// Shared [InAppWebView] host for [YoutubePlayerEngine] (single instance per engine).
///
/// Speaks only to [YoutubeWebViewController] — the WebView lifecycle owner —
/// plus a `currentVideoId` reader for the watch-navigation policy. The engine
/// itself stays behind the [PlayerEngine] contract (issue #630).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/webview/platform_webview_environment.dart';
import 'youtube_watch_navigation_policy.dart';
import 'youtube_webview_bridge.dart';
import 'youtube_webview_controller.dart';

final _logWeb = logNamed('YouTubeWebViewHost');

String _consoleLevelLabel(ConsoleMessageLevel level) => switch (level) {
  ConsoleMessageLevel.TIP => 'TIP',
  ConsoleMessageLevel.LOG => 'LOG',
  ConsoleMessageLevel.WARNING => 'WARNING',
  ConsoleMessageLevel.ERROR => 'ERROR',
  ConsoleMessageLevel.DEBUG => 'DEBUG',
  _ => level.toString(),
};

/// One [InAppWebView] per engine; mounted in the video stage slot.
class YoutubeWebViewHost extends StatefulWidget {
  const YoutubeWebViewHost({
    super.key,
    required this.controller,
    required this.currentVideoId,
  });

  final YoutubeWebViewController controller;

  /// Watch-navigation policy needs the id of the video the engine opened.
  final String Function() currentVideoId;

  @override
  State<YoutubeWebViewHost> createState() => _YoutubeWebViewHostState();
}

class _YoutubeWebViewHostState extends State<YoutubeWebViewHost> {
  InAppWebViewController? _controller;

  @override
  void dispose() {
    widget.controller.onWebViewDisposed(_controller);
    super.dispose();
  }

  Future<NavigationActionPolicy> _onShouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final url = action.request.url?.toString() ?? '';
    final videoId = widget.currentVideoId();
    final allowed = shouldAllowYoutubeWatchNavigation(
      url: url,
      videoId: videoId,
      isForMainFrame: resolveYoutubeNavigationIsForMainFrame(
        action.isForMainFrame,
      ),
    );
    if (!allowed &&
        action.isForMainFrame &&
        url.contains('accounts.google.com') &&
        videoId.isNotEmpty) {
      unawaited(widget.controller.onSignInNavigationBlocked(controller));
    }
    return allowed
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL;
  }

  @override
  Widget build(BuildContext context) {
    // Distinct name from the InAppWebViewController closure parameters.
    final lifecycle = widget.controller;
    final vid = widget.currentVideoId();
    final iosInlinePlayback = defaultTargetPlatform == TargetPlatform.iOS;

    final initialUrl = vid.isEmpty
        ? YoutubeWebViewBridge.idleUri
        : YoutubeWebViewBridge.watchUri(vid);

    return ExcludeSemantics(
      child: InAppWebView(
        webViewEnvironment: appWebViewEnvironment,
        initialSettings: YoutubeWebViewSettings.forPlayer(),
        onWebViewCreated: (controller) {
          _controller = controller;
          // [initialUrlRequest] already navigates on cold mount when [vid] is set;
          // avoid a second [loadWatchPage] that interrupts the first playback start.
          lifecycle.onWebViewCreated(
            controller,
            initialWatchUrlRequested: vid.isNotEmpty,
          );
        },
        onEnterFullscreen: iosInlinePlayback
            ? (controller) {
                unawaited(lifecycle.exitNativeFullscreen(controller));
              }
            : null,
        onExitFullscreen: iosInlinePlayback
            ? (controller) {
                unawaited(lifecycle.onNativeFullscreenExit(controller));
              }
            : null,
        onLoadStop: (controller, url) async {
          await lifecycle.onPageFinished(controller, url?.toString());
        },
        onConsoleMessage: (controller, consoleMessage) {
          // YouTube/Chromium console warnings (autoplay policy, player
          // errors) are the only page-side narration of WHY a pause
          // happened — surface them in diagnostic logs.
          final message = consoleMessage.message;
          if (message.trim().isEmpty) return;
          _logWeb.fine(
            'youtube console [${_consoleLevelLabel(consoleMessage.messageLevel)}] '
            '${message.length > 300 ? message.substring(0, 300) : message}',
          );
        },
        onReceivedHttpError: (controller, request, response) {
          lifecycle.onWebResourceHttpError(
            url: request.url.toString(),
            statusCode: response.statusCode,
            isForMainFrame: request.isForMainFrame ?? false,
          );
        },
        onReceivedError: (controller, request, error) {
          if (request.isForMainFrame != true) return;
          lifecycle.onWebResourceLoadError(
            url: request.url.toString(),
            description: error.description,
          );
        },
        onWebContentProcessDidTerminate: (controller) {
          unawaited(lifecycle.onWebViewProcessTerminated());
        },
        onRenderProcessGone: (controller, detail) {
          unawaited(lifecycle.onWebViewProcessTerminated());
        },
        shouldOverrideUrlLoading: _onShouldOverrideUrlLoading,
        initialUrlRequest: URLRequest(url: initialUrl),
      ),
    );
  }
}
