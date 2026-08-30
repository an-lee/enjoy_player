/// Video surface + transcript side panel (desktop-friendly split).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/interaction/mouse_tracker_safe.dart';
import 'package:enjoy_player/core/platform/player_content_layout.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_state_providers.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/application/player_surface_registry.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_collapse_control.dart';
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
                  SizedBox(
                    width: vw,
                    child: SafeArea(
                      top: true,
                      bottom: false,
                      left: false,
                      right: false,
                      child: _VideoColumn(
                        engine: widget.engine,
                        surfaceOverlay: widget.surfaceOverlay,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _splitterHovered,
                    builder: (context, splitterHovered, _) {
                      return _ResizeSplitter(
                        hitWidth: _kSplitterHitWidth,
                        hovered: splitterHovered,
                        onHover: (v) => setValueNotifierOutsideMouseTracker(
                          _splitterHovered,
                          v,
                        ),
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

/// Wraps the video stage with persistent back + paused title overlay.
class _VideoColumn extends StatelessWidget {
  const _VideoColumn({required this.engine, required this.surfaceOverlay});

  final PlayerEngine engine;
  final Widget? surfaceOverlay;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: _VideoStageWithChrome(
        engine: engine,
        surfaceOverlay: surfaceOverlay,
      ),
    );
  }
}

/// Title + scrim, shown only while paused or buffering.
class _VideoPausedTitleOverlay extends ConsumerWidget {
  const _VideoPausedTitleOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerIsPlayingProvider).value ?? false;
    final isBuffering = ref.watch(playerIsBufferingProvider).value ?? false;
    final chrome = ref.watch(playerControllerProvider.select(playbackChromeOf));
    final isVisible = !isPlaying || isBuffering;
    final title = chrome?.mediaTitle ?? '';

    return Align(
      alignment: Alignment.topCenter,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
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
              child: Padding(
                // Leave room for the always-on back control.
                padding: const EdgeInsets.fromLTRB(54, 0, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
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
    required this.surfaceOverlay,
  });

  final PlayerEngine engine;
  final Widget? surfaceOverlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isYoutube = engine.supportsYouTubePlayback;

    return PlayerSurfaceTarget(
      id: PlayerSurfaceIds.expandedPlayer,
      // opaque: false so empty regions pass hits through to the WebView
      // below (YouTube needs a real WebView gesture; see docs/features/youtube.md).
      overlayBuilder: (ctx) => MouseRegion(
        opaque: false,
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
            const _VideoPausedTitleOverlay(),
            const PlayerCollapseControl(),
            if (isYoutube)
              const Positioned(
                bottom: 12,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    YoutubeOpenInBrowserButton(),
                    SizedBox(width: 6),
                    YoutubeLoginVideoFrameButton(),
                  ],
                ),
              ),
            ?surfaceOverlay,
          ],
        ),
      ),
      child: ColoredBox(
        color: Colors.black,
        child: !isYoutube
            ? const SizedBox.expand()
            : YoutubeVideoPoster(
                primaryUrl: engine.metadata?.posterUrl,
                visible: true,
              ),
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
