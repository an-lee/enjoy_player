// Issue #663 (rebuild scope, item D): transport progress strip hot path.
//
// While playing, the scrubber position stream emits once per
// [kPositionBucketScrubberMs] (50 ms ≈ 20 Hz). Two things are pinned here:
//
//  1. the strip rebuilds exactly once per bucket — no amplification (the
//     strip-level rebuild is accepted; the elapsed label and thumb must still
//     update every bucket), and
//  2. the thumb glow no longer allocates a `Paint` + `MaskFilter` per paint,
//     which used to be 20 native-object allocations per second of playback.
//
// Both are structural per docs/perf-measurement.md: widget-instance identity
// and an allocation counter, no wall-clock timing.
import 'dart:async' show StreamController, unawaited;

import 'package:enjoy_player/features/player/application/player_interactions.dart';
import 'package:enjoy_player/features/player/application/position_buckets.dart';
import 'package:enjoy_player/features/player/application/transport_slider_position_provider.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/presentation/widgets/transport/transport_progress_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _durationSeconds = 120.0;

final PlaybackChrome _chrome = (
  mediaId: 'm1',
  dexieTargetType: 'Audio',
  mediaType: 'audio',
  mediaTitle: 'Progress strip perf',
  thumbnailUrl: null,
  durationSeconds: _durationSeconds,
  language: 'en',
);

class _RecordingInteractions extends PlayerInteractions {
  _RecordingInteractions(super.ref);

  @override
  Future<void> seekToProgressFraction(double fraction) async {}
}

/// Paint-counting double over the production thumb shape: proves the paints
/// really ran through the cached glow path.
class _CountingThumbShape extends TransportThumbShape {
  _CountingThumbShape({required super.enabledThumbRadius});

  int paints = 0;

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
    paints++;
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

/// One paint call on a throwaway layer, the way a repaint would do it.
void _paintOnce(_CountingThumbShape shape, SliderThemeData theme) {
  const bounds = Rect.fromLTWH(0, 0, 200, 40);
  final context = PaintingContext(ContainerLayer(), bounds);
  shape.paint(
    context,
    const Offset(10, 20),
    activationAnimation: kAlwaysCompleteAnimation,
    enableAnimation: kAlwaysCompleteAnimation,
    isDiscrete: false,
    labelPainter: TextPainter(),
    parentBox: RenderPadding(padding: EdgeInsets.zero),
    sliderTheme: theme,
    textDirection: TextDirection.ltr,
    value: 0.5,
    textScaleFactor: 1,
    sizeWithOverflow: bounds.size,
  );
}

void main() {
  late StreamController<Duration> positions;
  late ProviderContainer container;

  setUp(() {
    positions = StreamController<Duration>.broadcast();
    container = ProviderContainer(
      overrides: [
        transportSliderPositionProvider.overrideWith((ref) => positions.stream),
        playerInteractionsProvider.overrideWith(
          (ref) => _RecordingInteractions(ref),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    unawaited(positions.close());
  });

  testWidgets('one strip rebuild per scrubber bucket, not more', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: TransportProgressStrip(chrome: _chrome)),
          ),
        ),
      ),
    );
    positions.add(const Duration(seconds: 10));
    await tester.pump();

    Text elapsed() => tester.widget<Text>(
      find
          .descendant(
            of: find.byType(TransportProgressStrip),
            matching: find.byType(Text),
          )
          .first,
    );

    var previous = elapsed();
    const ticks = 20;
    var rebuilds = 0;
    for (var i = 1; i <= ticks; i++) {
      positions.add(Duration(seconds: 10 + i));
      // Two frames per tick: the first lets the (async) stream delivery mark
      // the strip dirty, the second builds the frame it belongs to.
      await tester.pump();
      await tester.pump();
      final current = elapsed();
      if (!identical(current, previous)) rebuilds++;
      previous = current;
    }

    expect(
      rebuilds,
      ticks,
      reason:
          'Every bucket must refresh the elapsed label exactly once — and not '
          'cost more than one rebuild (issue #663)',
    );
    // And the label really moved with the position.
    expect(find.text('00:30'), findsOneWidget);
  });

  test('thumb glow Paint is cached per color, not allocated per paint', () {
    TransportThumbShape.debugResetGlowPaints();

    const paintCalls = 40;
    final shape = _CountingThumbShape(enabledThumbRadius: 4);
    const theme = SliderThemeData(
      thumbColor: Color(0xFF6750A4),
      disabledThumbColor: Color(0xFF6750A4),
    );
    for (var i = 0; i < paintCalls; i++) {
      _paintOnce(shape, theme);
    }

    expect(shape.paints, paintCalls);
    expect(
      TransportThumbShape.debugGlowPaintsCreated,
      1,
      reason:
          'One glow Paint per thumb color — the strip repaints on every '
          'scrubber bucket (~${1000 ~/ kPositionBucketScrubberMs} Hz), so a '
          'Paint + MaskFilter per paint is pure garbage (issue #663)',
    );

    // A second thumb color is exactly one more cached Paint, not more.
    final other = _CountingThumbShape(enabledThumbRadius: 6);
    _paintOnce(
      other,
      const SliderThemeData(
        thumbColor: Colors.red,
        disabledThumbColor: Colors.red,
      ),
    );
    expect(other.paints, 1);
    expect(TransportThumbShape.debugGlowPaintsCreated, 2);
  });
}
