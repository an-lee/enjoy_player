/// YouTube-style Discover feed video card with add / play actions.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:enjoy_player/core/ids/enjoy_ids.dart';
import 'package:enjoy_player/core/interaction/mouse_tracker_safe.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/routing/player_navigation.dart';
import 'package:enjoy_player/features/player/application/youtube_warm.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/generative_media_cover.dart';
import 'package:enjoy_player/core/utils/remote_thumbnail_url.dart';
import 'package:enjoy_player/core/utils/time_format.dart';
import 'package:enjoy_player/features/discover/application/discover_providers.dart';
import 'package:enjoy_player/features/discover/domain/discover_channel.dart';
import 'package:enjoy_player/features/discover/domain/feed_entry.dart';
import 'package:enjoy_player/features/library/application/library_media_provider.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Width / height for [SliverGrid] cells (16:9 thumb + compact metadata).
const double discoverFeedTileGridAspectRatio = 1.28;

/// Per-locale bundle of `DateFormat` instances used by [_formatPublishedLabel].
///
/// Each `DateFormat` constructor compiles ICU `DateSymbols` (~1 KB per call),
/// so the per-locale bundle is allocated lazily on first use and reused for
/// every subsequent tile in the feed.
class _DiscoverFeedTileDateFormats {
  _DiscoverFeedTileDateFormats(this.jm, this.mmmd, this.yMMMd);

  final DateFormat jm;
  final DateFormat mmmd;
  final DateFormat yMMMd;
}

final Map<String, _DiscoverFeedTileDateFormats> _dateFormatCache = {};

_DiscoverFeedTileDateFormats _discoverFeedTileDateFormats(String locale) {
  return _dateFormatCache.putIfAbsent(
    locale,
    () => _DiscoverFeedTileDateFormats(
      DateFormat.jm(locale),
      DateFormat.MMMd(locale),
      DateFormat.yMMMd(locale),
    ),
  );
}

class DiscoverFeedTile extends ConsumerStatefulWidget {
  const DiscoverFeedTile({required this.entry, super.key});

  final FeedEntry entry;

  @override
  ConsumerState<DiscoverFeedTile> createState() => _DiscoverFeedTileState();
}

