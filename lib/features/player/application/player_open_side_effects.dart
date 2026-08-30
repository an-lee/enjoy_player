/// Post-open work that is not required for immediate playback (transcripts, sync).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/utils/youtube_video_identity.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/library/application/library_repository_provider.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_metadata_notifier.dart';
import 'package:enjoy_player/features/sync/application/sync_providers.dart';
import 'package:enjoy_player/features/transcript/application/transcript_fetch_controller.dart';

void schedulePlayerOpenSideEffects(
  Ref ref, {
  required int openGeneration,
  required bool Function() isStale,
  required String mediaId,
  required String dexieTargetType,
}) {
  final auth = ref.read(authCtrlProvider).valueOrNull;
  final signedIn = auth is AuthSignedIn;

  unawaited(
    _runTranscriptResolve(
      ref,
      mediaId: mediaId,
      isStale: isStale,
      signedIn: signedIn,
    ),
  );

  if (signedIn) {
    unawaited(
      _runRecordingPull(
        ref,
        dexieTargetType: dexieTargetType,
        mediaId: mediaId,
        isStale: isStale,
      ),
    );
  }
}

Future<void> _runTranscriptResolve(
  Ref ref, {
  required String mediaId,
  required bool Function() isStale,
  required bool signedIn,
}) async {
  try {
    if (isStale()) return;
    await ref
        .read(transcriptFetchCtrlProvider(mediaId).notifier)
        .resolveOnOpen(signedIn: signedIn);
  } on Object catch (e, st) {
    logNamed(
      'PlayerOpenSideEffects',
    ).warning('transcript resolve failed for $mediaId', e, st);
  }
}

Future<void> _runRecordingPull(
  Ref ref, {
  required String dexieTargetType,
  required String mediaId,
  required bool Function() isStale,
}) async {
  try {
    if (isStale()) return;
    await ref
        .read(recordingTargetSyncServiceProvider)
        .pullRecordingsForTarget(
          targetType: dexieTargetType,
          targetId: mediaId,
        );
  } on Object catch (e, st) {
    logNamed(
      'PlayerOpenSideEffects',
    ).warning('recording pull failed for $mediaId', e, st);
  }
}

/// Lazy oEmbed retry after YouTube WebView reports playback-ready.
///
/// [engine] is the live playback engine and the freshness callbacks read the
/// controller's state — both captured by the caller from the [PlayerOpenHost],
/// never via `ref.read(playerControllerProvider...)`: this runs on the
/// controller's own [Ref], and Riverpod asserts "A provider cannot depend on
/// itself" when a provider reads itself (issue #676).
void scheduleYoutubeMetadataRefresh(
  Ref ref, {
  required String mediaId,
  required int openGeneration,
  required PlayerEngine engine,
  required int Function() currentOpenGeneration,
  required String? Function() currentSessionMediaId,
}) {
  unawaited(
    _runYoutubeMetadataRefresh(
      ref,
      mediaId: mediaId,
      openGeneration: openGeneration,
      engine: engine,
      currentOpenGeneration: currentOpenGeneration,
      currentSessionMediaId: currentSessionMediaId,
    ),
  );
}

Future<void> _runYoutubeMetadataRefresh(
  Ref ref, {
  required String mediaId,
  required int openGeneration,
  required PlayerEngine engine,
  required int Function() currentOpenGeneration,
  required String? Function() currentSessionMediaId,
}) async {
  // Same catch-and-log contract as the sibling helpers: this future is
  // fire-and-forget, so an escaping throw becomes an unhandled async error.
  try {
    final row = await ref.read(appDatabaseProvider).videoDao.getById(mediaId);
    if (row == null || row.provider.toLowerCase() != 'youtube') return;
    if (!_youtubeMetadataNeedsRefresh(row)) return;

    final ready = Completer<void>();
    StreamSubscription<bool>? bufferingSub;
    StreamSubscription<Duration>? durationSub;
    Timer? timeout;

    void finish() {
      if (!ready.isCompleted) ready.complete();
    }

    timeout = Timer(const Duration(seconds: 5), finish);
    bufferingSub = engine.buffering.listen((buffering) {
      if (!buffering) finish();
    });
    durationSub = engine.duration.listen((duration) {
      if (duration > Duration.zero) finish();
    });

    await ready.future;
    await bufferingSub.cancel();
    await durationSub.cancel();
    timeout.cancel();

    if (currentOpenGeneration() != openGeneration) return;
    if (currentSessionMediaId() != mediaId) return;

    final patch = await ref
        .read(mediaLibraryRepositoryProvider)
        .refreshYoutubeMetadataIfNeeded(mediaId);
    if (patch == null) return;

    ref
        .read(playerMetadataProvider)
        .patchIfCurrent(
          mediaId: mediaId,
          openGeneration: openGeneration,
          title: patch.title,
          thumbnailUrl: patch.thumbnailUrl,
        );
  } on Object catch (e, st) {
    logNamed(
      'PlayerOpenSideEffects',
    ).warning('youtube metadata refresh failed for $mediaId', e, st);
  }
}

bool _youtubeMetadataNeedsRefresh(VideoRow row) {
  return isYoutubeImportPlaceholderTitle(row.title, row.vid) ||
      row.thumbnailUrl == null ||
      row.thumbnailUrl!.trim().isEmpty;
}
