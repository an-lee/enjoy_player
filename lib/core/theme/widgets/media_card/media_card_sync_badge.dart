/// Sync status badge for [MediaCardRow] and [MediaCardTile].
///
/// Derived from `(mediaUrl, syncStatus)` per the table in
/// `specs/043-craft-cloud-sync/contracts/audio-cloud-sync.md#contract-4`:
/// - `synced`     — `mediaUrl != null` (audio is on cloud, playable anywhere)
/// - `pending`    — `mediaUrl == null && syncStatus == 'pending'`
///                  (queued for upload, e.g. crafted offline)
/// - `localOnly`  — everything else (imported files, never-synced crafted)
///
/// Localized tooltip / label strings are resolved from ARB inside the widget
/// via `AppLocalizations.of(context)`.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/l10n/app_localizations.dart';

/// State of the cloud-sync indicator for a library item.
enum MediaCardSyncBadge {
  /// Audio binary is on cloud and playable from any signed-in device.
  synced,

  /// Audio is queued for cloud sync but not yet uploaded (e.g. crafted
  /// while offline; the offline queue will retry on connectivity).
  pending,

  /// Audio is not on cloud — either an imported user file or a pre-feature
  /// crafted audio that has not yet been synced.
  localOnly,
}

/// Pill rendered in the top-right of a media card thumbnail. Visual style
/// mirrors [MediaCardProviderBadgePill] but uses neutral/iconography that
/// distinguishes the three states.
///
/// The tooltip text is resolved from ARB inside the widget via
/// `AppLocalizations.of(context)`, so callers only need to pass the state.
class MediaCardSyncBadgePill extends StatelessWidget {
  const MediaCardSyncBadgePill({
    super.key,
    required this.state,
    this.compact = true,
  });

  final MediaCardSyncBadge state;
  final bool compact;

  IconData get _icon => switch (state) {
    MediaCardSyncBadge.synced => Icons.cloud_done_outlined,
    MediaCardSyncBadge.pending => Icons.cloud_upload_outlined,
    MediaCardSyncBadge.localOnly => Icons.cloud_off_outlined,
  };

  Color _backgroundFor(ColorScheme cs) => switch (state) {
    MediaCardSyncBadge.synced => Colors.green.shade700.withValues(alpha: 0.92),
    MediaCardSyncBadge.pending => cs.surfaceContainerHighest.withValues(
      alpha: 0.92,
    ),
    MediaCardSyncBadge.localOnly => cs.surfaceContainerHighest.withValues(
      alpha: 0.92,
    ),
  };

  Color _foregroundFor(ColorScheme cs) => switch (state) {
    MediaCardSyncBadge.synced => Colors.white,
    MediaCardSyncBadge.pending => cs.onSurfaceVariant,
    MediaCardSyncBadge.localOnly => cs.onSurfaceVariant.withValues(alpha: 0.85),
  };

  String _tooltipFor(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (state) {
      MediaCardSyncBadge.synced => l10n.cloudSyncBadgeSynced,
      MediaCardSyncBadge.pending => l10n.cloudSyncBadgePending,
      MediaCardSyncBadge.localOnly => l10n.cloudSyncBadgeLocalOnly,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: _tooltipFor(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 8,
          vertical: compact ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: _backgroundFor(cs),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(_icon, size: compact ? 12 : 14, color: _foregroundFor(cs)),
      ),
    );
  }
}

/// Helper: derive the [MediaCardSyncBadge] for a row given its
/// [provider], [mediaUrl], and [syncStatus]. Returns `null` for non-craft
/// rows so the badge does not render at all — imported user files and
/// YouTube downloads are explicitly out of scope (FR-005, US-3).
MediaCardSyncBadge? resolveMediaCardSyncBadge({
  required String provider,
  required String? mediaUrl,
  required String? syncStatus,
}) {
  if (provider != 'craft') return null;
  final hasMediaUrl = mediaUrl != null && mediaUrl.isNotEmpty;
  if (hasMediaUrl) return MediaCardSyncBadge.synced;
  if (syncStatus == 'pending') return MediaCardSyncBadge.pending;
  return MediaCardSyncBadge.localOnly;
}
