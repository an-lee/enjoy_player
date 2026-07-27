/// Dark-theme markdown styling for lookup sheet AI sections.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

/// Markdown styles aligned with Enjoy's dark UI.
///
/// Avoids [MarkdownStyleSheet.fromTheme], which hard-codes light-blue
/// blockquotes and other light-mode defaults that clash with our surfaces.
MarkdownStyleSheet buildLookupMarkdownStyleSheet(
  ThemeData theme,
  EnjoyThemeTokens tokens,
) {
  final scheme = theme.colorScheme;
  final body = theme.textTheme.bodyMedium;
  final calloutFill = scheme.surfaceContainerHigh;
  final subtleBorder = scheme.outlineVariant.withValues(alpha: 0.35);
  final monospaceSize = (body?.fontSize ?? 14) * 0.92;

  return MarkdownStyleSheet(
    a: body?.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary.withValues(alpha: 0.5),
    ),
    p: body?.copyWith(height: 1.45),
    blockSpacing: tokens.space8,
    h1: theme.textTheme.headlineSmall,
    h2: theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    h2Padding: EdgeInsets.only(top: tokens.space8, bottom: tokens.space4),
    h3: theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    h3Padding: EdgeInsets.only(top: tokens.space8, bottom: tokens.space4),
    h4: theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    em: const TextStyle(fontStyle: FontStyle.italic),
    strong: body?.copyWith(fontWeight: FontWeight.w600),
    del: const TextStyle(decoration: TextDecoration.lineThrough),
    code: body?.copyWith(
      fontFamily: 'monospace',
      fontSize: monospaceSize,
      backgroundColor: calloutFill,
      color: scheme.onSurface,
    ),
    blockquote: body?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
    blockquotePadding: EdgeInsets.fromLTRB(
      tokens.space12,
      tokens.space8,
      tokens.space12,
      tokens.space8,
    ),
    blockquoteDecoration: BoxDecoration(
      color: calloutFill,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      border: Border(
        left: BorderSide(
          color: scheme.primary.withValues(alpha: 0.65),
          width: 3,
        ),
      ),
    ),
    codeblockPadding: EdgeInsets.all(tokens.space12),
    codeblockDecoration: BoxDecoration(
      color: calloutFill,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      border: Border.all(color: subtleBorder),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: subtleBorder)),
    ),
    listIndent: tokens.space24,
    listBullet: body?.copyWith(color: scheme.onSurfaceVariant),
    tableHead: body?.copyWith(fontWeight: FontWeight.w600),
    tableBody: body,
    tableBorder: TableBorder.all(color: subtleBorder),
    tableCellsPadding: EdgeInsets.symmetric(
      horizontal: tokens.space12,
      vertical: tokens.space8,
    ),
  );
}
