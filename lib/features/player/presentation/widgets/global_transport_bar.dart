/// Full-width bottom transport: progress, times, play controls, artwork/meta, tools.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/routing/player_navigation.dart';
import 'package:enjoy_player/core/window/desktop_window.dart';
import 'package:enjoy_player/core/theme/dynamic_color/dynamic_color_provider.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/glass_surface.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/core/theme/widgets/sheet_drag_handle.dart';
import 'package:enjoy_player/features/hotkeys/presentation/hotkey_tooltip_label.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_interactions.dart';
import 'package:enjoy_player/features/player/application/player_preferences_provider.dart';
import 'package:enjoy_player/features/player/application/player_state_providers.dart';
import 'package:enjoy_player/features/player/application/player_ui_provider.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import 'transport/transport_artwork_tile.dart';
import 'transport/transport_cc_fullscreen.dart';
import 'transport/transport_meta_row.dart';
import 'transport/transport_play_ring_button.dart';
import 'transport/transport_playback_rate.dart';
import 'transport/transport_progress_strip.dart';
import 'transport/transport_volume_button.dart';

/// Strips trailing zeros (and the optional decimal point) from a fixed-format
/// rate string. Hoisted to a top-level final to avoid recompiling per call.
final _kTrailingZerosRegExp = RegExp(r'\.?0+$');

String _formatRateCore(double rate) {
  final x = (rate * 100).round() / 100;
  return x.toStringAsFixed(2).replaceFirst(_kTrailingZerosRegExp, '');
}

/// Narrow transport layout constants ([mobile-transport-line-nav]).
const double kNarrowPlayRingWidth = 54;
const double kNarrowIconSlotWidth = 40;
const double kNarrowSpeedSlotExtra = 12;
const double kNarrowLayoutSlack = 8;
const double kNarrowLineNavGap = 4;

/// Which controls fit in the narrow single-row transport bar.
///
/// Play/pause, echo, blur, subtitle (cc), and speed are always-on (never
/// subject to width pressure); only line navigation, volume, fullscreen, and
/// the expand icon are droppable. Previous and next are independent so that
/// previous can hide before next as width shrinks.
class NarrowTransportBudget {
  const NarrowTransportBudget({
    required this.showPrevious,
    required this.showNext,
    required this.showEcho,
    required this.showBlur,
    required this.showCc,
    required this.showSpeed,
    required this.showVolume,
    required this.showFullscreen,
    required this.showExpand,
  });

  final bool showPrevious;
  final bool showNext;
  final bool showEcho;
  final bool showBlur;
  final bool showCc;
  final bool showSpeed;
  final bool showVolume;
  final bool showFullscreen;
  final bool showExpand;
}

/// Resolves which controls fit in the narrow single-row transport bar.
///
/// The five practice controls — echo, blur, subtitle (cc), speed — plus the
/// play/pause ring are ALWAYS shown; their combined cost is reserved first so
/// the always-on invariant holds at every supported width. Only line
/// navigation, volume, fullscreen, and the expand icon are droppable, packed
/// greedily in strict priority order (highest priority first). The first
/// droppable that does not fit terminates packing, so a lower-priority control
/// can never survive at the expense of a higher-priority one. As width
/// shrinks, controls therefore drop in this order: expand → previous → next →
/// volume → fullscreen.
NarrowTransportBudget resolveNarrowTransportBudget(
  double maxWidth, {
  required bool hasTranscriptLines,
  required bool onPlayer,
  required bool showFullscreenTransport,
}) {
  // Always-on baseline: play ring + layout slack + echo + blur + cc + speed.
  // These never drop, so their cost is reserved first (always-on invariant).
  const alwaysOnCost =
      kNarrowPlayRingWidth +
      kNarrowLayoutSlack +
      kNarrowIconSlotWidth + // echo
      kNarrowIconSlotWidth + // blur
      kNarrowIconSlotWidth + // cc
      (kNarrowIconSlotWidth + kNarrowSpeedSlotExtra); // speed

  var remaining = maxWidth - alwaysOnCost;

  // Pack droppables in strict priority order. Once one does not fit, stop — a
  // lower-priority control must never be shown while a higher-priority one is
  // dropped. Drop order (first dropped first) is the reverse of this packing
  // order: expand, previous, next, volume, fullscreen.
  var stopped = false;
  bool tryAdd(double cost) {
    if (stopped) return false;
    if (remaining >= cost) {
      remaining -= cost;
      return true;
    }
    stopped = true;
    return false;
  }

  final showFullscreen =
      showFullscreenTransport && tryAdd(kNarrowIconSlotWidth);
  final showVolume = tryAdd(kNarrowIconSlotWidth);
  final showNext =
      hasTranscriptLines && tryAdd(kNarrowIconSlotWidth + kNarrowLineNavGap);
  final showPrevious =
      hasTranscriptLines && tryAdd(kNarrowIconSlotWidth + kNarrowLineNavGap);
  final showExpand = !onPlayer && tryAdd(kNarrowIconSlotWidth);

  return NarrowTransportBudget(
    showPrevious: showPrevious,
    showNext: showNext,
    showEcho: true,
    showBlur: true,
    showCc: true,
    showSpeed: true,
    showVolume: showVolume,
    showFullscreen: showFullscreen,
    showExpand: showExpand,
  );
}

