/// Shared loading affordance for transcript manual actions.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/presentation/loading_icon.dart';

/// Outlined or filled action button with inline loading spinner.
class TranscriptBusyButton extends StatefulWidget {
  const TranscriptBusyButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;
  final bool filled;

  @override
  State<TranscriptBusyButton> createState() => _TranscriptBusyButtonState();
}

class _TranscriptBusyButtonState extends State<TranscriptBusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _busy
        ? LoadingIcon(
            size: 18,
            color: widget.filled
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.primary,
          )
        : Icon(widget.icon);

    final button = widget.filled
        ? FilledButton.icon(
            onPressed: _busy ? null : _run,
            icon: icon,
            label: Text(widget.label),
          )
        : OutlinedButton.icon(
            onPressed: _busy ? null : _run,
            icon: icon,
            label: Text(widget.label),
          );
    return SizedBox(width: double.infinity, child: button);
  }
}

/// [ListTile] row with a busy leading icon for picker actions.
class TranscriptBusyListTile extends StatefulWidget {
  const TranscriptBusyListTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.busy,
    this.tapWhenBusy = false,
    this.contentPadding,
    this.progress,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Future<void> Function() onTap;

  /// When non-null, the spinner follows this flag instead of a local future.
  final bool? busy;

  /// When true, [onTap] stays enabled while busy (cancel / retry).
  final bool tapWhenBusy;
  final EdgeInsetsGeometry? contentPadding;

  /// Determinate `0…1` while [busy]. Null keeps an indeterminate spinner.
  final double? progress;

  @override
  State<TranscriptBusyListTile> createState() => _TranscriptBusyListTileState();
}

class _TranscriptBusyListTileState extends State<TranscriptBusyListTile> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showBusy = widget.busy ?? _busy;
    final usesExternalBusy = widget.busy != null;
    final tapEnabled = widget.tapWhenBusy || !showBusy;
    final progress = showBusy ? widget.progress : null;
    final tile = ListTile(
      contentPadding: widget.contentPadding,
      leading: showBusy
          ? LoadingIcon(size: 24, color: cs.primary, value: progress)
          : Icon(widget.icon, size: 24, color: cs.onSurfaceVariant),
      title: Text(widget.title),
      subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
      enabled: tapEnabled,
      onTap: !tapEnabled
          ? null
          : usesExternalBusy
          ? widget.onTap
          : _run,
    );
    if (progress == null) return tile;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        LinearProgressIndicator(minHeight: 2, value: progress.clamp(0.0, 1.0)),
      ],
    );
  }
}
