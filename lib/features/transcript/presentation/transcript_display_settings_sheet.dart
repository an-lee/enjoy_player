/// Karaoke + IPA toggles for the subtitle track picker (not Settings hub).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/settings/application/ipa_overlay_settings.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/transcript/presentation/subtitle_track_picker_primitives.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Karaoke / IPA switches embedded in the CC subtitle sheet or dialog.
///
/// Uses the same rounded card + compact list-row chrome as track sections and
/// action tiles so the picker reads as one composition.
class TranscriptDisplaySettingsSection extends ConsumerWidget {
  const TranscriptDisplaySettingsSection({
    required this.hasPhones,
    this.horizontalPadding,
    super.key,
  });

  final bool hasPhones;

  /// When null, uses [EnjoyThemeTokens.space16].
  final double? horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tok = EnjoyThemeTokens.of(context);
    final pad = horizontalPadding ?? tok.space16;
    final cs = Theme.of(context).colorScheme;
    final karaokeEnabled =
        ref.watch(karaokeHighlightSettingsProvider).valueOrNull ?? false;
    final ipaEnabled =
        ref.watch(ipaOverlaySettingsProvider).valueOrNull ?? false;

    final tiles = <Widget>[
      SubtitleToggleTile(
        icon: Icons.highlight_outlined,
        title: l10n.settingsTranscriptKaraokeTitle,
        subtitle: l10n.settingsTranscriptKaraokeSubtitle,
        value: karaokeEnabled,
        onChanged: (value) {
          unawaited(
            ref
                .read(karaokeHighlightSettingsProvider.notifier)
                .setEnabled(value),
          );
        },
      ),
      SubtitleToggleTile(
        icon: Icons.record_voice_over_outlined,
        title: l10n.settingsTranscriptIpaOverlayTitle,
        subtitle: hasPhones
            ? l10n.settingsTranscriptIpaOverlaySubtitle
            : l10n.transcriptIpaUnavailableHint,
        value: ipaEnabled && hasPhones,
        onChanged: hasPhones
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
