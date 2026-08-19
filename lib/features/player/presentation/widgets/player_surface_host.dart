/// Permanent shell host for the active engine video / WebView surface.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine_rev.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_surface_registry.dart';

/// Owns the single `buildVideoStage` for the current engine.
///
/// Follows [playerSurfaceRegistryProvider] when a target is attached; otherwise
/// parks YouTube off-screen so WebView2 is not torn down. Never reparents the
/// underlying [InAppWebView] / media_kit [Video] between routes.
///
/// Set [forcePark] when a shell route that owns its own platform view (e.g.
/// `/youtube/login`) is on top of a still-mounted player page, or when a
/// transient overlay (dialog / sheet / snackbar) must clear the native
/// surface (ADR-0066) — otherwise this host stays above the shell [Stack]
/// and covers that UI.
class PlayerSurfaceHost extends ConsumerWidget {
  const PlayerSurfaceHost({super.key, this.forcePark = false});

  /// When true, ignore any registry attachment and park off-screen.
  final bool forcePark;

  static const double _parkWidth = 320;
  static const double _parkHeight = 180;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playerEngineRevProvider);
    final attachment = forcePark
        ? null
        : ref.watch(playerSurfaceRegistryProvider);

    // Prefer the real owned engine; fall back to the test double when set.
    final engine =
        ref.read(playerControllerProvider.notifier).ownedEngine ??
        ref.read(playerEngineTestDoubleProvider);
    if (engine == null) {
      return const SizedBox.shrink();
    }

    return _EngineSurface(
      key: ObjectKey(engine),
      engine: engine,
      attachment: attachment,
      parkWidth: _parkWidth,
      parkHeight: _parkHeight,
    );
  }
}

class _EngineSurface extends StatefulWidget {
  const _EngineSurface({
    super.key,
    required this.engine,
    required this.attachment,
    required this.parkWidth,
    required this.parkHeight,
  });

  final PlayerEngine engine;
  final PlayerSurfaceAttachment? attachment;
  final double parkWidth;
  final double parkHeight;

  @override
  State<_EngineSurface> createState() => _EngineSurfaceState();
}

class _EngineSurfaceState extends State<_EngineSurface> {
  /// Last on-screen target, held one frame when [widget.attachment] goes null
  /// so a loading → chrome target swap cannot unmount media_kit [Video].
  PlayerSurfaceAttachment? _heldAttachment;

  @override
  void initState() {
    super.initState();
    _heldAttachment = widget.attachment;
    // Convert global target bounds using this stack's size from the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _EngineSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attachment != null) {
      _heldAttachment = widget.attachment;
      return;
    }
    if (oldWidget.attachment == null || widget.engine.keepSurfaceWhenParked) {
      return;
    }
    _heldAttachment = oldWidget.attachment;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.attachment != null) return;
      setState(() => _heldAttachment = null);
    });
  }

  Offset _toLocal(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return global;
    return box.globalToLocal(global);
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final attachment =
        widget.attachment ??
        (engine.keepSurfaceWhenParked ? null : _heldAttachment);
    if (attachment == null && !engine.keepSurfaceWhenParked) {
      // MediaKit: first layout of the Android Surface must be on-screen.
      return const SizedBox.shrink();
    }

    final offset = attachment != null
        ? _toLocal(attachment.offset)
        : Offset(-widget.parkWidth - 64, 0);
    final size = attachment?.size ?? Size(widget.parkWidth, widget.parkHeight);

    Widget stageFor(double w, double h) {
      if (w <= 0 || h <= 0) return const SizedBox.shrink();
      return engine.buildVideoStage(
        context: context,
        maxWidth: w,
        maxHeight: h,
      );
    }

    // The stage always occupies this exact element slot for the engine's
    // lifetime. Target changes only update Positioned geometry; the keyed
    // WebView is never moved between branches. Absolute layout also avoids
    // WebView2 applying a follower transform at the wrong Windows DPI scale.
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: offset.dx,
          top: offset.dy,
          width: size.width,
          height: size.height,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: IgnorePointer(
              ignoring: attachment == null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  stageFor(size.width, size.height),
                  if (attachment?.overlayBuilder != null)
                    attachment!.overlayBuilder!(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
