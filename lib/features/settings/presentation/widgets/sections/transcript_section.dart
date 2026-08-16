/// Transcript options (Craft timeline enrichment + karaoke highlight).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/settings/application/timeline_enrichment_settings.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_row.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class TranscriptSectionBody extends ConsumerWidget {
  const TranscriptSectionBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final enrichmentEnabled =
        ref.watch(timelineEnrichmentSettingsProvider).valueOrNull ?? false;
    final karaokeEnabled =
        ref.watch(karaokeHighlightSettingsProvider).valueOrNull ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          leadingIcon: Icons.subtitles_outlined,
          title: l10n.settingsTranscriptEnrichmentTitle,
          subtitle: l10n.settingsTranscriptEnrichmentSubtitle,
          showChevron: false,
          trailing: Switch.adaptive(
            value: enrichmentEnabled,
            onChanged: (value) {
              unawaited(
                ref
                    .read(timelineEnrichmentSettingsProvider.notifier)
                    .setEnabled(value),
              );
            },
          ),
          onTap: () {
            unawaited(
              ref
                  .read(timelineEnrichmentSettingsProvider.notifier)
                  .setEnabled(!enrichmentEnabled),
            );
          },
        ),
        SettingsRow(
          leadingIcon: Icons.highlight_outlined,
          title: l10n.settingsTranscriptKaraokeTitle,
          subtitle: l10n.settingsTranscriptKaraokeSubtitle,
          showChevron: false,
          trailing: Switch.adaptive(
            value: karaokeEnabled,
            onChanged: (value) {
              unawaited(
                ref
                    .read(karaokeHighlightSettingsProvider.notifier)
                    .setEnabled(value),
              );
            },
          ),
          onTap: () {
            unawaited(
              ref
                  .read(karaokeHighlightSettingsProvider.notifier)
                  .setEnabled(!karaokeEnabled),
            );
          },
        ),
      ],
    );
  }
}
