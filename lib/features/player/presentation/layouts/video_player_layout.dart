/// Video surface + transcript side panel (desktop-friendly split).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/platform/player_content_layout.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_player_engine.dart';
import 'package:enjoy_player/features/player/application/player_collapse.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_state_providers.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/application/player_surface_registry.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_surface_target.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_login_video_frame_button.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_open_in_browser_button.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_video_poster.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class VideoPlayerLayout extends StatefulWidget {
  const VideoPlayerLayout({
    required this.engine,
    required this.transcript,
    super.key,
    this.initialTranscriptSplitWidthPx,
    this.onTranscriptSplitWidthCommitted,
    this.surfaceOverlay,
  });

  final PlayerEngine engine;
  final Widget transcript;

  /// Chrome painted by the permanent surface host above the video stage.
  final Widget? surfaceOverlay;

  /// Restored persisted split width; `null` uses default fraction.
  final double? initialTranscriptSplitWidthPx;

  /// Called once when the user finishes dragging the resize handle.
  final ValueChanged<double>? onTranscriptSplitWidthCommitted;

  @override
  State<VideoPlayerLayout> createState() => _VideoPlayerLayoutState();
}

class _VideoPlayerLayoutState extends State<VideoPlayerLayout> {
  /// Minimum transcript column width when layout allows it.
  static const double _kMinTranscriptWidth = 360;

  /// Transcript may use at most this fraction of total width (video keeps >=50%).
  static const double _kMaxTranscriptFraction = 0.5;

  /// Initial transcript width as a fraction of total (before first drag).
  static const double _kDefaultTranscriptFraction = 0.4;

  /// Hit target for the invisible resize strip.
  static const double _kSplitterHitWidth = 12;

  /// Stacked (narrow) layout: video stage matches TV-safe 16:9 frame width.
  static const double _kMobileVideoAspectWidth = 16;
  static const double _kMobileVideoAspectHeight = 9;

  /// User-chosen transcript width in pixels; `null` = use default fraction.
  late final ValueNotifier<double?> _transcriptWidthNotifier = ValueNotifier(
    widget.initialTranscriptSplitWidthPx,
  );

  /// Hover on splitter (desktop) for a faint affordance — no hard divider line.
  final ValueNotifier<bool> _splitterHovered = ValueNotifier(false);

  /// Whether the mouse hovers the video column (desktop side-by-side only).
  final ValueNotifier<bool> _videoColumnHovered = ValueNotifier(false);

