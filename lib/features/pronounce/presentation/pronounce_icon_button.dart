/// Shared tap-to-play pronounce control.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/subscription/presentation/credits_failure_actions.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_locale.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class PronounceIconButton extends ConsumerWidget {
  const PronounceIconButton({
    super.key,
    required this.text,
    required this.localeTag,
    required this.surfaceId,
    this.compact = false,
    this.enabled = true,
    this.beforePlay,
    this.label,
  });

  final String text;
  final String localeTag;
  final PronounceSurfaceId surfaceId;
  final bool compact;
  final bool enabled;

  /// Optional hook before model playback starts (e.g. stop take preview).
  final Future<void> Function()? beforePlay;

  /// When set, render icon + [label] as an accent text control.
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final playback = ref.watch(pronouncePlaybackControllerProvider);
    final target = PronounceTarget.tryCreate(
      text: text,
      localeTag: localeTag,
      surfaceId: surfaceId,
    );

    final trimmed = text.trim();
    final String? disabledReason;
    if (!enabled || trimmed.isEmpty) {
      disabledReason = l10n.pronounceUnavailableLanguage;
    } else if (trimmed.length > kPronounceMaxChars) {
      disabledReason = l10n.pronounceTextTooLong;
    } else if (target == null) {
      disabledReason = l10n.pronounceUnavailableLanguage;
    } else {
      disabledReason = null;
    }

    final isLoading = target != null && playback.isLoadingFor(target);
    final isPlaying = target != null && playback.isPlayingFor(target);
    final canTap = enabled && target != null;

    final tooltip = isLoading
        ? l10n.pronounceLoading
        : isPlaying
        ? l10n.pronounceStop
        : (disabledReason ?? l10n.pronouncePlay);

    final iconSize = compact ? 20.0 : 18.0;
    final buttonSize = compact ? 40.0 : 44.0;
    final foreground = label != null ? scheme.primary : scheme.onSurfaceVariant;
    final style = IconButton.styleFrom(
      minimumSize: Size(buttonSize, buttonSize),
      fixedSize: label == null ? Size(buttonSize, buttonSize) : null,
      foregroundColor: foreground,
    );

    Future<void> onPressed() async {
      if (isLoading) {
        Haptics.selection(context);
        await ref.read(pronouncePlaybackControllerProvider.notifier).stop();
        return;
      }
      if (!canTap) return;
      final notifier = ref.read(pronouncePlaybackControllerProvider.notifier);
      try {
        // Stop competing take/clip audio only when starting model play.
        if (!isPlaying) {
          await beforePlay?.call();
        }
        await notifier.play(target);
      } on AuthFailure {
        if (!context.mounted) return;
        AppNotice.info(context, l10n.pronounceSignInRequired);
      } on CreditsFailure catch (failure) {
        if (!context.mounted) return;
        // Numbered message when the worker envelope was parsed (spec 045)
        // plus the one-tap recovery CTA; warning tone retained.
        AppNotice.warning(
          context,
          creditsFailureMessage(failure, l10n),
          action: SnackBarAction(
            label: creditsCtaLabel(l10n),
            onPressed: () => context.push('/subscription'),
          ),
        );
      } on AppFailure {
        if (!context.mounted) return;
        AppNotice.error(context, l10n.pronounceFailed);
      }
    }

    final icon = isLoading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Icon(
            isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
            size: isPlaying ? iconSize + 2 : iconSize,
          );

    if (label != null) {
      return Semantics(
        button: true,
        enabled: canTap || isLoading,
        label: tooltip,
        child: TextButton.icon(
          onPressed: (canTap || isLoading) ? onPressed : null,
          icon: icon,
          label: Text(label!),
          style: TextButton.styleFrom(
            foregroundColor: foreground,
            minimumSize: const Size(44, 44),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (isLoading) {
      return IconButton(
        tooltip: tooltip,
        style: style,
        onPressed: onPressed,
        icon: icon,
      );
    }

    return EnjoyTappableIcon(
      tooltip: tooltip,
      semanticLabel: tooltip,
      iconSize: isPlaying ? iconSize + 2 : iconSize,
      icon: isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
      color: foreground,
      style: style,
      onPressed: canTap ? onPressed : null,
    );
  }
}
