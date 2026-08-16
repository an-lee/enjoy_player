/// Single transcript cue row with timestamp, markup, and tap target.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/interaction/mouse_tracker_safe.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/typography.dart';
import 'package:enjoy_player/core/transcript/transcript_density.dart';
import 'package:enjoy_player/data/subtitle/current_transcript_word.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/application/karaoke_word_index_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_cue_reveal_provider.dart';
import 'package:enjoy_player/features/transcript/application/tap_reveal_hold_provider.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_blur.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_blur_text.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_recording_badge.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_selection_toolbar.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_markup.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class TranscriptLineTile extends ConsumerStatefulWidget {
  const TranscriptLineTile({
    required this.line,
    required this.mediaId,
    required this.secondaryText,
    required this.isActive,
    required this.inEcho,
    required this.onTap,
    this.groupedInEcho = false,
    this.selectable = false,
    this.recordingCount,
    this.onLookupRequested,
    this.onRetranslateSecondary,
    super.key,
  });

  final TranscriptLine line;
  final String mediaId;
  final String? secondaryText;
  final bool isActive;
  final bool inEcho;

  /// Echo cues rendered inside the echo-region transcript shell: flat rows.
  final bool groupedInEcho;

  /// When true, cue text is selectable and tap-to-seek is disabled (active / echo lines).
  final bool selectable;

  /// Overlapping shadow-reading take count when known; `null` while loading.
  final int? recordingCount;

  /// Invoked when the user chooses **Look up** in the text selection toolbar
  /// (1–100 characters after trim).
  final ValueChanged<String>? onLookupRequested;

  /// When set (auto-translate active), shows an inline refresh control on the
  /// secondary translation line.
  final VoidCallback? onRetranslateSecondary;

  final VoidCallback onTap;

  @override
  ConsumerState<TranscriptLineTile> createState() => _TranscriptLineTileState();
}

class _TranscriptLineTileState extends ConsumerState<TranscriptLineTile> {
  final _hover = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  void _handleTap(BuildContext context) {
    Haptics.selection(context);
    if (ref.read(transcriptBlurModeProvider)) {
      ref
          .read(tapRevealHoldCtrlProvider(widget.mediaId).notifier)
          .setHold(
            cueId: cueIdFor(widget.line),
            holdSeconds: kTapRevealHoldSeconds,
          );
    }
    widget.onTap();
  }

  /// Reveal-only tap for selectable (active / echo) cues: starts the
  /// tap-reveal hold without seeking, since selectable cues disable
  /// tap-to-seek. No-op when blur practice is off.
  void _revealHoldOnly() {
    if (!ref.read(transcriptBlurModeProvider)) return;
    ref
        .read(tapRevealHoldCtrlProvider(widget.mediaId).notifier)
        .setHold(
          cueId: cueIdFor(widget.line),
          holdSeconds: kTapRevealHoldSeconds,
        );
  }

