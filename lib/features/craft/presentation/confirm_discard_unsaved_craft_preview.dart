/// Confirm dialog when leaving Craft (or switching mode) with an unsaved
/// in-memory TTS preview.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Returns `true` when the user confirms discarding the unsaved preview.
Future<bool> confirmDiscardUnsavedCraftPreview(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showEnjoyAlertDialog<bool>(
    context: context,
    title: Text(l10n.craftAudioDiscardTitle),
    content: Text(l10n.craftAudioDiscardMessage),
    actionsBuilder: (ctx) => [
      TextButton(
        onPressed: () => Navigator.pop(ctx, false),
        child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
      ),
      TextButton(
        onPressed: () => Navigator.pop(ctx, true),
        child: Text(l10n.craftAudioDiscardConfirm),
      ),
    ],
  );
  return confirmed == true;
}
