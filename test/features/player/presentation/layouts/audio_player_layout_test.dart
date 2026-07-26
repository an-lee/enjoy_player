import 'dart:async';
import 'dart:typed_data';

import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine_provider.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:enjoy_player/features/player/presentation/layouts/audio_player_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' as mk;

class _FakeEngine implements PlayerEngine {
  _FakeEngine({bool initialPlaying = false, bool initialBuffering = false})
    : _playing = initialPlaying,
      _buffering = initialBuffering;

  bool _playing;
  bool _buffering;
  final _playingCtl = StreamController<bool>.broadcast();
  final _bufferingCtl = StreamController<bool>.broadcast();

  set playing(bool value) {
    _playing = value;
    _playingCtl.add(value);
  }

  set buffering(bool value) {
    _buffering = value;
    _bufferingCtl.add(value);
  }

  @override
  Stream<bool> get playing async* {
    yield _playing;
    yield* _playingCtl.stream;
  }

  @override
  Stream<bool> get buffering async* {
    yield _buffering;
    yield* _bufferingCtl.stream;
  }

  @override
  ({bool playing, bool buffering}) get transportSnapshot =>
      (playing: _playing, buffering: _buffering);

  // Unused members
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<Duration> get duration => const Stream.empty();
  @override
  Stream<void> get completed => const Stream.empty();
  @override
  Stream<mk.Tracks>? get mkTracksStream => null;
  @override
  bool get supportsVideoPosterCapture => false;
  @override
  bool get supportsSubtitleDisabling => false;
  @override
  Stream<double> get videoAspectRatioStream => const Stream.empty();
  @override
  Widget buildVideoStage({
    required BuildContext context,
    required double maxWidth,
    required double maxHeight,
  }) => const SizedBox.shrink();
  @override
  Future<void> open(PlayableSource source) async {}
  @override
  Future<void> disableRenderedSubtitles() async {}
  @override
  Future<void> seek(Duration target) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> setVolumeNormalized(double volume) async {}
  @override
  Future<void> playOrPause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<Uint8List?> screenshot({String? format}) async => null;
  @override
  void warmVideoSurface() {}
  @override
  Future<void> dispose() async {
    await _playingCtl.close();
    await _bufferingCtl.close();
  }
}

Widget _wrap(_FakeEngine engine, {required Widget transcript}) {
  return ProviderScope(
    overrides: [playerEngineProvider.overrideWithValue(engine)],
    child: MaterialApp(
      home: Scaffold(body: AudioPlayerLayout(transcript: transcript)),
    ),
  );
}

void main() {
  testWidgets('renders transcript widget centered with max-width constraint', (
    tester,
  ) async {
    final engine = _FakeEngine();
    addTearDown(engine.dispose);
    await tester.pumpWidget(
      _wrap(engine, transcript: const Text('transcript body')),
    );
    await tester.pump();

    expect(find.text('transcript body'), findsOneWidget);
    // The transcript is wrapped in a ConstrainedBox(maxWidth: contentMaxWidth).
    final constrainedBoxes = find
        .byWidgetPredicate((w) => w is ConstrainedBox)
        .evaluate();
    expect(constrainedBoxes, isNotEmpty);
  });

  testWidgets('does not wrap in SafeArea when not playing', (tester) async {
    final engine = _FakeEngine();
    addTearDown(engine.dispose);
    await tester.pumpWidget(_wrap(engine, transcript: const Text('body')));
    await tester.pump();

    // SafeArea should NOT be present when paused.
    expect(find.byType(SafeArea), findsNothing);
  });

  testWidgets('wraps in SafeArea when playing (hides AppBar overlay)', (
    tester,
  ) async {
    final engine = _FakeEngine(initialPlaying: true);
    addTearDown(engine.dispose);
    await tester.pumpWidget(_wrap(engine, transcript: const Text('body')));
    await tester.pump();

    expect(find.byType(SafeArea), findsOneWidget);
  });

  testWidgets('updates playing state when stream emits new value', (
    tester,
  ) async {
    final engine = _FakeEngine();
    addTearDown(engine.dispose);
    await tester.pumpWidget(_wrap(engine, transcript: const Text('body')));
    await tester.pump();

    expect(find.byType(SafeArea), findsNothing);

    engine.playing = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The seed-then-follow stream emits through the StreamProvider and
    // eventually settles; allow a few pumps for the diff to propagate.
    expect(find.byType(SafeArea), findsOneWidget);
  });
}
