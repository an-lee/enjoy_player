/// Balance → Credits conversion card.
///
/// Replaces the legacy "use balance" path that used to live inside the
/// prepaid purchase flow (see `purchase_sheet.dart`). The actual conversion
/// runs server-side; this widget is a discoverable pointer to the dedicated
/// flow on the credits page.
///
/// When the desktop credits transfer page is not yet wired up, tapping the CTA
/// surfaces a "coming soon" notice so users still see the path exists. The
/// card only renders when the user's profile carries a transferable balance
/// (legacy USD balance > 0). When `forceShow` is true, it renders in an empty
/// state explaining how the flow will appear once a balance is present.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Published transfer rate: $1 legacy balance → this many permanent credits.
/// Mirrors `TRANSFER_CREDITS_PER_USD` on the web app (credits-helpers.ts).
const int kBalanceToCreditsRate = 100000;

/// Returns the permanent credits preview for the given USD balance (floor).
int previewBalanceToCredits(double usd) {
  if (!usd.isFinite || usd <= 0) return 0;
  return (usd * kBalanceToCreditsRate).floor();
}

/// True when the legacy USD balance can yield at least 1 permanent credit.
bool isTransferableBalance(double usd) => previewBalanceToCredits(usd) >= 1;

class BalanceToCredits extends ConsumerWidget {
  const BalanceToCredits({super.key, this.forceShow = false});

  /// Render the card even when balance is 0 — used to teach users about the
  /// upcoming flow.
  final bool forceShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authCtrlProvider);
    final balance = auth.valueOrNull is AuthSignedIn
        ? (auth.valueOrNull as AuthSignedIn).profile.balance ?? 0
        : 0.0;

    if (auth.isLoading) {
      return const _BalanceToCreditsSkeleton();
    }

    final transferable = isTransferableBalance(balance);
    if (!transferable && !forceShow) {
      return const SizedBox.shrink();
    }

    final usdLabel = NumberFormat.simpleCurrency(name: 'USD').format(balance);
    final previewCredits = previewBalanceToCredits(balance);

    return EnjoyCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(EnjoyThemeTokens.of(context).space16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;
            final body = _BalanceToCreditsBody(
              usdLabel: usdLabel,
              previewCredits: previewCredits,
              transferable: transferable,
            );
            final cta = _BalanceToCreditsCta(
              enabled: transferable,
              onPressed: transferable
                  ? () => _openTransferFlow(context, usdLabel)
                  : null,
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: body),
                  SizedBox(width: EnjoyThemeTokens.of(context).space16),
                  cta,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                body,
                SizedBox(height: EnjoyThemeTokens.of(context).space16),
                Align(alignment: Alignment.centerRight, child: cta),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openTransferFlow(BuildContext context, String usdLabel) async {
    final l10n = AppLocalizations.of(context)!;
    // TODO(credits-transfer): route to the dedicated `/credits?transfer=1`
    // page once it ships on desktop. Until then, surface a friendly
    // notice so users still see the path exists.
    await showEnjoyAlertDialog<void>(
      context: context,
      title: Text(l10n.subscriptionBalanceToCreditsComingSoonTitle),
      content: Text(
        l10n.subscriptionBalanceToCreditsComingSoonMessage(usdLabel),
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}

class _BalanceToCreditsBody extends StatelessWidget {
  const _BalanceToCreditsBody({
    required this.usdLabel,
    required this.previewCredits,
    required this.transferable,
  });

  final String usdLabel;
  final int previewCredits;
  final bool transferable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final description = transferable
        ? l10n.subscriptionBalanceToCreditsDescriptionWithPreview(
            usdLabel,
            previewCredits.toString(),
          )
        : l10n.subscriptionBalanceToCreditsDescriptionEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconBadge(icon: Icons.account_balance_wallet_rounded, cs: cs),
        SizedBox(width: t.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: t.space8,
                runSpacing: t.space4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.subscriptionBalanceToCreditsTitle,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (transferable)
                    _BalanceBadge(label: usdLabel, cs: cs, tt: tt),
                ],
              ),
              SizedBox(height: t.space4),
              Text(
                description,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceToCreditsCta extends StatelessWidget {
  const _BalanceToCreditsCta({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EnjoyButton.secondary(
      onPressed: enabled ? onPressed : null,
      icon: Icons.arrow_forward_rounded,
      child: Text(l10n.subscriptionBalanceToCreditsCta),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.cs});

  final IconData icon;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(t.radiusFull),
      ),
      child: Padding(
        padding: EdgeInsets.all(t.space12),
        child: Icon(icon, color: cs.onPrimaryContainer, size: 22),
      ),
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  const _BalanceBadge({
    required this.label,
    required this.cs,
    required this.tt,
  });

  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.savings_rounded, size: 12, color: cs.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceToCreditsSkeleton extends StatelessWidget {
  const _BalanceToCreditsSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    return EnjoyCard(
      child: Padding(
        padding: EdgeInsets.all(t.space16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(t.radiusFull),
              ),
            ),
            SizedBox(width: t.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 220,
                    height: 14,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(t.radiusSm),
                    ),
                  ),
                  SizedBox(height: t.space8),
                  Container(
                    width: double.infinity,
                    height: 10,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(t.radiusSm),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: t.space12),
            Container(
              width: 140,
              height: 36,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(t.radiusMd),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
