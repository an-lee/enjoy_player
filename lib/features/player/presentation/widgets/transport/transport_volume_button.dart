/// Volume icon + vertical slider overlay for the transport bar.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_chrome_icon.dart';
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

  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  Timer? _hideTimer;
  bool _hovering = false;
  bool _pinned = false;

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _syncPopup() {
    final visible = _hovering || _pinned;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (visible) {
        if (!_portal.isShowing) _portal.show();
      } else if (_portal.isShowing) {
        _portal.hide();
      }
    });
  }

  void _onPointerInside(bool inside) {
    _hovering = inside;
    if (inside) {
      _cancelHideTimer();
      _syncPopup();
    } else if (!_pinned) {
      _cancelHideTimer();
      _hideTimer = Timer(const Duration(milliseconds: 200), () {
        if (!mounted || _hovering || _pinned) return;
        _syncPopup();
      });
    }
  }

  void _togglePopup() {
    _cancelHideTimer();
    setState(() => _pinned = !_pinned);
    _syncPopup();
  }

  void _dismissPinned() {
    if (!_pinned) return;
    setState(() => _pinned = false);
    _syncPopup();
  }

  @override
  void dispose() {
    _cancelHideTimer();
    super.dispose();
  }

  Widget _sliderCard(BuildContext overlayCtx) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => _onPointerInside(true),
      onExit: (_) => _onPointerInside(false),
      child: Material(
        elevation: 6,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(t.radiusSm),
        color: cs.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: _popupW,
          height: _popupH,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                        .watch(
                          playerPreferencesCtrlProvider.select((p) => p.volume),
                        )
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
  }

  @override
  Widget build(BuildContext context) {
    final volume = ref.watch(
      playerPreferencesCtrlProvider.select((p) => p.volume),
    );
    final muted = volume <= 0.01;
    final l10n = AppLocalizations.of(context)!;

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (overlayCtx) {
        final popup = CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0, -4),
          child: _sliderCard(overlayCtx),
        );
        if (!_pinned) return popup;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissPinned,
              ),
            ),
            popup,
          ],
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: MouseRegion(
          onEnter: (_) => _onPointerInside(true),
          onExit: (_) => _onPointerInside(false),
          child: IconButton(
            tooltip: l10n.volume,
            icon: EnjoyChromeIcon(
              muted ? EnjoyChromeGlyph.volumeOff : EnjoyChromeGlyph.volume,
            ),
            onPressed: _togglePopup,
          ),
        ),
      ),
    );
  }
}
