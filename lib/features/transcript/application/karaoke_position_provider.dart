/// 50 ms quantized position stream for karaoke word highlight.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../player/application/position_buckets.dart';
import '../../player/application/quantized_position.dart';
import '../../player/application/raw_engine_position_stream_provider.dart';

part 'karaoke_position_provider.g.dart';

@riverpod
Stream<Duration> karaokePosition(Ref ref) {
  final rawStream = ref.watch(rawEnginePositionStreamProvider);
  return quantizedPositionStream(rawStream, bucketMs: kPositionBucketKaraokeMs);
}