  @override
  void didUpdateWidget(covariant VideoPlayerLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTranscriptSplitWidthPx !=
            oldWidget.initialTranscriptSplitWidthPx &&
        widget.initialTranscriptSplitWidthPx != null &&
        _transcriptWidthNotifier.value == null) {
      _transcriptWidthNotifier.value = widget.initialTranscriptSplitWidthPx;
    }
  }

  @override
  void dispose() {
    _transcriptWidthNotifier.dispose();
    _splitterHovered.dispose();
    _videoColumnHovered.dispose();
    super.dispose();
  }

  double _transcriptWidthForTotal(double totalWidth, double? widthPx) {
    final maxW = totalWidth * _kMaxTranscriptFraction;
    final minW = math.min(_kMinTranscriptWidth, maxW);
    final defaultW = totalWidth * _kDefaultTranscriptFraction;
    final raw = widthPx ?? defaultW;
    return raw.clamp(minW, maxW);
  }

  void _applyDragDelta(double totalWidth, double deltaDx) {
    final maxW = totalWidth * _kMaxTranscriptFraction;
    final minW = math.min(_kMinTranscriptWidth, maxW);
    final current = _transcriptWidthForTotal(
      totalWidth,
      _transcriptWidthNotifier.value,
    );
    _transcriptWidthNotifier.value = (current - deltaDx).clamp(minW, maxW);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Aspect of the layout constraints (not width breakpoint): landscape
        // → side-by-side; portrait/square → stacked. Transport packing still
        // uses breakpointTranscriptSideBySide elsewhere.
        final useSideBySide = usePlayerSideBySideLayout(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );

        if (useSideBySide) {
          final total = constraints.maxWidth;
          return ValueListenableBuilder<double?>(
            valueListenable: _transcriptWidthNotifier,
            builder: (context, widthPx, child) {
              final tw = _transcriptWidthForTotal(total, widthPx);
              final vw = math.max(0.0, total - tw - _kSplitterHitWidth);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _videoColumnHovered,
                    builder: (context, hovered, _) {
                      return SizedBox(
                        width: vw,
                        child: SafeArea(
                          top: true,
                          bottom: false,
                          left: false,
                          right: false,
                          child: _VideoColumn(
                            engine: widget.engine,
                            isHovered: hovered,
                            onHoverChanged: (v) =>
                                _videoColumnHovered.value = v,
                            showButtonsInTitleBar: true,
                            surfaceOverlay: widget.surfaceOverlay,
                          ),
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _splitterHovered,
                    builder: (context, splitterHovered, _) {
                      return _ResizeSplitter(
                        hitWidth: _kSplitterHitWidth,
                        hovered: splitterHovered,
                        onHover: (v) => _splitterHovered.value = v,
                        semanticLabel: AppLocalizations.of(
                          context,
                        )!.playerTranscriptResizeHint,
                        onDragDelta: (dx) => _applyDragDelta(total, dx),
                        onDragEnd: () =>
                            widget.onTranscriptSplitWidthCommitted?.call(
                              _transcriptWidthForTotal(
                                total,
                                _transcriptWidthNotifier.value,
                              ),
                            ),
                      );
                    },
                  ),
                  SizedBox(
                    width: tw,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        border: Border(
                          left: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                      ),
                      child: child,
                    ),
                  ),
                ],
              );
            },
            child: widget.transcript,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              top: true,
              bottom: false,
              left: false,
              right: false,
              child: AspectRatio(
                aspectRatio:
                    _kMobileVideoAspectWidth / _kMobileVideoAspectHeight,
                child: _VideoColumn(
                  engine: widget.engine,
                  isHovered: false,
                  onHoverChanged: null,
                  showButtonsInTitleBar: false,
                  surfaceOverlay: widget.surfaceOverlay,
                ),
              ),
            ),
            Expanded(
              child: ColoredBox(color: cs.surface, child: widget.transcript),
            ),
          ],
        );
      },
    );
  }
}

/// Wraps the video stage with an optional title-bar overlay.
///
/// On desktop (side-by-side) the title bar contains the YT control buttons;
/// on mobile the YT buttons stay at the bottom-right inside the stage.
class _VideoColumn extends StatelessWidget {
  const _VideoColumn({
    required this.engine,
    required this.isHovered,
    required this.onHoverChanged,
    required this.showButtonsInTitleBar,
    required this.surfaceOverlay,
  });

