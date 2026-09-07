/// "Usage analytics" opt-out row (specs/046 US4).
///
/// Persists the device-global capture preference; the analytics provider
/// observes the preference and applies enable/disable on the vendor — the
/// preference is the single source of truth.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/analytics/analytics_capture_pref.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_row.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

final class AnalyticsCaptureToggleRow extends ConsumerWidget {
  const AnalyticsCaptureToggleRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsRow(
      leadingIcon: Icons.insights_outlined,
      title: l10n.settingsAnalyticsCaptureTitle,
      subtitle: l10n.settingsAnalyticsCaptureSubtitle,
      showChevron: false,
      responsive: false,
      trailing: ref
          .watch(analyticsCapturePrefProvider)
          .when(
            data: (enabled) => Switch.adaptive(
              value: enabled,
              onChanged: (value) => unawaited(
                ref
                    .read(analyticsCapturePrefProvider.notifier)
                    .setEnabled(value),
              ),
            ),
            loading: () => const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
    );
  }
}
