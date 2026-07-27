/// Volume icon + vertical slider overlay for the transport bar.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/player/application/player_preferences_provider.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class TransportVolumeButton extends ConsumerStatefulWidget {
  const TransportVolumeButton({super.key});

  @override
  ConsumerState<TransportVolumeButton> createState() =>
      _TransportVolumeButtonState();
}

class _TransportVolumeButtonState extends ConsumerState<TransportVolumeButton> {
  static const double _popupW = 44;
  static const double _popupH = 152;
  static const double _gap = 4;

  final OverlayPortalController _portal = OverlayPortalController();
  Timer? _hideTimer;

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _setPopupVisible(bool visible) {
    // Defer portal mutations — showing/hiding during a layout pass (e.g. when
    // the transcript ListView rebuilds beside this bar) triggers
    // "_RenderLayoutBuilder was mutated in performLayout".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (visible) {
        _portal.show();
      } else {
        _portal.hide();
      }
    });
  }

  void _showPopup() {
    _cancelHideTimer();
    _setPopupVisible(true);
  }

  void _scheduleHidePopup() {
    _cancelHideTimer();
    _hideTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _setPopupVisible(false);
    });
  }

  void _onPointerInside(bool inside) {
    if (inside) {
      _showPopup();
    } else {
      _scheduleHidePopup();
    }
  }

  void _toggleMute() {
    _cancelHideTimer();
    unawaited(ref.read(playerPreferencesCtrlProvider.notifier).toggleMute());
  }

  /// Returns (left, top) in global coordinates for the popup card.
  (double, double) _popupOffset() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return (0, 0);
    final pos = box.localToGlobal(Offset.zero);
    final btnW = box.size.width;
    return (pos.dx + (btnW - _popupW) / 2, pos.dy - _popupH - _gap);
  }

  @override
  void dispose() {
    _cancelHideTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(playerPreferencesCtrlProvider);
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (overlayCtx) {
        final (left, top) = _popupOffset();
        return Positioned(
          left: left,
          top: top,
          width: _popupW,
          height: _popupH,
          child: MouseRegion(
            onEnter: (_) => _onPointerInside(true),
            onExit: (_) => _onPointerInside(false),
            child: Material(
              elevation: 6,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(t.radiusSm),
              color: cs.surfaceContainerHigh,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(overlayCtx).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Consumer(
                      builder: (_, ref, _) {
                        final vol = ref
                            .watch(playerPreferencesCtrlProvider)
                            .volume
                            .clamp(0.0, 1.0);
                        return Slider(
                          value: vol,
                          onChanged: (v) => unawaited(
                            ref
                                .read(playerPreferencesCtrlProvider.notifier)
                                .setVolumeTransient(v),
                          ),
                          onChangeEnd: (v) => unawaited(
                            ref
                                .read(playerPreferencesCtrlProvider.notifier)
                                .setVolume(v),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => _onPointerInside(true),
        onExit: (_) => _onPointerInside(false),
        child: IconButton(
          tooltip: prefs.volume <= 0.01
              ? l10n.transportUnmute
              : l10n.transportMute,
          icon: Icon(
            prefs.volume <= 0.01
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
          ),
          onPressed: _toggleMute,
        ),
      ),
    );
  }
}
