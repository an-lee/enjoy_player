/// Summary body for the `CommunityActivityCard`.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/utils/time_format.dart';
import 'package:enjoy_player/features/community/domain/active_user.dart';
import 'package:enjoy_player/features/community/presentation/community_activity_avatars.dart';
import 'package:enjoy_player/features/community/presentation/community_activity_metrics.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Internal building block for `CommunityActivityCard`; not public API.
class SummaryBody extends StatelessWidget {
  const SummaryBody({
    super.key,
    required this.data,
    required this.t,
    required this.cs,
  });

  final ActiveUsersResponse data;
  final EnjoyThemeTokens t;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasToday =
        data.recordingsCountToday != null ||
        data.recordingsDurationToday != null;
    final subStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant);
    final tabular = const [FontFeature.tabularFigures()];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 16, color: cs.primary),
            SizedBox(width: t.space4),
            Expanded(
              child: Text(
                l10n.communityActivity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (data.users.isNotEmpty)
              OverlappingAvatarStack(
                users: data.users,
                totalCount: data.count,
                maxShown: kMaxAvatarsSummary,
                cs: cs,
              ),
          ],
        ),
        SizedBox(height: t.space8),
        if (hasToday) ...[
          Wrap(
            spacing: t.space8,
            runSpacing: t.space4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (data.recordingsCountToday != null)
                InlineMetric(
                  icon: Icons.mic,
                  value: '${data.recordingsCountToday}',
                  label: l10n.homeRecordingsToday,
                  cs: cs,
                  tabular: tabular,
                ),
              if (data.recordingsCountToday != null &&
                  data.recordingsDurationToday != null)
                Text('·', style: subStyle),
              if (data.recordingsDurationToday != null)
                InlineMetric(
                  icon: Icons.schedule,
                  value: formatPracticeDurationMs(
                    data.recordingsDurationToday!,
                  ),
                  label: l10n.homePracticeTime,
                  cs: cs,
                  tabular: tabular,
                ),
            ],
          ),
          if (data.count > 0) ...[
            SizedBox(height: t.space4),
            Text(
              '${data.count} ${l10n.homeActiveLearners}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: subStyle?.copyWith(fontFeatures: tabular),
            ),
          ],
        ] else if (data.users.isEmpty)
          Text(
            l10n.homeNoActiveUsers,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: subStyle,
          )
        else
          Text(
            l10n.homePeopleLearning(data.count),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: subStyle,
          ),
      ],
    );
  }
}