class _DiscoverFeedTileState extends ConsumerState<DiscoverFeedTile> {
  bool? _inLibrary;
  bool _adding = false;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLibraryState());
  }

  @override
  void didUpdateWidget(covariant DiscoverFeedTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.videoId != widget.entry.videoId) {
      unawaited(_loadLibraryState());
    }
  }

  Future<void> _loadLibraryState() async {
    final inLib = await discoverVideoInLibrary(ref, widget.entry.videoId);
    if (!mounted) return;
    setState(() => _inLibrary = inLib);
  }

  /// Returns `true` when the video is in the library after this call.
  Future<bool> _addToLibrary() async {
    if (_adding) return _inLibrary ?? false;
    setState(() => _adding = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await addDiscoverFeedEntryToLibrary(ref, widget.entry);
      ref.invalidate(libraryMediaProvider);
      ref.invalidate(libraryHomeRecentsProvider);
      if (!mounted) return false;
      setState(() => _inLibrary = true);
      AppNotice.success(context, l10n.discoverAddedToLibrary);
      return true;
    } catch (_) {
      if (mounted) {
        AppNotice.error(context, l10n.discoverAddFailed);
      }
      return false;
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _play() async {
    var inLib = await discoverVideoInLibrary(ref, widget.entry.videoId);
    if (!inLib) {
      inLib = await _addToLibrary();
    }
    if (!inLib || !mounted) return;
    if (mounted) setState(() => _inLibrary = true);
    final mediaId = enjoyVideoId(
      provider: 'youtube',
      vid: widget.entry.videoId,
    );
    warmYoutubeSurfaceForVideoId(ref);
    openPlayerRoute(context, mediaId);
  }

  DiscoverChannel? _subscriptionForEntry(List<DiscoverChannel> subs) {
    for (final sub in subs) {
      if (sub.channelId == widget.entry.channelId) return sub;
    }
    return null;
  }

  String? _durationLabel(FeedEntry entry) {
    final seconds = entry.durationSeconds;
    if (seconds == null || seconds <= 0) return null;
    return formatDurationHmsSeconds(seconds);
  }

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final entry = widget.entry;
    final thumb = remoteThumbnailForCard(entry.thumbnailUrl);
    final subs =
        ref.watch(discoverSubscriptionsProvider).valueOrNull ?? const [];
    final sub = _subscriptionForEntry(subs);
    final channelName = sub?.displayName ?? 'YouTube';
    final channelAvatar = remoteThumbnailForCard(sub?.thumbnailUrl);
    final inLibrary = _inLibrary ?? false;
    final publishedLabel = _formatPublishedLabel(context, entry.publishedAt);
    final durationLabel = _durationLabel(entry);

    return MouseRegion(
      onEnter: (_) => runOutsideMouseTrackerIfMounted(() => mounted, () {
        if (_hover) return;
        setState(() => _hover = true);
      }),
      onExit: (_) => runOutsideMouseTrackerIfMounted(() => mounted, () {
        if (!_hover) return;
        setState(() => _hover = false);
      }),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radiusLg),
          onTap: () => unawaited(_play()),
          hoverColor: cs.onSurface.withValues(alpha: 0.04),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VideoThumbnail(
                thumbUrl: thumb,
                coverSeed: entry.videoId,
                hover: _hover,
                inLibrary: inLibrary,
                adding: _adding,
                durationLabel: durationLabel,
              ),
              SizedBox(height: t.space8),
              Padding(
                padding: EdgeInsets.fromLTRB(t.space4, 0, t.space4, t.space4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChannelAvatar(
                      imageUrl: channelAvatar,
                      label: channelName,
                      seed: entry.channelId,
                    ),
                    SizedBox(width: t.space8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.22,
                            ),
                          ),
                          SizedBox(height: t.space4),
                          Text(
                            '$channelName · $publishedLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.85,
                              ),
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatPublishedLabel(BuildContext context, DateTime dt) {
    final formats = _discoverFeedTileDateFormats(
      Localizations.localeOf(context).toString(),
    );
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inDays == 0) {
      return formats.jm.format(local);
    }
    if (diff.inDays < 7) {
      return formats.mmmd.format(local);
    }
    if (local.year == now.year) {
      return formats.mmmd.format(local);
    }
    return formats.yMMMd.format(local);
  }
}

class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({
    required this.coverSeed,
    required this.hover,
    required this.inLibrary,
    required this.adding,
    this.thumbUrl,
    this.durationLabel,
  });

  final String? thumbUrl;
  final String coverSeed;
  final bool hover;
  final bool inLibrary;
  final bool adding;
  final String? durationLabel;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbUrl != null)
              Image.network(
                thumbUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    GenerativeMediaCover(seed: coverSeed, isVideo: true),
              )
            else
              GenerativeMediaCover(seed: coverSeed, isVideo: true),
            if (hover)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                ),
              ),
            if (hover && !adding)
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            if (adding)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (inLibrary)
              Positioned(
                top: t.space8,
                right: t.space8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(t.radiusSm),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.space8,
                      vertical: t.space4,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: cs.primary.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
            if (durationLabel != null)
              Positioned(
                right: t.space8,
                bottom: t.space8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(t.radiusSm),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.space8,
                      vertical: t.space4,
                    ),
                    child: Text(
                      durationLabel!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({
    required this.label,
    required this.seed,
    this.imageUrl,
  });

  final String? imageUrl;
  final String label;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final accent = generativeAccentForSeed(seed);
    final initial = label.trim().isNotEmpty
        ? label.trim()[0].toUpperCase()
        : '?';

    Widget fallback() {
      return ColoredBox(
        color: accent.withValues(alpha: 0.22),
        child: Center(
          child: Text(
            initial,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: 36,
        height: 36,
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              )
            : fallback(),
      ),
    );
  }
}
