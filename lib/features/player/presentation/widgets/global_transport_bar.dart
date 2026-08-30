/// Full-width bottom transport: progress, times, play controls, artwork/meta, tools.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/window/desktop_window.dart';
import 'package:enjoy_player/core/theme/dynamic_color/dynamic_color_provider.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_chrome_icon.dart';
import 'package:enjoy_player/core/theme/widgets/glass_surface.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/core/theme/widgets/sheet_drag_handle.dart';
import 'package:enjoy_player/features/hotkeys/presentation/hotkey_tooltip_label.dart';
import 'package:enjoy_player/features/onboarding/application/onboarding_controller.dart';
import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_eligibility.dart';
import 'package:enjoy_player/features/onboarding/presentation/onboarding_target.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_interactions.dart';
import 'package:enjoy_player/features/player/application/player_preferences_provider.dart';
import 'package:enjoy_player/features/player/application/player_state_providers.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

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

/// Height of the transport bar's control row (progress strip sits above it).
///
/// Sized to the widest always-on control — the [mobile-transport-line-nav]
/// play ring — so the bar never reflows when a control is dropped on narrow
/// layouts.
const double kTransportControlRowHeight = 56;

/// Which controls fit in the narrow single-row transport bar.
///
/// Play/pause, echo, subtitle (cc), and speed are always-on (never subject to
/// width pressure). Blur/hide lives in the CC sheet on narrow layouts, so
/// [showBlur] is always false here. Only line navigation, volume, fullscreen,
/// and the expand icon are droppable. Previous and next are independent so
/// that previous can hide before next as width shrinks.
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
  });

  final bool showPrevious;
  final bool showNext;
  final bool showEcho;
  final bool showBlur;
  final bool showCc;
  final bool showSpeed;
  final bool showVolume;
  final bool showFullscreen;
}

/// Resolves which controls fit in the narrow single-row transport bar.
///
/// The four practice controls — echo, subtitle (cc), speed — plus the
/// play/pause ring are ALWAYS shown; their combined cost is reserved first so
/// the always-on invariant holds at every supported width. Blur is omitted
/// (CC sheet). Only line navigation, volume, and fullscreen are droppable,
/// packed greedily in strict priority order (highest priority first). As
/// width shrinks, controls drop in this order: previous → next → volume →
/// fullscreen.
NarrowTransportBudget resolveNarrowTransportBudget(
  double maxWidth, {
  required bool hasTranscriptLines,
  required bool showFullscreenTransport,
}) {
  // Always-on baseline: play ring + layout slack + echo + cc + speed.
  // These never drop, so their cost is reserved first (always-on invariant).
  const alwaysOnCost =
      kNarrowPlayRingWidth +
      kNarrowLayoutSlack +
      kNarrowIconSlotWidth + // echo
      kNarrowIconSlotWidth + // cc
      (kNarrowIconSlotWidth + kNarrowSpeedSlotExtra); // speed

  var remaining = maxWidth - alwaysOnCost;

  // Pack droppables in strict priority order. Once one does not fit, stop — a
  // lower-priority control must never be shown while a higher-priority one is
  // dropped. Drop order (first dropped first) is the reverse of this packing
  // order: previous, next, volume, fullscreen.
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

  return NarrowTransportBudget(
    showPrevious: showPrevious,
    showNext: showNext,
    showEcho: true,
    showBlur: false,
    showCc: true,
    showSpeed: true,
    showVolume: showVolume,
    showFullscreen: showFullscreen,
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
  /// Avoids scheduling practice tips on every rebuild for the same UI state.
  String? _practiceScheduleKey;

  void _schedulePracticeTips({
    required String mediaId,
    required bool hasTranscript,
    required bool echoActive,
  }) {
    if (!hasTranscript || mediaId.isEmpty) return;
    final key = '$mediaId|echo=$echoActive';
    if (_practiceScheduleKey == key) return;
    _practiceScheduleKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final path = GoRouterState.of(context).uri.path;
      unawaited(
        ref
            .read(onboardingControllerProvider.notifier)
            .tryStartPracticeChain(
              TriggerContext(
                routePath: path,
                mediaId: mediaId,
                hasTranscript: true,
                echoActive: echoActive,
                recordUiReady: echoActive,
                assessUiReady: echoActive,
              ),
            ),
      );
    });
  }

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
      icon: const EnjoyChromeIcon(EnjoyChromeGlyph.skipBack),
      enabled: !isBuffering && hasTranscriptLines,
      onTap: () => ref.read(playerInteractionsProvider.notifier).prevLine(),
    );

    final nextButton = _LineNavButton(
      tooltip: ttNext,
      icon: const EnjoyChromeIcon(EnjoyChromeGlyph.skipForward),
      enabled: !isBuffering && hasTranscriptLines,
      onTap: () => ref.read(playerInteractionsProvider.notifier).nextLine(),
    );

    final replayButton = _LineNavButton(
      tooltip: ttReplay,
      icon: const EnjoyChromeIcon(EnjoyChromeGlyph.replay),
      enabled: !isBuffering && hasTranscriptLines,
      onTap: () => ref.read(playerInteractionsProvider.notifier).replayLine(),
    );

    final transcriptControls = <Widget>[prevButton, nextButton, replayButton];

    final primaryTransport = <Widget>[playRing, ...transcriptControls];

    void echoToggle() =>
        ref.read(playerInteractionsProvider.notifier).toggleEcho();
    final echoButton = OnboardingTarget(
      tipId: OnboardingTipId.playerEcho,
      onTargetAction: echo.active || hasTranscriptLines ? echoToggle : null,
      child: _TransportToggleButton(
        tooltip: ttEcho,
        isActive: echo.active,
        activeColor: t.echoActive,
        onPressed: echo.active || hasTranscriptLines
            ? Haptics.wrapTap(context, echoToggle)
            : null,
        icon: const EnjoyChromeIcon(EnjoyChromeGlyph.mic),
      ),
    );

    ref.listen(transcriptHasLinesForMediaProvider(mediaId ?? ''), (prev, next) {
      final hasLines = next.asData?.value ?? false;
      final id = mediaId ?? chrome.mediaId;
      if (!hasLines || id.isEmpty) return;
      _schedulePracticeTips(
        mediaId: id,
        hasTranscript: true,
        echoActive: ref.read(echoModeProvider).active,
      );
    });
    ref.listen(echoModeProvider, (prev, next) {
      final id = mediaId ?? chrome.mediaId;
      if (id.isEmpty || !hasTranscriptLines) return;
      _schedulePracticeTips(
        mediaId: id,
        hasTranscript: true,
        echoActive: next.active,
      );
    });
    if (hasTranscriptLines && chrome.mediaId.isNotEmpty) {
      _schedulePracticeTips(
        mediaId: chrome.mediaId,
        hasTranscript: true,
        echoActive: echo.active,
      );
    }

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
            const EnjoyChromeIcon(EnjoyChromeGlyph.speed),
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

    final secondaryEssentials = <Widget>[
      echoButton,
      blurButton,
      ccButton,
      speedButton,
      volumeButton,
      fullscreenButton,
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
              height: kTransportControlRowHeight,
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
                                    Flexible(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: t.space4,
                                          horizontal: t.space4,
                                        ),
                                        child: TransportMetaRow(chrome: chrome),
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

    final radius = t.radiusXl;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GlassSurface(
        borderRadius: radius,
        padding: EdgeInsets.zero,
        child: Material(color: Colors.transparent, child: inner),
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
  final Widget icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 22,
      onPressed: enabled ? Haptics.wrapTap(context, onTap) : null,
      icon: icon,
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
