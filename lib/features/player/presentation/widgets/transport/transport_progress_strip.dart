/// Progress slider + elapsed / total times for the transport bar.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/interaction/mouse_tracker_safe.dart';
import 'package:enjoy_player/core/platform/mobile_platform.dart';
import 'package:enjoy_player/core/utils/time_format.dart';
import 'package:enjoy_player/features/player/application/player_interactions.dart';
import 'package:enjoy_player/features/player/application/position_buckets.dart';
import 'package:enjoy_player/features/player/application/transport_slider_position_provider.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';

/// Soft outer glow so the playhead reads clearly on glass backgrounds.
///
/// Public so tests can subclass [paint] and count paints; the glow [Paint] is
/// served from a per-color cache because the strip repaints on every scrubber
/// bucket (~20 Hz while playing) and a `Paint` + `MaskFilter` per paint is
/// pure garbage (issue #663).
class TransportThumbShape extends RoundSliderThumbShape {
  const TransportThumbShape({required super.enabledThumbRadius});

  static final Map<Color, Paint> _glowPaints = <Color, Paint>{};

  /// Number of distinct glow [Paint]s allocated so far — one per thumb color,
  /// never one per paint (pinned by the transport strip perf test).
  @visibleForTesting
  static int get debugGlowPaintsCreated => _glowPaints.length;

  /// Clears the cache. Only useful between tests.
  @visibleForTesting
  static void debugResetGlowPaints() => _glowPaints.clear();

  static Paint _glowPaintFor(Color thumbColor) {
    return _glowPaints.putIfAbsent(thumbColor, () {
      return Paint()
        ..color = thumbColor.withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    });
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final color = sliderTheme.thumbColor ?? const Color(0xFF6750A4);
    canvas.drawCircle(center, enabledThumbRadius + 4, _glowPaintFor(color));
    super.paint(
      context,
      center,
      activationAnimation: activationAnimation,
      enableAnimation: enableAnimation,
      isDiscrete: isDiscrete,
      labelPainter: labelPainter,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      textDirection: textDirection,
      value: value,
      textScaleFactor: textScaleFactor,
      sizeWithOverflow: sizeWithOverflow,
    );
  }
}

class TransportProgressStrip extends ConsumerStatefulWidget {
  const TransportProgressStrip({super.key, required this.chrome});

  final PlaybackChrome chrome;

  @override
  ConsumerState<TransportProgressStrip> createState() =>
      _TransportProgressStripState();
}

