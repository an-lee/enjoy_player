/// Shows a once-per-session info notice after Craft saves solid synthesis cues.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/features/craft/domain/craft_solid_transcript_hint_gate.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// If [savedSolidTimeline] and the session gate allows, show a dismissible
/// info notice. Never starts ASR.
void maybeShowCraftSolidTranscriptSttHint(
  BuildContext context, {
  required bool savedSolidTimeline,
}) {
  if (!savedSolidTimeline) return;
  if (!CraftSolidTranscriptHintGate.consume()) return;
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context);
  if (l10n == null) return;

  AppNotice.info(context, l10n.craftSolidTranscriptSttHint);
}
