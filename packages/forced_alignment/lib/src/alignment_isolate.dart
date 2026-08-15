import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import 'alignment_pipeline.dart';
import 'failures.dart';
import 'request.dart';
import 'types.dart';

final _log = Logger('forced_alignment');

final class IsolateTimeout implements Exception {
  const IsolateTimeout();
}

final class IsolateCancelled implements Exception {
  const IsolateCancelled();
}

final class AlignIsolateJob {
  const AlignIsolateJob({
    required this.sourcePcm,
    required this.transcript,
    required this.language,
    required this.granularity,
    this.timeOffset = 0,
  });

  final Float32List sourcePcm;
  final String transcript;
  final String language;
  final AlignmentGranularity granularity;
  final double timeOffset;
}

/// DSP entry used by [Isolate.spawn]. Top-level so it is sendable.
void _alignIsolateMain(_AlignIsolateBox box) {
  try {
    final job = box.job;
    final result = runAlignPipeline(
      sourcePcm: job.sourcePcm,
      transcript: job.transcript,
      language: job.language,
      granularity: job.granularity,
      timeOffset: job.timeOffset,
    );
    box.reply.send(result);
  } catch (e, st) {
    _log.warning('alignment isolate failed', e, st);
    box.reply.send(
      AlignmentFailure(
        reason: AlignmentFailureReason.internal,
        message: e.toString(),
      ),
    );
  }
}

final class _AlignIsolateBox {
  const _AlignIsolateBox(this.reply, this.job);

  final SendPort reply;
  final AlignIsolateJob job;
}

/// Runs [runAlignPipeline] off the calling isolate. Kills the worker on
/// cancel or timeout.
Future<Object> runAlignJobInIsolate({
  required AlignIsolateJob job,
  AlignmentCancelToken? cancel,
  required Duration timeout,
}) async {
  if (cancel?.isCancelled ?? false) {
    throw const IsolateCancelled();
  }
  final receive = ReceivePort();
  late Isolate isolate;
  try {
    isolate = await Isolate.spawn(
      _alignIsolateMain,
      _AlignIsolateBox(receive.sendPort, job),
      debugName: 'forced_alignment',
    );
  } catch (e, st) {
    receive.close();
    _log.warning('failed to spawn alignment isolate', e, st);
    rethrow;
  }

  var killed = false;
  void kill() {
    if (killed) return;
    killed = true;
    isolate.kill(priority: Isolate.immediate);
  }

  final done = Completer<Object>();
  receive.listen((message) {
    if (!done.isCompleted) done.complete(message as Object);
  });

  cancel?.onCancel(() {
    kill();
    if (!done.isCompleted) {
      done.completeError(const IsolateCancelled());
    }
  });

  try {
    return await done.future.timeout(timeout);
  } on TimeoutException {
    kill();
    if (cancel?.isCancelled ?? false) {
      throw const IsolateCancelled();
    }
    throw const IsolateTimeout();
  } finally {
    receive.close();
  }
}
