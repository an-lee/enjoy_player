/// Placeholder when a medium has no transcript cues yet.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/empty_state.dart';
import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/presentation/onboarding_target.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import 'transcript_busy_action.dart';

class TranscriptEmptyState extends StatelessWidget {
  const TranscriptEmptyState({
    required this.onImport,
    this.onExtract,
    this.onGenerate,
    this.onFetchYoutube,
    this.showImportButton = true,
    this.showExtractButton = false,
    this.showGenerateButton = false,
    this.showFetchYoutubeButton = false,
    super.key,
  });

  final Future<void> Function() onImport;

  /// Embedded subtitle extract (local video only).
  final Future<void> Function()? onExtract;

  /// ASR transcript generation (local audio/video only).
  final Future<void> Function()? onGenerate;

  /// YouTube cloud transcript fetch.
  final Future<void> Function()? onFetchYoutube;

  /// When false, only remote/cloud hint copy (e.g. YouTube — no local file).
  final bool showImportButton;

  /// When true with [onExtract], shows an Extract control.
  final bool showExtractButton;

  /// When true with [onGenerate], shows an AI transcript control.
  final bool showGenerateButton;

  /// When true with [onFetchYoutube], shows Fetch transcript for YouTube.
  final bool showFetchYoutubeButton;

  bool get _hasActions =>
      showImportButton ||
      showExtractButton ||
      showGenerateButton ||
      showFetchYoutubeButton;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hint = showFetchYoutubeButton && !showImportButton
        ? l10n.noTranscriptHintRemote
        : (_hasActions ? l10n.noTranscriptHint : l10n.noTranscriptHintRemote);

    // Primary local spotlight: Extract when available, else Add subtitle.
    final wrapExtract = showExtractButton && onExtract != null;
    final wrapImport = showImportButton && !wrapExtract;

    return LayoutBuilder(
      builder: (context, viewport) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: t.space16,
            vertical: t.space24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      EnjoyIllustrations.emptyTranscript,
                      height: 72,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: t.space20),
                    Text(
                      l10n.noTranscript,
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: t.space8),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    if (_hasActions) ...[
                      SizedBox(height: t.space24),
                      _EmptyActionColumn(
                        children: [
                          if (showFetchYoutubeButton && onFetchYoutube != null)
                            OnboardingTarget(
                              tipId:
                                  OnboardingTipId.playerEmptyTranscriptYoutube,
                              onTargetAction: () {
                                unawaited(onFetchYoutube!());
                              },
                              child: TranscriptBusyButton(
                                icon: Icons.cloud_download_outlined,
                                label: l10n.transcriptEmptyFetchYoutube,
                                onPressed: onFetchYoutube!,
                                filled: true,
                              ),
                            ),
                          if (showGenerateButton && onGenerate != null)
                            TranscriptBusyButton(
                              icon: Icons.auto_awesome_rounded,
                              label: l10n.transcriptEmptyGenerate,
                              onPressed: onGenerate!,
                              filled: !showFetchYoutubeButton,
                            ),
                          if (showImportButton)
                            _maybeWrapLocal(
                              wrap: wrapImport,
                              child: TranscriptBusyButton(
                                icon: Icons.upload_file_rounded,
                                label: l10n.transcriptEmptyAddSubtitle,
                                onPressed: onImport,
                                filled:
                                    !showGenerateButton &&
                                    !showFetchYoutubeButton,
                              ),
                              onAction: () {
                                unawaited(onImport());
                              },
                            ),
                          if (showExtractButton && onExtract != null)
                            _maybeWrapLocal(
                              wrap: wrapExtract,
                              child: TranscriptBusyButton(
                                icon: Icons.subtitles_outlined,
                                label: l10n.transcriptEmptyExtract,
                                onPressed: onExtract!,
                              ),
                              onAction: () {
                                unawaited(onExtract!());
                              },
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _maybeWrapLocal({
    required bool wrap,
    required Widget child,
    required VoidCallback onAction,
  }) {
    if (!wrap) return child;
    return OnboardingTarget(
      tipId: OnboardingTipId.playerEmptyTranscriptLocal,
      onTargetAction: onAction,
      child: child,
    );
  }
}

class _EmptyActionColumn extends StatelessWidget {
  const _EmptyActionColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: t.space8),
          children[i],
        ],
      ],
    );
  }
}
