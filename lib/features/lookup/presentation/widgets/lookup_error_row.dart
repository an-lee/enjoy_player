library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/presentation/loading_icon.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/subscription/presentation/credits_failure_actions.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// User-facing text for lookup failures (translation, dictionary, contextual).
///
/// The [CreditsFailure] arm routes through the shared credits message builder
/// (spec 045) so a rejected lookup spells out the credit numbers instead of
/// leaking the raw `HTTP 402` internal string. Cross-feature import is the
/// documented presentation seam (specs/045 contracts/client-presentation-api.md).
String lookupErrorUserMessage(Object error, AppLocalizations l10n) {
  return switch (error) {
    AuthFailure() => l10n.lookupCloudRequiresSignIn,
    // BYOK provider billing rejection — provider copy, never the Enjoy
    // upsell (spec 045 FR-008).
    ProviderBillingFailure() => l10n.byokProviderBillingMessage,
    CreditsFailure() => creditsFailureMessage(error, l10n),
    AppFailure(:final message) => message,
    _ => error.toString(),
  };
}

class LookupErrorRow extends StatefulWidget {
  const LookupErrorRow({
    required this.message,
    required this.onRetry,
    this.isRetrying = false,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  /// Parent-driven busy state (e.g. [AsyncValue.hasError] && [AsyncValue.isLoading]).
  final bool isRetrying;

  @override
  State<LookupErrorRow> createState() => _LookupErrorRowState();
}

class _LookupErrorRowState extends State<LookupErrorRow> {
  bool _tapLatched = false;

  @override
  void didUpdateWidget(covariant LookupErrorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRetrying) {
      if (_tapLatched) setState(() => _tapLatched = false);
    } else if (oldWidget.isRetrying && !widget.isRetrying) {
      if (_tapLatched) setState(() => _tapLatched = false);
    }
  }

  void _handleRetry() {
    setState(() => _tapLatched = true);
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = EnjoyThemeTokens.of(context);
    final busy = widget.isRetrying || _tapLatched;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: scheme.error.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: EdgeInsets.all(t.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: scheme.error,
                  size: 24,
                ),
                SizedBox(width: t.space8),
                Expanded(
                  child: Text(
                    widget.message,
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: t.space12),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(
                  horizontal: t.space16,
                  vertical: t.space8,
                ),
              ),
              onPressed: busy ? null : _handleRetry,
              icon: busy
                  ? LoadingIcon(size: 18, color: scheme.primary)
                  : const Icon(Icons.refresh_rounded, size: 20),
              label: Text(l10n.lookupErrorRetry),
            ),
          ],
        ),
      ),
    );
  }
}
