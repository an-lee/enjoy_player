/// Transcript options (Craft timeline enrichment).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/features/settings/application/timeline_enrichment_settings.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_row.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class TranscriptSectionBody extends ConsumerWidget {
  const TranscriptSectionBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final enabled =
        ref.watch(timelineEnrichmentSettingsProvider).valueOrNull ?? false;

    return SettingsRow(
      leadingIcon: Icons.subtitles_outlined,
      title: l10n.settingsTranscriptEnrichmentTitle,
      subtitle: l10n.settingsTranscriptEnrichmentSubtitle,
      showChevron: false,
      trailing: Switch.adaptive(
        value: enabled,
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
              .setEnabled(!enabled),
        );
      },
    );
  }
}
