/// Current membership card: tier, renewal, credits — cancel stays low-emphasis.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/subscription/application/subscription_purchase_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/subscription/domain/auto_renew_billing.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_status.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/auto_renew_plan_sheet.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/mobile_purchase_unavailable.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/tier_catalog.dart';
import 'package:enjoy_player/core/platform/subscription_purchase_capability.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class SubscriptionStatusCard extends ConsumerWidget {
  const SubscriptionStatusCard({required this.status, super.key});

  final SubscriptionStatus status;

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    AutoRenewBilling ar,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final dateLabel =
        _formatDate(context, ar.currentPeriodEnd) ??
        _formatDate(context, status.subscriptionExpireDate) ??
        l10n.subscriptionNeverExpires;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(l10n.subscriptionAutoRenewCancelConfirmTitle),
          content: Text(
            l10n.subscriptionAutoRenewCancelConfirmMessage(dateLabel),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: Text(l10n.subscriptionAutoRenewCancelConfirmAction),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.subscriptionAutoRenewCancelKeep),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref
          .read(subscriptionPurchaseCtrlProvider.notifier)
          .cancelAutoRenew();
      ref.invalidate(subscriptionStatusProvider);
      if (!context.mounted) return;
      AppNotice.success(
        context,
        l10n.subscriptionAutoRenewCancelSuccess(dateLabel),
      );
    } on AppFailure catch (e) {
      if (!context.mounted) return;
      AppNotice.error(
        context,
        e.message.isNotEmpty
            ? e.message
            : l10n.subscriptionAutoRenewCancelFailed,
      );
    } catch (_) {
      if (!context.mounted) return;
      AppNotice.error(context, l10n.subscriptionAutoRenewCancelFailed);
    }
  }

  Future<void> _extendToPro(BuildContext context) async {
    if (showsMobilePurchaseUnavailable()) {
      await showMobilePurchaseUnavailableDialog(context);
      return;
    }
    if (!supportsExternalSubscriptionPurchase()) return;
    if (!context.mounted) return;
    await showUnifiedPurchaseSheet(
      context,
      tier: SubscriptionTier.pro,
      interval: CatalogInterval.month,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isPaid = status.isPaidTier;
    final ar = status.autoRenew;
    final cancelBusy = ref.watch(subscriptionPurchaseCtrlProvider).isLoading;
    final creditsLabel = l10n.subscriptionDailyCredits(
      NumberFormat.decimalPattern().format(status.dailyCreditsLimit),
    );

    if (isPaid) {
      return _PaidMembershipCard(
        status: status,
        autoRenew: ar,
        creditsLabel: creditsLabel,
        cancelBusy: cancelBusy,
        onCancel: ar != null && ar.isCancelable
            ? () => _cancel(context, ref, ar)
            : null,
        onExtend: status.hasActiveAutoRenewPlan
            ? null
            : () {
                unawaited(_extendToPro(context));
              },
      );
    }

    // Free users get a basic card.
    final tierName = l10n.profileSubscriptionFree;
    final tierDescription = l10n.subscriptionTierFreeDescription;

    return EnjoyCard(
      padding: EdgeInsets.all(t.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 20, color: cs.primary),
              SizedBox(width: t.space8),
              Expanded(
                child: Text(
                  tierName,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _SoftChip(label: l10n.subscriptionActive, emphasized: false),
            ],
          ),
          SizedBox(height: t.space12),
          Text(
            creditsLabel,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: t.space4),
          Text(
            tierDescription,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PaidMembershipCard extends StatelessWidget {
  const _PaidMembershipCard({
    required this.status,
    required this.autoRenew,
    required this.creditsLabel,
    required this.cancelBusy,
    required this.onCancel,
    required this.onExtend,
  });

  final SubscriptionStatus status;
  final AutoRenewBilling? autoRenew;
  final String creditsLabel;
  final bool cancelBusy;
  final VoidCallback? onCancel;
  final VoidCallback? onExtend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ar = autoRenew;
    final renewing = status.hasActiveAutoRenewPlan;
    final endingSoon = ar != null && ar.cancelAtPeriodEnd;
    final isLite = status.isLite;

    final periodDate =
        _formatDate(context, ar?.currentPeriodEnd) ??
        _formatDate(context, status.subscriptionExpireDate);
    final planLabel = ar == null
        ? null
        : ar.interval == 'year'
        ? l10n.subscriptionAutoRenewIntervalYear
        : ar.interval == 'month'
        ? l10n.subscriptionAutoRenewIntervalMonth
        : null;
    final priceLabel = ar?.amount == null
        ? null
        : ar!.interval == 'year'
        ? l10n.subscriptionAutoRenewPriceYear(
            NumberFormat('0.00').format(ar.amount),
          )
        : l10n.subscriptionAutoRenewPriceMonth(
            NumberFormat('0.00').format(ar.amount),
          );
    final tierTitle = isLite
        ? l10n.subscriptionTierLiteName
        : l10n.subscriptionProMemberTitle;
    final tierBadge = isLite
        ? l10n.subscriptionTierLiteName
        : l10n.profileSubscriptionPro;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusXl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.16),
            cs.tertiary.withValues(alpha: 0.10),
            cs.surfaceContainer,
          ],
        ),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          t.space20,
          t.space20,
          t.space20,
          t.space12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(t.space8),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(t.radiusMd),
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: cs.primary,
                    size: 22,
                  ),
                ),
                SizedBox(width: t.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tierTitle,
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: t.space4),
                      Text(
                        [?planLabel, ?priceLabel].join(' · '),
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _SoftChip(
                  label: renewing
                      ? l10n.subscriptionAutoRenewOn
                      : tierBadge,
                  emphasized: true,
                ),
              ],
            ),
            SizedBox(height: t.space16),
            Wrap(
              spacing: t.space8,
              runSpacing: t.space8,
              children: [
                if (periodDate != null)
                  _InfoPill(
                    icon: Icons.event_outlined,
                    label: renewing
                        ? l10n.subscriptionRenewsOn(periodDate)
                        : l10n.subscriptionAccessUntil(periodDate),
                  ),
                _InfoPill(icon: Icons.bolt_rounded, label: creditsLabel),
              ],
            ),
            if (endingSoon) ...[
              SizedBox(height: t.space12),
              Text(
                l10n.subscriptionAutoRenewEndingSoon,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (onExtend != null) ...[
              SizedBox(height: t.space16),
              EnjoyButton.primary(
                onPressed: onExtend,
                child: Text(l10n.subscriptionExtend),
              ),
            ],
            if (onCancel != null) ...[
              SizedBox(height: t.space4),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: cancelBusy ? null : onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant.withValues(
                      alpha: 0.75,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(
                      horizontal: t.space12,
                      vertical: t.space4,
                    ),
                    textStyle: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: cs.onSurfaceVariant.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                  child: Text(l10n.subscriptionAutoRenewCancel),
                ),
              ),
            ] else
              SizedBox(height: t.space8),
          ],
        ),
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.label, required this.emphasized});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? cs.primaryContainer.withValues(alpha: 0.85)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: emphasized ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space12, vertical: t.space8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          SizedBox(width: t.space4),
          Flexible(
            child: Text(
              label,
              style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String? _formatDate(BuildContext context, String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    final date = DateTime.parse(iso).toLocal();
    return DateFormat.yMMMMd(
      Localizations.localeOf(context).toString(),
    ).format(date);
  } catch (_) {
    return iso;
  }
}
