// Regression coverage for issue #660: after the user releases the scrubber the
// thumb must stay on the requested target instead of rubber-banding back to the
// stale pre-seek stream position.
import 'dart:async';

import 'package:enjoy_player/features/player/application/player_interactions.dart';
import 'package:enjoy_player/features/player/application/transport_slider_position_provider.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/presentation/widgets/transport/transport_progress_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _durationSeconds = 120.0;

final PlaybackChrome _chrome = (
  mediaId: 'm1',
  dexieTargetType: 'Audio',
  mediaType: 'audio',
  mediaTitle: 'Progress strip test',
  thumbnailUrl: null,
  durationSeconds: _durationSeconds,
  language: 'en',
);

/// Records the seeks the strip issues without dragging a real engine in.
class _RecordingInteractions extends PlayerInteractions {
  _RecordingInteractions(super.ref);

  final List<double> seekFractions = [];

  @override
  Future<void> seekToProgressFraction(double fraction) async {
    seekFractions.add(fraction);
  }
}

double _sliderFraction(WidgetTester tester) =>
    tester.widget<Slider>(find.byType(Slider)).value;

void main() {
  late StreamController<Duration> positions;
  late _RecordingInteractions interactions;
  late ProviderContainer container;

  /// Pumps the strip on a position stream we drive by hand, then seeds the
  /// first position (the StreamProvider only subscribes on the first watch).
  Future<void> pumpStrip(WidgetTester tester) async {
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
  }

  /// Drives the real slider callbacks through a full scrub to [fraction].
  Future<void> scrubTo(WidgetTester tester, double fraction) async {
    tester.widget<Slider>(find.byType(Slider)).onChangeStart!(fraction);
    await tester.pump();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(fraction);
    await tester.pump();
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(fraction);
    await tester.pump();
  }

  setUp(() {
    positions = StreamController<Duration>.broadcast();
    container = ProviderContainer(
      overrides: [
        transportSliderPositionProvider.overrideWith((ref) => positions.stream),
        // Assigned here because the service now needs the provider's Ref
        // (issue #668); the strip is pumped before [interactions] is read.
        playerInteractionsProvider.overrideWith(
          (ref) => interactions = _RecordingInteractions(ref),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    // Not awaited: awaiting a controller close inside the test's fake-async
    // zone never completes and hangs the test.
    unawaited(positions.close());
  });

  testWidgets('thumb holds the seek target until the stream catches up', (
    tester,
  ) async {
    await pumpStrip(tester);
    expect(_sliderFraction(tester), closeTo(10 / _durationSeconds, 1e-9));

    await scrubTo(tester, 0.5);

    // Straight after release the stream still reports 10s, but the thumb and
    // the elapsed label already show the requested target.
    expect(_sliderFraction(tester), 0.5);
    expect(find.text('01:00'), findsOneWidget);
    expect(interactions.seekFractions, [0.5]);

    // Stale ticks arriving later do not pull the thumb back.
    positions.add(const Duration(seconds: 11));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_sliderFraction(tester), 0.5);
    expect(find.text('01:00'), findsOneWidget);

    // The engine finally reports the target: hold releases, stream takes over.
    positions.add(const Duration(seconds: 60));
    await tester.pump();
    await tester.pump();
    positions.add(const Duration(seconds: 61));
    await tester.pump();
    await tester.pump();
    expect(_sliderFraction(tester), closeTo(61 / _durationSeconds, 1e-9));
    expect(find.text('01:01'), findsOneWidget);
  });

  testWidgets('backward seek holds too (stream starts beyond the target)', (
    tester,
  ) async {
    await pumpStrip(tester);

    await scrubTo(tester, 0.25);
    expect(_sliderFraction(tester), 0.25);

    // The stale position is already past the target; the hold must not read
    // that as "caught up".
    positions.add(const Duration(seconds: 11));
    await tester.pump();
    await tester.pump();
    expect(_sliderFraction(tester), 0.25);

    positions.add(const Duration(seconds: 30));
    await tester.pump();
    await tester.pump();
    positions.add(const Duration(seconds: 31));
    await tester.pump();
    await tester.pump();
    expect(_sliderFraction(tester), closeTo(31 / _durationSeconds, 1e-9));
    expect(find.text('00:31'), findsOneWidget);
  });

  testWidgets('hold releases on timeout when the stream never catches up', (
    tester,
  ) async {
    await pumpStrip(tester);

    await scrubTo(tester, 0.5);
    expect(_sliderFraction(tester), 0.5);

    // Still holding inside the 1.5s window.
    await tester.pump(const Duration(seconds: 1));
    expect(_sliderFraction(tester), 0.5);

    // Past the window the (stale) stream position takes over again.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(_sliderFraction(tester), closeTo(10 / _durationSeconds, 1e-9));
    expect(find.text('00:10'), findsOneWidget);
  });

  testWidgets('an active drag overrides the stream and any pending hold', (
    tester,
  ) async {
    await pumpStrip(tester);

    await scrubTo(tester, 0.5);
    expect(_sliderFraction(tester), 0.5);

    // Re-grab while the hold from the previous seek is still active.
    tester.widget<Slider>(find.byType(Slider)).onChangeStart!(0.5);
    await tester.pump();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0.25);
    await tester.pump();
    expect(_sliderFraction(tester), 0.25);

    // A position tick mid-drag does not move the thumb.
    positions.add(const Duration(seconds: 60));
    await tester.pump();
    await tester.pump();
    expect(_sliderFraction(tester), 0.25);
    expect(find.text('00:30'), findsOneWidget);

    // Releasing starts a fresh hold on the new target.
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(0.75);
    await tester.pump();
    expect(_sliderFraction(tester), 0.75);
    expect(interactions.seekFractions, [0.5, 0.75]);
  });
}