class _TransportProgressStripState
    extends ConsumerState<TransportProgressStrip> {
  /// Non-null while the user is actively dragging the slider; the thumb
  /// renders from this value instead of the engine position stream so the
  /// UI stays responsive without issuing a seek per micro-movement
  /// (issue #470).
  double? _dragFraction;

  /// Non-null for a short window after the drag ends: the engine position
  /// stream keeps reporting the PRE-seek position until the seek lands, so
  /// dropping [_dragFraction] immediately makes the thumb rubber-band back to
  /// where the user came from and then jump forward once the seek arrives
  /// (issue #660 — worst on YouTube, whose 250 ms poll cadence + JS seek keep
  /// the stale position on screen for 300-800 ms). While held, the thumb and
  /// the elapsed label render the requested target instead.
  double? _pendingSeekFraction;

  /// How long [_pendingSeekFraction] may pin the thumb when the stream never
  /// reports the target (swallowed / failed seek). Comfortably above
  /// YouTube's 250 ms poll cadence so a healthy seek always releases through
  /// the catch-up check below rather than through this bound.
  static const Duration _pendingSeekHold = Duration(milliseconds: 1500);

  Timer? _pendingSeekTimer;

  /// Hover state is managed locally so the parent transport bar does not
  /// rebuild when the cursor enters/exits the slider thumb area (issue #471).
  bool _hovered = false;

  int? _scrubSecond;

  bool get _hapticScrub => isMobilePlatform;

  /// Memoized thumb shapes: identity-stable so the [SliderThemeData] below (and
  /// therefore the slider) does not get a new shape per scrubber bucket.
  static const _thumbShapeIdle = TransportThumbShape(enabledThumbRadius: 4);
  static const _thumbShapeHovered = TransportThumbShape(enabledThumbRadius: 6);

  /// Memoized [SliderThemeData], invalidated when any of its inputs change.
  /// The strip rebuilds once per scrubber bucket while playing; allocating a
  /// fresh ~25-field theme data each time was the bulk of the per-tick
  /// garbage left after the glow [Paint] (issue #663).
  (SliderThemeData, Color, Color, bool)? _sliderThemeKey;
  SliderThemeData? _sliderTheme;

  SliderThemeData _sliderThemeFor(
    BuildContext context,
    ColorScheme cs,
    bool hovered,
  ) {
    final base = SliderTheme.of(context);
    final key = (base, cs.primary, cs.onSurface, hovered);
    final cached = _sliderTheme;
    if (cached != null && _sliderThemeKey == key) return cached;
    final theme = base.copyWith(
      trackHeight: 3,
      thumbShape: hovered ? _thumbShapeHovered : _thumbShapeIdle,
      overlayShape: SliderComponentShape.noOverlay,
      activeTrackColor: cs.primary,
      inactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
      thumbColor: cs.primary,
    );
    _sliderThemeKey = key;
    _sliderTheme = theme;
    return theme;
  }

  /// Memoized elapsed/total label style — same rationale as the theme data.
  (TextStyle?, Color)? _timeStyleKey;
  TextStyle? _timeStyle;

  TextStyle? _timeStyleFor(BuildContext context, ColorScheme cs) {
    final base = Theme.of(context).textTheme.labelSmall;
    final key = (base, cs.onSurfaceVariant);
    final cached = _timeStyle;
    if (cached != null && _timeStyleKey == key) return cached;
    final style = base?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: cs.onSurfaceVariant,
    );
    _timeStyleKey = key;
    _timeStyle = style;
    return style;
  }

  @override
  void dispose() {
    _pendingSeekTimer?.cancel();
    super.dispose();
  }

  /// True once the engine position stream reports a position within one
  /// scrubber bucket ([kPositionBucketScrubberMs]) of the held target, i.e.
  /// the seek landed and the real position can take over again.
  ///
  /// Compared on magnitude, not just "has the stream passed the target": for
  /// a *backward* seek the stale pre-seek position is already beyond the
  /// target, so a one-sided test would release instantly and resurrect the
  /// very snap-back this hold exists to hide (issue #660).
  bool _streamCaughtUp(Duration pos, double durationSec) {
    final pending = _pendingSeekFraction;
    if (pending == null) return false;
    final targetMs = (pending * durationSec * 1000).round();
    return (pos.inMilliseconds - targetMs).abs() <= kPositionBucketScrubberMs;
  }

  void _holdPendingSeek(double fraction) {
    _pendingSeekFraction = fraction;
    _pendingSeekTimer?.cancel();
    _pendingSeekTimer = Timer(_pendingSeekHold, _releasePendingSeek);
  }

  void _releasePendingSeek() {
    _pendingSeekTimer?.cancel();
    _pendingSeekTimer = null;
    if (!mounted || _pendingSeekFraction == null) return;
    setState(() => _pendingSeekFraction = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final durationSec = widget.chrome.durationSeconds > 0
        ? widget.chrome.durationSeconds
        : 1.0;

    final posAsync = ref.watch(transportSliderPositionProvider);
    final pos = switch (posAsync) {
      AsyncData(:final value) => value,
      _ => Duration.zero,
    };
    final streamFraction = durationSec > 0
        ? pos.inMilliseconds / 1000 / durationSec
        : 0.0;
    // Render the thumb from the local override, not the stream position,
    // while the user is dragging (#470) or while a just-issued seek has not
    // landed yet (#660) — the stream reports the stale pre-seek position in
    // both cases.
    final holdFraction = _dragFraction ?? _pendingSeekFraction;
    final fraction = holdFraction ?? streamFraction.clamp(0.0, 1.0);

    // The stream caught up, so hand the thumb back to it. Done post-frame
    // because this runs during build (pos arrives via ref.watch above).
    if (_streamCaughtUp(pos, durationSec)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _releasePendingSeek();
      });
    }

    final timeStyle = _timeStyleFor(context, cs);

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Row(
        children: [
          Text(
            formatDurationHms(
              holdFraction != null
                  ? Duration(
                      milliseconds: (holdFraction * durationSec * 1000).round(),
                    )
                  : pos,
            ),
            style: timeStyle,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ExcludeSemantics(
              child: SliderTheme(
                data: _sliderThemeFor(context, cs, _hovered),
                child: Slider(
                  value: fraction.clamp(0, 1),
                  onChangeStart: (_) {
                    _scrubSecond = null;
                    // A re-grab supersedes any hold from the previous seek;
                    // the drag value wins for as long as the finger is down.
                    _pendingSeekTimer?.cancel();
                    _pendingSeekFraction = null;
                  },
                  onChanged: (v) {
                    if (_hapticScrub) {
                      final sec = (v * durationSec).floor();
                      if (_scrubSecond != sec) {
                        _scrubSecond = sec;
                        Haptics.selection(context);
                      }
                    }
                    setState(() => _dragFraction = v);
                  },
                  onChangeEnd: (v) {
                    // Keep the thumb on the target instead of snapping back
                    // to the stale pre-seek stream position (issue #660).
                    setState(() {
                      _dragFraction = null;
                      _holdPendingSeek(v);
                    });
                    unawaited(
                      ref
                          .read(playerInteractionsProvider)
                          .seekToProgressFraction(v),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(formatDurationHmsSeconds(durationSec), style: timeStyle),
        ],
      ),
    );
  }

  void _setHovered(bool v) {
    if (_hovered == v) return;
    runOutsideMouseTrackerIfMounted(() => mounted, () {
      if (_hovered == v) return;
      setState(() => _hovered = v);
    });
  }
}
