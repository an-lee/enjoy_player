/// On-demand list of stored phone labels for one transcript word.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/core/theme/widgets/sheet_drag_handle.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Future<void> showWordPhoneInspectSheet({
  required BuildContext context,
  required String wordText,
  required List<String> pieces,
}) {
  return showEnjoyAdaptiveSheet<void>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      final t = EnjoyThemeTokens.of(ctx);
      final title = l10n?.transcriptWordInspectTitle(wordText) ?? wordText;
      return Padding(
        padding: EdgeInsets.fromLTRB(t.space16, t.space8, t.space16, t.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PaddedSheetDragHandle(),
            Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            SizedBox(height: t.space12),
            for (final piece in pieces)
              Padding(
                padding: EdgeInsets.only(bottom: t.space8),
                child: Text(piece, style: Theme.of(ctx).textTheme.bodyLarge),
              ),
          ],
        ),
      );
    },
  );
}
