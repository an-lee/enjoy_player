/// Thumbnail poster overlay while YouTube WebView loads or buffers.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:enjoy_player/core/utils/remote_thumbnail_url.dart';

class YoutubeVideoPoster extends StatefulWidget {
  const YoutubeVideoPoster({
    required this.primaryUrl,
    super.key,
    this.visible = true,
  });

  final String? primaryUrl;
  final bool visible;

  @override
  State<YoutubeVideoPoster> createState() => _YoutubeVideoPosterState();
}

class _YoutubeVideoPosterState extends State<YoutubeVideoPoster> {
  String? _activeUrl;
  bool _useMqFallback = false;

  /// The fade-out has finished, so the (fully transparent) poster can leave
  /// the tree. Without this the child had to be dropped synchronously on
  /// `visible: false` — which is what made the 220 ms fade-out dead code:
  /// `SizedBox.shrink()` replaced the [AnimatedOpacity] before it could
  /// animate to 0 (issue #662).
  bool _fadedOut = false;

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.primaryUrl;
    // Built hidden from the start: nothing is on screen to fade, so there is
    // no animation to wait for either.
    _fadedOut = !widget.visible;
  }

  @override
  void didUpdateWidget(covariant YoutubeVideoPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.primaryUrl != oldWidget.primaryUrl) {
      _useMqFallback = false;
      _activeUrl = widget.primaryUrl;
    }
    if (widget.visible) {
      // Re-arm the fade for the next hide.
      _fadedOut = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _activeUrl;
    if (url == null || url.isEmpty) {
      return const SizedBox.shrink();
    }
    // Nothing was on screen to fade, so go straight to the empty box.
    if (!widget.visible && _fadedOut) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: widget.visible ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      onEnd: () {
        if (!widget.visible && mounted && !_fadedOut) {
          setState(() => _fadedOut = true);
        }
      },
      child: ColoredBox(
        color: Colors.black,
        child: Image(
          image: CachedNetworkImageProvider(url),
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            if (!_useMqFallback) {
              final mq = youtubeMqFallbackForCardUrl(url);
              if (mq != null && mq != url) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _useMqFallback = true;
                      _activeUrl = mq;
                    });
                  }
                });
              }
            }
            return const ColoredBox(color: Colors.black);
          },
        ),
      ),
    );
  }
}
