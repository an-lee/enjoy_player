/// Karaoke + IPA toggles for the subtitle track picker (not Settings hub).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/subtitle/transcript_display_readiness.dart';
import 'package:enjoy_player/features/settings/application/ipa_overlay_settings.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/transcript/application/transcript_enrichment_controller.dart';
import 'package:enjoy_player/features/transcript/presentation/subtitle_track_picker_primitives.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_busy_action.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Karaoke / IPA switches embedded in the CC subtitle sheet or dialog.
///
/// Uses the same rounded card + compact list-row chrome as track sections and
/// action tiles so the picker reads as one composition. Switch **value** is
/// preference && capability; gated switches do not write SettingsDao false.
class TranscriptDisplaySettingsSection extends ConsumerWidget {
  const TranscriptDisplaySettingsSection({
    required this.mediaId,
    required this.readiness,
    this.horizontalPadding,
    super.key,
  });

  final String mediaId;
  final TranscriptDisplayReadiness readiness;

  /// When null, uses [EnjoyThemeTokens.space16].
  final double? horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tok = EnjoyThemeTokens.of(context);
    final pad = horizontalPadding ?? tok.space16;
    final cs = Theme.of(context).colorScheme;
    final karaokePref =
        ref.watch(karaokeHighlightSettingsProvider).valueOrNull ?? false;
    final ipaPref = ref.watch(ipaOverlaySettingsProvider).valueOrNull ?? false;
    final enrich = ref.watch(transcriptEnrichmentControllerProvider(mediaId));

    final karaokeOn = karaokePref && readiness.karaokeSwitchEnabled;
    final ipaOn = ipaPref && readiness.ipaSwitchEnabled;

    final tiles = <Widget>[
      SubtitleToggleTile(
        icon: Icons.highlight_outlined,
        title: l10n.settingsTranscriptKaraokeTitle,
        subtitle: readiness.karaokeSwitchEnabled
            ? l10n.settingsTranscriptKaraokeSubtitle
            : readiness.canTrustWordTimes
            ? l10n.transcriptKaraokeUnavailableHint
            : l10n.transcriptKaraokeUnavailableRemoteHint,
        value: karaokeOn,
        onChanged: readiness.karaokeSwitchEnabled
            ? (value) {
                unawaited(
                  ref
                      .read(karaokeHighlightSettingsProvider.notifier)
                      .setEnabled(value),
                );
              }
            : null,
      ),
      SubtitleToggleTile(
        icon: Icons.record_voice_over_outlined,
        title: l10n.settingsTranscriptIpaOverlayTitle,
        subtitle: readiness.ipaSwitchEnabled
            ? l10n.settingsTranscriptIpaOverlaySubtitle
            : l10n.transcriptIpaUnavailableHint,
        value: ipaOn,
        onChanged: readiness.ipaSwitchEnabled
            ? (value) {
                unawaited(
                  ref
                      .read(ipaOverlaySettingsProvider.notifier)
                      .setEnabled(value),
                );
              }
            : null,
      ),
    ];

    if (readiness.showEnrich) {
      final running = enrich.isRunning;
      final failed = enrich.isFailed;
      final owned = readiness.canTrustWordTimes;
      tiles.add(
        TranscriptBusyListTile(
          icon: Icons.auto_fix_high_outlined,
          title: running
              ? l10n.transcriptEnrichCancel
              : failed
              ? l10n.transcriptEnrichRetry
              : owned
              ? l10n.transcriptEnrichOwnedTitle
              : l10n.transcriptEnrichYoutubeTitle,
          subtitle: failed
              ? l10n.transcriptEnrichFailed
              : owned
              ? l10n.transcriptEnrichOwnedSubtitle
              : l10n.transcriptEnrichYoutubeSubtitle,
          busy: running,
          tapWhenBusy: true,
          onTap: () async {
            final ctrl = ref.read(
              transcriptEnrichmentControllerProvider(mediaId).notifier,
            );
            if (running) {
              ctrl.cancel();
            } else {
              await ctrl.run();
            }
          },
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: SubtitlePickerCard(
        title: l10n.transcriptDisplaySettingsTitle,
        child: Column(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: tok.space16 + 24 + tok.space16,
                  endIndent: tok.space16,
                  color: cs.outlineVariant.withValues(alpha: 0.14),
                ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tok.space4),
                child: tiles[i],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
