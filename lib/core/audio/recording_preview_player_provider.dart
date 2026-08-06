/// Riverpod wiring for [RecordingPreviewPlayer].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recording_preview_player.dart';

final recordingPreviewPlayerProvider = Provider<RecordingPreviewPlayback>((
  ref,
) {
  final player = RecordingPreviewPlayer();
  ref.onDispose(player.dispose);
  return player;
});
