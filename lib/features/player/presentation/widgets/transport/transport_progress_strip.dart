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
import 'package:enjoy_player/features/player/application/transport_slider_position_provider.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';

/// Soft outer glow so the playhead reads clearly on glass backgrounds.
class _TransportThumbShape extends RoundSliderThumbShape {
  const _TransportThumbShape({required super.enabledThumbRadius});

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
    final glow = Paint()
      ..color = color.withValues(alpha: 0.42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawCircle(center, enabledThumbRadius + 4, glow);
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

  /// Hover state is managed locally so the parent transport bar does not
  /// rebuild when the cursor enters/exits the slider thumb area (issue #471).
  bool _hovered = false;

  int? _scrubSecond;

  bool get _hapticScrub => isMobilePlatform;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
    // While dragging, render the thumb from the local drag value, not the
    // stream position — the stream won't update until the seek completes.
    final fraction = _dragFraction ?? streamFraction.clamp(0.0, 1.0);

    final timeStyle = tt.labelSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: cs.onSurfaceVariant,
    );

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Row(
        children: [
          Text(
            formatDurationHms(
              _dragFraction != null
                  ? Duration(
                      milliseconds: (_dragFraction! * durationSec * 1000)
                          .round(),
                    )
                  : pos,
            ),
            style: timeStyle,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ExcludeSemantics(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: _TransportThumbShape(
                    enabledThumbRadius: _hovered ? 6 : 4,
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: cs.primary,
                  inactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
                  thumbColor: cs.primary,
                ),
                child: Slider(
                  value: fraction.clamp(0, 1),
                  onChangeStart: (_) {
                    _scrubSecond = null;
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
                    _dragFraction = null;
                    unawaited(
                      ref
                          .read(playerInteractionsProvider.notifier)
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
