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

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.primaryUrl;
  }

  @override
  void didUpdateWidget(covariant YoutubeVideoPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.primaryUrl != oldWidget.primaryUrl) {
      _useMqFallback = false;
      _activeUrl = widget.primaryUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _activeUrl;
    if (url == null || url.isEmpty || !widget.visible) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: widget.visible ? 1 : 0,
      duration: const Duration(milliseconds: 220),
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
