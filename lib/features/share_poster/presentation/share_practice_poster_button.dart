/// Player chrome entry for share-practice-poster when recordings exist.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/data/db/dexie_target_type_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/share_poster/presentation/practice_poster_preview_sheet.dart';
import 'package:enjoy_player/features/sync/application/recordings_for_target_provider.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class SharePracticePosterButton extends ConsumerWidget {
  const SharePracticePosterButton({
    super.key,
    required this.mediaId,
    this.iconColor,
  });

  final String mediaId;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sessionInfo = ref.watch(
      playerControllerProvider.select(
        (s) => s != null
            ? (mediaId: s.mediaId, dexieTargetType: s.dexieTargetType)
            : null,
      ),
    );
    final targetTypeAsync = ref.watch(dexieTargetTypeForMediaProvider(mediaId));

    final targetType = sessionInfo?.mediaId == mediaId
        ? sessionInfo!.dexieTargetType
        : targetTypeAsync.value;
    if (targetType == null) return const SizedBox.shrink();

    final recordingsAsync = ref.watch(
      recordingsForTargetProvider((targetType: targetType, targetId: mediaId)),
    );

    final hasRecordings = recordingsAsync.maybeWhen(
      data: (list) => list.isNotEmpty,
      orElse: () => false,
    );

    if (!hasRecordings) return const SizedBox.shrink();

    return IconButton(
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(44, 44),
      ),
      tooltip: l10n.practicePosterShareTooltip,
      icon: Icon(Icons.ios_share_rounded, color: iconColor, size: 22),
      onPressed: () =>
          showPracticePosterPreviewSheet(context, ref, mediaId: mediaId),
    );
  }
}