  final PlayerEngine engine;
  final bool isHovered;
  final ValueChanged<bool>? onHoverChanged;
  final bool showButtonsInTitleBar;
  final Widget? surfaceOverlay;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, c) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _VideoStageWithChrome(
                engine: engine,
                maxWidth: c.maxWidth,
                maxHeight: c.maxHeight,
                showButtons: !showButtonsInTitleBar,
                loginOnTop: showButtonsInTitleBar,
                onHoverChanged: onHoverChanged,
                titleBar: _VideoTitleBar(
                  isHovered: isHovered,
                  showYtButtons: showButtonsInTitleBar,
                ),
                surfaceOverlay: surfaceOverlay,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Title bar overlaid at the top of the video column.
///
/// Visible when paused, buffering, or the mouse hovers the video column
/// (desktop only — [isHovered] is always `false` on mobile).
class _VideoTitleBar extends ConsumerWidget {
  const _VideoTitleBar({required this.isHovered, required this.showYtButtons});

  final bool isHovered;
  final bool showYtButtons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerIsPlayingProvider).value ?? false;
    final isBuffering = ref.watch(playerIsBufferingProvider).value ?? false;
    final chrome = ref.watch(playerControllerProvider.select(playbackChromeOf));
    final isVisible = (!isPlaying || isBuffering) || isHovered;

    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Align(
        alignment: Alignment.topCenter,
        child: IgnorePointer(
          ignoring: !isVisible,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () =>
                        unawaited(collapseExpandedPlayer(ref, context)),
                  ),
                  Expanded(
                    child: Text(
                      chrome?.mediaTitle ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (showYtButtons) ...[
                    const YoutubeOpenInBrowserButton(),
                    const SizedBox(width: 6),
                    const YoutubeLoginVideoFrameButton(),
                    const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoStageWithChrome extends ConsumerWidget {
  const _VideoStageWithChrome({
    required this.engine,
    required this.maxWidth,
    required this.maxHeight,
    required this.loginOnTop,
    required this.onHoverChanged,
    required this.titleBar,
    required this.surfaceOverlay,
    this.showButtons = true,
  });

  final PlayerEngine engine;
  final double maxWidth;
  final double maxHeight;

  /// Wide side-by-side: login sits top-right on the video column (share uses
  /// app chrome top-right). Stacked narrow: login sits bottom-right to avoid
  /// the share button over the video top edge.
  final bool loginOnTop;
  final ValueChanged<bool>? onHoverChanged;
  final Widget titleBar;
  final Widget? surfaceOverlay;

  /// Whether to render YouTube control buttons inside this stage.
  ///
  /// Should be `false` when the buttons are rendered in [\_VideoTitleBar].
  final bool showButtons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isYoutube = engine is YoutubePlayerEngine;
    final yt = isYoutube ? engine as YoutubePlayerEngine : null;

    return PlayerSurfaceTarget(
      id: PlayerSurfaceIds.expandedPlayer,
      // opaque: false so empty regions pass hits through to the WebView
      // below (YouTube needs a real WebView gesture; see docs/features/youtube.md).
      overlayBuilder: (ctx) => MouseRegion(
        opaque: false,
        onEnter: onHoverChanged == null ? null : (_) => onHoverChanged!(true),
        onExit: onHoverChanged == null ? null : (_) => onHoverChanged!(false),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!isYoutube)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: Haptics.wrapTap(
                    ctx,
                    () => ref
                        .read(playerControllerProvider.notifier)
                        .togglePlay(),
                  ),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            if (showButtons)
              Positioned(
                top: loginOnTop ? 8 : null,
                bottom: loginOnTop ? null : 12,
                right: 8,
                child: isYoutube
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          YoutubeOpenInBrowserButton(),
                          SizedBox(width: 6),
                          YoutubeLoginVideoFrameButton(),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            titleBar,
            ?surfaceOverlay,
          ],
        ),
      ),
      child: ColoredBox(
        color: Colors.black,
        child: yt == null
            ? const SizedBox.expand()
            : YoutubeVideoPoster(primaryUrl: yt.posterUrl, visible: true),
      ),
    );
  }
}

class _ResizeSplitter extends StatelessWidget {
  const _ResizeSplitter({
    required this.hitWidth,
    required this.hovered,
    required this.onHover,
    required this.onDragDelta,
    required this.onDragEnd,
    required this.semanticLabel,
  });

  final double hitWidth;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final ValueChanged<double> onDragDelta;
  final VoidCallback onDragEnd;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      cursor: SystemMouseCursors.resizeColumn,
      child: SizedBox(
        width: hitWidth,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) {
            onDragDelta(details.delta.dx);
          },
          onHorizontalDragEnd: (_) => onDragEnd(),
          child: Tooltip(
            message: semanticLabel,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                width: hovered ? 4 : 3,
                height: 88,
                decoration: BoxDecoration(
                  color: hovered
                      ? cs.outline.withValues(alpha: 0.65)
                      : cs.outline.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