Widget _narrowTransportSlot({required Widget child}) {
  return SizedBox(
    width: kNarrowIconSlotWidth,
    height: kNarrowIconSlotWidth,
    child: Center(child: child),
  );
}

class GlobalTransportBar extends ConsumerStatefulWidget {
  const GlobalTransportBar({super.key});

  @override
  ConsumerState<GlobalTransportBar> createState() => _GlobalTransportBarState();
}

class _GlobalTransportBarState extends ConsumerState<GlobalTransportBar> {
  void _openPlaybackRateSheet() {
    final t = EnjoyThemeTokens.of(context);
    unawaited(
      showEnjoySheet<void>(
        context: context,
        builder: (sheetCtx) {
          final prefs = ref.read(playerPreferencesCtrlProvider);
          final rate = prefs.playbackRate;
          final l10n = AppLocalizations.of(sheetCtx)!;
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PaddedSheetDragHandle(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      t.space20,
                      t.space4,
                      t.space20,
                      t.space8,
                    ),
                    child: Text(
                      l10n.speed,
                      style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final r in kPlaybackRatePresets)
                    ListTile(
                      leading: Icon(
                        playbackRatesEqual(rate, r)
                            ? Icons.check_rounded
                            : Icons.speed_rounded,
                        color: playbackRatesEqual(rate, r)
                            ? Theme.of(sheetCtx).colorScheme.primary
                            : Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(l10n.playbackRateTimes(_formatRateCore(r))),
                      onTap: () {
                        Haptics.selection(sheetCtx);
                        unawaited(
                          ref
                              .read(playerPreferencesCtrlProvider.notifier)
                              .setPlaybackRate(r),
                        );
                        Navigator.pop(sheetCtx);
                      },
                    ),
                  SizedBox(height: t.space8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chrome = ref.watch(playerControllerProvider.select(playbackChromeOf));
    final mediaId = ref.watch(
      playerControllerProvider.select((s) => s?.mediaId),
    );
    final hasTranscriptLinesAsync = ref.watch(
      transcriptHasLinesForMediaProvider(mediaId ?? ''),
    );
    final hasTranscriptLines = hasTranscriptLinesAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );
    final echo = ref.watch(echoModeProvider);
    final blurEnabled = ref.watch(transcriptBlurModeProvider);
    final playingAsync = ref.watch(playerIsPlayingProvider);
    final bufferingAsync = ref.watch(playerIsBufferingProvider);
    final isPlaying = playingAsync.value ?? false;
    final isBuffering = bufferingAsync.value ?? false;
    final paletteAsync = ref.watch(currentArtworkPaletteProvider);
    final dynamicAccent = paletteAsync.value?.accent;
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final playbackRate = ref.watch(
      playerPreferencesCtrlProvider.select((p) => p.playbackRate),
    );
    final playAccent = dynamicAccent ?? cs.primary;
    final path = GoRouterState.of(context).uri.path;
    final onPlayer = path.startsWith('/player/');
    final narrowLayout =
        MediaQuery.sizeOf(context).width <= t.breakpointTranscriptSideBySide;
    final hideBottomMediaInfo = narrowLayout;

    final ttPrev = hotkeyTooltipLabel(
      ref,
      'player.prevLine',
      l10n.previousLine,
    );
    final ttNext = hotkeyTooltipLabel(ref, 'player.nextLine', l10n.nextLine);
    final ttReplay = hotkeyTooltipLabel(
      ref,
      'player.replayLine',
      l10n.replayLine,
    );
    final ttEcho = hotkeyTooltipLabel(
      ref,
      'player.toggleEchoMode',
      l10n.echoMode,
    );
    final ttBlur = hotkeyTooltipLabel(
      ref,
      'player.toggleBlurPractice',
      l10n.transcriptBlurToggleTooltip,
    );
    final ttSpeed = hotkeyTooltipPair(
      ref,
      'player.slowDown',
      'player.speedUp',
      l10n.speed,
    );
    final ttPlayPause = hotkeyTooltipLabel(
      ref,
      'player.togglePlay',
      isPlaying ? l10n.pause : l10n.play,
    );

    final ttExpand = hotkeyTooltipLabel(
      ref,
      'player.toggleExpand',
      l10n.transportExpand,
    );

    if (chrome == null) return const SizedBox.shrink();

    final playRing = TransportPlayRingButton(
      playing: isPlaying,
      buffering: isBuffering,
      tooltip: ttPlayPause,
      accentColor: playAccent,
      onPressed: isBuffering
          ? null
          : Haptics.wrapTap(
              context,
              () => ref.read(playerControllerProvider.notifier).togglePlay(),
            ),
    );

    final prevButton = _LineNavButton(
      tooltip: ttPrev,
      icon: Icons.skip_previous_rounded,
      enabled: !isBuffering && hasTranscriptLines,
      onTap: () => ref.read(playerInteractionsProvider.notifier).prevLine(),
    );

    final nextButton = _LineNavButton(
      tooltip: ttNext,
      icon: Icons.skip_next_rounded,
      enabled: !isBuffering && hasTranscriptLines,
      onTap: () => ref.read(playerInteractionsProvider.notifier).nextLine(),
    );

    final replayButton = _LineNavButton(
      tooltip: ttReplay,
      icon: Icons.replay_rounded,
      enabled: !isBuffering && hasTranscriptLines,
      onTap: () => ref.read(playerInteractionsProvider.notifier).replayLine(),
    );

    final transcriptControls = <Widget>[prevButton, nextButton, replayButton];

    final primaryTransport = <Widget>[playRing, ...transcriptControls];

    final echoButton = _TransportToggleButton(
      tooltip: ttEcho,
      isActive: echo.active,
      activeColor: t.echoActive,
      onPressed: echo.active || hasTranscriptLines
          ? Haptics.wrapTap(
              context,
              () => ref.read(playerInteractionsProvider.notifier).toggleEcho(),
            )
          : null,
      icon: const Icon(Icons.mic_none_rounded),
    );

    final blurButton = _TransportToggleButton(
      tooltip: ttBlur,
      isActive: blurEnabled,
      activeColor: t.blurActive,
      onPressed: blurEnabled || hasTranscriptLines
          ? Haptics.wrapTap(
              context,
              () => ref.read(playerInteractionsProvider.notifier).toggleBlur(),
            )
          : null,
      icon: Icon(
        blurEnabled ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );

    final ccButton = TransportCcButton(mediaId: chrome.mediaId);

    final speedButton = IconButton(
      tooltip: ttSpeed,
      onPressed: Haptics.wrapTap(context, _openPlaybackRateSheet),
      icon: Padding(
        padding: EdgeInsets.all(narrowLayout ? t.space4 : t.space8),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(Icons.speed_rounded, color: cs.onSurfaceVariant),
            if (!playbackRatesEqual(playbackRate, 1.0))
              Positioned(
                right: -2,
                bottom: -4,
                child: Text(
                  AppLocalizations.of(
                    context,
                  )!.playbackRateTimes(_formatRateCore(playbackRate)),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    const volumeButton = TransportVolumeButton();

    final fullscreenButton = TransportFullscreenButton(
      isVideo: chrome.mediaType == 'video',
    );

    final expandButton = IconButton(
      tooltip: ttExpand,
      icon: const Icon(Icons.open_in_full_rounded),
      onPressed: Haptics.wrapTap(
        context,
        () => openPlayerRoute(context, chrome.mediaId),
      ),
    );

    final secondaryEssentials = <Widget>[
      echoButton,
      blurButton,
      ccButton,
      speedButton,
      volumeButton,
      fullscreenButton,
      if (!onPlayer) expandButton,
    ];

    final showFullscreenTransport = isDesktop && chrome.mediaType == 'video';

    final inner = Theme(
      data: Theme.of(context).copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(t.space12, t.space8, t.space12, 0),
            child: RepaintBoundary(
              child: TransportProgressStrip(chrome: chrome),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space12,
              t.space4,
              t.space12,
              t.space12,
            ),
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : t.motionMedium,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.03),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<bool>(hideBottomMediaInfo),
                  child: hideBottomMediaInfo
                      ? LayoutBuilder(
                          builder: (context, paddedConstraints) {
                            final budget = resolveNarrowTransportBudget(
                              paddedConstraints.maxWidth,
                              hasTranscriptLines: hasTranscriptLines,
                              onPlayer: onPlayer,
                              showFullscreenTransport: showFullscreenTransport,
                            );

                            final narrowSecondaries = <Widget>[
                              if (budget.showEcho)
                                _narrowTransportSlot(child: echoButton),
                              if (budget.showBlur)
                                _narrowTransportSlot(child: blurButton),
                              if (budget.showCc)
                                _narrowTransportSlot(child: ccButton),
                              if (budget.showSpeed)
                                SizedBox(
                                  width:
                                      kNarrowIconSlotWidth +
                                      kNarrowSpeedSlotExtra,
                                  height: kNarrowIconSlotWidth,
                                  child: Center(child: speedButton),
                                ),
                              if (budget.showVolume)
                                _narrowTransportSlot(child: volumeButton),
                              if (budget.showFullscreen)
                                _narrowTransportSlot(child: fullscreenButton),
                              if (budget.showExpand)
                                _narrowTransportSlot(child: expandButton),
                            ];

                            // Line navigation flanks the play ring; previous
                            // and next are independent so the cluster collapses
                            // cleanly (prev+play+next / play+next / play-alone).
                            final lineNavCluster = <Widget>[
                              if (budget.showPrevious) ...[
                                _narrowTransportSlot(child: prevButton),
                                const SizedBox(width: kNarrowLineNavGap),
                              ],
                              playRing,
                              if (budget.showNext) ...[
                                const SizedBox(width: kNarrowLineNavGap),
                                _narrowTransportSlot(child: nextButton),
                              ],
                            ];

                            final controlsRow = Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ...lineNavCluster,
                                const Spacer(),
                                ...narrowSecondaries,
                              ],
                            );

                            // Collapsed mini-player: tapping a neutral area of
                            // the controls bar expands the full player.
                            // Interactive controls (IconButtons / play ring) and
                            // the seek strip consume their own taps via the
                            // gesture arena, so only genuinely empty area (the
                            // spacer / row padding) triggers expand. This is a
                            // no-op on the player route (already expanded).
                            if (!onPlayer) {
                              return EnjoyTappableSurface(
                                borderRadius: BorderRadius.zero,
                                enableHoverScale: false,
                                semanticsLabel: l10n.transportExpand,
                                onTap: () =>
                                    openPlayerRoute(context, chrome.mediaId),
                                child: controlsRow,
                              );
                            }
                            return controlsRow;
                          },
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: primaryTransport,
                            ),
                            SizedBox(width: t.space12),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    if (!onPlayer) ...[
                                      TransportArtworkTile(chrome: chrome),
                                      SizedBox(width: t.space12),
                                    ],
                                    Flexible(
                                      child: Material(
                                        color: Colors.transparent,
                                        clipBehavior: Clip.antiAlias,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            t.radiusSm,
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: onPlayer
                                              ? null
                                              : Haptics.wrapTap(
                                                  context,
                                                  () => openPlayerRoute(
                                                    context,
                                                    chrome.mediaId,
                                                  ),
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            t.radiusSm,
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: t.space4,
                                              horizontal: t.space4,
                                            ),
                                            child: TransportMetaRow(
                                              chrome: chrome,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: secondaryEssentials,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final transportContent = GlassSurface(
      padding: EdgeInsets.zero,
      child: Material(color: Colors.transparent, child: inner),
    );

    if (onPlayer) return transportContent;

    return Semantics(
      explicitChildNodes: true,
      label: l10n.transportDismissPlayer,
      child: Dismissible(
        key: ValueKey<String>('transport-${chrome.mediaId}'),
        direction: DismissDirection.down,
        background: ColoredBox(
          color: cs.error.withValues(alpha: 0.1),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: t.space8),
              child: Icon(Icons.close_rounded, color: cs.error),
            ),
          ),
        ),
        onDismissed: (_) {
          Haptics.selection(context);
          ref.read(playerUiProvider.notifier).reset();
          unawaited(ref.read(playerControllerProvider.notifier).clear());
        },
        child: transportContent,
      ),
    );
  }
}

class _LineNavButton extends StatelessWidget {
  const _LineNavButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 22,
      onPressed: enabled ? Haptics.wrapTap(context, onTap) : null,
      icon: Icon(icon),
    );
  }
}

class _TransportToggleButton extends StatelessWidget {
  const _TransportToggleButton({
    required this.tooltip,
    required this.isActive,
    required this.activeColor,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      color: isActive ? activeColor : null,
      style: isActive
          ? IconButton.styleFrom(
              backgroundColor: activeColor.withValues(alpha: 0.18),
            )
          : null,
      onPressed: onPressed,
      icon: icon,
    );
  }
}
