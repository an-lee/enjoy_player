/// Patches in-flight [PlaybackSession] title/thumbnail after lazy metadata fetch.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/features/player/application/player_controller.dart';

part 'player_metadata_notifier.g.dart';

/// Applies the lazy YouTube metadata patch to the open session.
///
/// A state-less service (issue #668): it holds no state of its own, so it is
/// exposed by a plain keepAlive [Provider] rather than a `void build()`
/// notifier wearing dummy state.
@Riverpod(keepAlive: true)
PlayerMetadataService playerMetadata(Ref ref) => PlayerMetadataService(ref);

class PlayerMetadataService {
  PlayerMetadataService(this.ref);

  final Ref ref;

  /// Updates session chrome when [openGeneration] and [mediaId] still match.
  void patchIfCurrent({
    required String mediaId,
    required int openGeneration,
    required String title,
    String? thumbnailUrl,
  }) {
    final controller = ref.read(playerControllerProvider.notifier);
    if (controller.openGeneration != openGeneration) return;
    final session = ref.read(playerControllerProvider);
    if (session?.mediaId != mediaId) return;
    controller.applySessionPatch(
      session!.copyWith(
        mediaTitle: title,
        thumbnailUrl: thumbnailUrl ?? session.thumbnailUrl,
      ),
    );
  }
}