  String _snippet(String plain) {
    final t = plain.replaceAll('\n', ' ').trim();
    if (t.length <= 120) return t;
    return '${t.substring(0, 120)}…';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tok = EnjoyThemeTokens.of(context);
    final typography = TranscriptTypographyTokens.of(context);
    final density = TranscriptDensity.of(context);
    final l10n = AppLocalizations.of(context);
    final baseBody = typography.bodyStyle.copyWith(height: density.bodyHeight);
    final secondaryTypographyStyle = typography.secondaryStyle.copyWith(
      height: density.secondaryHeight,
    );
    final defaultFg = scheme.onSurface;

    final echoCurrent = widget.isActive && widget.inEcho;
    final timestampText = formatTranscriptTimestampMs(widget.line.startMs);
    final timestampStyle = typography.timestampStyle;

    final primaryPlain = transcriptPlainForSelection(widget.line.text);

    WordTextRange? karaokeRange;
    if (widget.isActive) {
      final wordIndex = ref.watch(karaokeWordIndexProvider(widget.mediaId));
      if (wordIndex != null) {
        karaokeRange = wordHighlightRange(
          primaryPlain,
          widget.line.timeline,
          wordIndex,
        );
      }
    }
    final karaokeFill = karaokeRange == null
        ? null
        : scheme.primary.withValues(alpha: 0.28);

    final blurEnabled = ref.watch(transcriptBlurModeProvider);
    final cueId = cueIdFor(widget.line);
    final providerRevealed = ref.watch(
      transcriptCueRevealProvider(widget.mediaId, cueId),
    );

    String statePrefix = '';
    if (l10n != null) {
      if (echoCurrent) {
        statePrefix = l10n.transcriptAccessibilityEchoCurrentLine;
      } else if (widget.isActive) {
        statePrefix = l10n.transcriptAccessibilityCurrentLine;
      } else if (widget.inEcho) {
        statePrefix = l10n.transcriptAccessibilityEchoRegion;
      }
    }
    final cueLabel = l10n != null
        ? l10n.transcriptAccessibilityCue(timestampText, _snippet(primaryPlain))
        : '$timestampText. ${_snippet(primaryPlain)}';
    var semanticsLabel = statePrefix.isEmpty
        ? cueLabel
        : '$statePrefix $cueLabel';
    final recordingCount = widget.recordingCount;
    if (recordingCount != null && recordingCount > 0 && l10n != null) {
      semanticsLabel =
          '$semanticsLabel. ${l10n.transcriptLineRecordingCount(recordingCount)}';
    }

    final primarySpan = transcriptMarkupToTextSpan(
      widget.line.text,
      baseBody,
      defaultColor: defaultFg,
      emphasize: widget.isActive,
      highlightRange: karaokeRange,
      highlightFill: karaokeFill,
    );
    final primaryWidget = widget.selectable
        ? TranscriptSelectableRichText(
            span: primarySpan,
            onTap: _revealHoldOnly,
            onLookupRequested: widget.onLookupRequested,
          )
        : Text.rich(primarySpan);

    Widget? secondaryWidget;
    if (widget.secondaryText != null) {
      secondaryWidget = widget.selectable
          ? TranscriptSelectableRichText(
              span: transcriptMarkupToTextSpan(
                widget.secondaryText!,
                secondaryTypographyStyle,
                defaultColor: scheme.onSurfaceVariant,
                emphasize: false,
              ),
              onTap: _revealHoldOnly,
              onLookupRequested: widget.onLookupRequested,
            )
          : Text.rich(
              transcriptMarkupToTextSpan(
                widget.secondaryText!,
                secondaryTypographyStyle,
                defaultColor: scheme.onSurfaceVariant,
                emphasize: false,
              ),
            );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _hover,
      builder: (context, hover, _) {
        Color? bg;
        Color? railColor;
        if (widget.groupedInEcho) {
          if (echoCurrent) {
            bg = tok.echoActive.withValues(alpha: 0.06);
            railColor = null;
          } else if (widget.inEcho) {
            bg = Colors.transparent;
          }
        } else if (echoCurrent) {
          bg = tok.echoActive.withValues(alpha: 0.06);
          railColor = tok.echoActive;
        } else if (widget.isActive) {
          bg = scheme.primary.withValues(alpha: 0.08);
          railColor = scheme.primary;
        } else if (widget.inEcho) {
          bg = tok.echoActive.withValues(alpha: 0.04);
        } else if (hover) {
          bg = scheme.onSurface.withValues(alpha: 0.04);
        }

        final isRevealed = !blurEnabled || hover || providerRevealed;

        final blurredPrimary = TranscriptBlurText(
          revealed: isRevealed,
          child: primaryWidget,
        );
        final blurredSecondary = secondaryWidget == null
            ? null
            : TranscriptBlurText(revealed: isRevealed, child: secondaryWidget);

        final textBody = Padding(
          padding: tok.transcriptLinePadding.copyWith(
            top: density.lineVerticalPadding,
            bottom: density.lineVerticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(timestampText, style: timestampStyle),
                  const Spacer(),
                  TranscriptLineRecordingBadge(count: widget.recordingCount),
                ],
              ),
              SizedBox(height: density.headerBodyGap),
              blurredPrimary,
              if (blurredSecondary != null) ...[
                SizedBox(height: density.primarySecondaryGap),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.22),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: density.secondaryLeftPadding,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: blurredSecondary),
                        if (widget.onRetranslateSecondary != null) ...[
                          SizedBox(width: tok.space4),
                          EnjoyTappableIcon(
                            icon: Icons.refresh_rounded,
                            tooltip:
                                AppLocalizations.of(
                                  context,
                                )?.subtitlesAutoTranslateRetranslateLine ??
                                'Re-translate this line',
                            iconSize: 18,
                            color: scheme.onSurfaceVariant,
                            visualDensity: VisualDensity.compact,
                            onPressed: widget.onRetranslateSecondary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );

        final content = railColor != null
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedContainer(
                      duration: tok.motionFast,
                      width: 3,
                      decoration: BoxDecoration(
                        color: railColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Expanded(child: textBody),
                  ],
                ),
              )
            : textBody;

        if (widget.selectable) {
          return Semantics(
            container: true,
            label: semanticsLabel,
            focusable: true,
            child: MouseRegion(
              onEnter: (_) => setValueNotifierOutsideMouseTracker(_hover, true),
              onExit: (_) => setValueNotifierOutsideMouseTracker(_hover, false),
              child: Material(color: bg ?? Colors.transparent, child: content),
            ),
          );
        }

        if (widget.groupedInEcho) {
          return Semantics(
            container: true,
            label: semanticsLabel,
            button: true,
            child: Material(
              color: bg ?? Colors.transparent,
              child: InkWell(
                onTap: () => _handleTap(context),
                highlightColor: scheme.onSurface.withValues(alpha: 0.04),
                splashColor: scheme.primary.withValues(alpha: 0.06),
                child: content,
              ),
            ),
          );
        }

        return Semantics(
          container: true,
          label: semanticsLabel,
          button: true,
          child: MouseRegion(
            onEnter: (_) => setValueNotifierOutsideMouseTracker(_hover, true),
            onExit: (_) => setValueNotifierOutsideMouseTracker(_hover, false),
            child: Material(
              color: bg ?? Colors.transparent,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tok.radiusSm),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(tok.radiusSm),
                onTap: () => _handleTap(context),
                hoverColor: Colors.transparent,
                highlightColor: scheme.primary.withValues(alpha: 0.06),
                splashColor: scheme.primary.withValues(alpha: 0.10),
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }
}
