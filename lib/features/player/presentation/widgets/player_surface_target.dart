/// Registers a viewport for the permanent [PlayerSurfaceHost].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/features/player/application/player_surface_registry.dart';

/// Placeholder slot that reports geometry to [playerSurfaceRegistryProvider].
///
/// The native video surface is painted by [PlayerSurfaceHost] via
/// [CompositedTransformFollower]; this widget only reserves space and may
/// show a poster/loading placeholder underneath.
class PlayerSurfaceTarget extends ConsumerStatefulWidget {
  const PlayerSurfaceTarget({
    required this.id,
    required this.child,
    this.overlayBuilder,
    this.enabled = true,
    super.key,
  });

  final String id;

  /// Content behind the portal surface (poster / loading skeleton).
  final Widget child;

  /// Chrome drawn above the native surface inside the host stack.
  final PlayerSurfaceOverlayBuilder? overlayBuilder;

  /// When false, detaches so the host parks (or hides) the surface.
  final bool enabled;

  @override
  ConsumerState<PlayerSurfaceTarget> createState() =>
      _PlayerSurfaceTargetState();
}

class _PlayerSurfaceTargetState extends ConsumerState<PlayerSurfaceTarget> {
  final Object _owner = Object();
  late final PlayerSurfaceRegistry _registry;

  @override
  void initState() {
    super.initState();
    // Capture notifier while mounted — [dispose] must not use [ref].
    _registry = ref.read(playerSurfaceRegistryProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant PlayerSurfaceTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.overlayBuilder != widget.overlayBuilder) {
      if (oldWidget.id != widget.id || !widget.enabled) {
        final oldId = oldWidget.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _registry.detach(oldId, _owner);
          } on Object {
            // The ProviderScope may have been disposed with the whole app.
          }
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    } else if (widget.enabled) {
      _registry.update(id: widget.id, overlayBuilder: widget.overlayBuilder);
    }
  }

  @override
  void dispose() {
    final id = widget.id;
    final owner = _owner;
    // Provider notifications while Flutter is finalizing this subtree can
    // make a keyed platform view get retaken from `_InactiveElements`.
    // Detach after finalization; link identity prevents a stale callback from
    // detaching a replacement target with the same id.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _registry.detach(id, owner);
      } on Object {
        // The ProviderScope may have been disposed with the whole app.
      }
    });
    super.dispose();
  }

  Offset? _lastOffset;
  Size? _lastSize;

  void _sync() {
    if (!mounted || !widget.enabled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    if (size.width <= 0 || size.height <= 0) return;
    final offset = box.localToGlobal(Offset.zero);

    // Delta gate: skip registry write when geometry hasn't changed.
    if (_lastOffset == offset && _lastSize == size) return;
    _lastOffset = offset;
    _lastSize = size;

    final cur = ref.read(playerSurfaceRegistryProvider);
    if (cur?.id != widget.id) {
      _registry.attach(
        PlayerSurfaceAttachment(
          id: widget.id,
          owner: _owner,
          offset: offset,
          size: size,
          overlayBuilder: widget.overlayBuilder,
        ),
      );
    } else {
      _registry.update(
        id: widget.id,
        offset: offset,
        size: size,
        overlayBuilder: widget.overlayBuilder,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
        return false;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}
