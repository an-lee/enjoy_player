/// Unified purchase modal — opened after the user picks a paid tier from the
/// catalog. Presents two payment paths in a single cohesive flow:
///
///   1. **Auto-renew** (Stripe Checkout) — primary, default-selected, labeled
///      as the recommended path.
///   2. **Pay once** — secondary; inlines the existing prepaid controls
///      (duration + processor) so the user never has to re-derive the context.
///
/// The legacy "Use balance" path was retired; users with a legacy balance are
/// pointed to the dedicated `BalanceToCredits` card on the subscription page.
///
/// Server rule (preserved): only one non-terminal auto-renew subscription is
/// allowed per account. We surface 409 `SubscriptionConflictFailure` instead of
/// silently swallowing it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/platform/subscription_purchase_capability.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/subscription/application/subscription_plans_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_purchase_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/subscription/domain/payment_processor.dart';
import 'package:enjoy_player/features/subscription/domain/purchase_request.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_plan.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/mobile_purchase_unavailable.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/payment_processor_option.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/subscription_duration_selector.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/tier_catalog.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Payment path chosen inside the unified modal.
enum _PaymentPath { autoRenew, prepaid }

/// Opens the unified purchase modal in auto-renew-default mode.
///
/// Kept for backwards compatibility with callers that don't yet know the
/// selected catalog interval (e.g. legacy upgrade CTAs). New code should call
/// [showUnifiedPurchaseSheet] and pass the tier + interval chosen on the catalog.
Future<void> showAutoRenewPlanSheet(BuildContext context) {
  return showUnifiedPurchaseSheet(
    context,
    tier: SubscriptionTier.pro,
    interval: CatalogInterval.month,
  );
}

/// Opens the unified purchase modal at the chosen catalog tier + interval.
///
/// On compact widths this is a bottom sheet; on wide widths it presents as a
/// centered adaptive dialog so the side-by-side payment cards stay legible.
Future<void> showUnifiedPurchaseSheet(
  BuildContext context, {
  required SubscriptionTier tier,
  required CatalogInterval interval,
}) async {
  if (showsMobilePurchaseUnavailable()) {
    await showMobilePurchaseUnavailableDialog(context);
    return;
  }
  if (!supportsExternalSubscriptionPurchase()) return;
  if (!context.mounted) return;
  await showEnjoyAdaptiveSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) =>
        _UnifiedPurchaseSheetBody(initialTier: tier, initialInterval: interval),
  );
}

class _UnifiedPurchaseSheetBody extends ConsumerStatefulWidget {
  const _UnifiedPurchaseSheetBody({
    required this.initialTier,
    required this.initialInterval,
  });

  final SubscriptionTier initialTier;
  final CatalogInterval initialInterval;

  @override
  ConsumerState<_UnifiedPurchaseSheetBody> createState() =>
      _UnifiedPurchaseSheetBodyState();
}

class _UnifiedPurchaseSheetBodyState
    extends ConsumerState<_UnifiedPurchaseSheetBody> {
  late _PaymentPath _path;
  late int _months;
  late PaymentProcessor _processor;

  @override
  void initState() {
    super.initState();
    _path = _PaymentPath.autoRenew;
    _months = widget.initialInterval == CatalogInterval.year ? 12 : 1;
    _processor = PaymentProcessor.stripe;
  }

  double? _prepaidTotal(List<SubscriptionPlan> plans) {
    final unit = prepaidUnitPriceForTier(plans, widget.initialTier.name);
    if (unit == null) return null;
    return _months * unit;
  }

  SubscriptionPlan? _resolvePlan(
    List<SubscriptionPlan> plans,
    CatalogInterval target,
    SubscriptionTier tier,
  ) {
    final tierName = tier.name;
    for (final plan in plans) {
      if (catalogIntervalFromString(plan.interval) == target &&
          plan.tier == tierName) {
        return plan;
      }
    }
    return null;
  }

  Future<void> _startAutoRenew(SubscriptionPlan plan) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(subscriptionPurchaseCtrlProvider.notifier)
          .startAutoRenewExternal(planId: plan.id);
      if (!mounted) return;
      Navigator.pop(context);
      AppNotice.info(context, l10n.subscriptionRedirectingToPayment);
    } on SubscriptionConflictFailure catch (e) {
      if (!mounted) return;
      AppNotice.error(
        context,
        e.message.isNotEmpty ? e.message : l10n.subscriptionAutoRenewConflict,
      );
    } on AppFailure catch (e) {
      if (!mounted) return;
      AppNotice.error(
        context,
        e.message.isNotEmpty ? e.message : l10n.subscriptionPurchaseFailed,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = switch (e.toString()) {
        final s
            when s.contains('missing_pay_url') ||
                s.contains('invalid_pay_url') =>
          l10n.subscriptionPaymentUrlMissing,
        final s when s.contains('launch_failed') =>
          l10n.subscriptionPaymentLaunchFailed,
        _ => l10n.subscriptionPurchaseFailed,
      };
      AppNotice.error(context, msg);
    }
  }

  Future<void> _startPrepaidPurchase() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(subscriptionPurchaseCtrlProvider.notifier)
          .purchaseExternal(
            months: _months,
            processor: _processor,
            tier: widget.initialTier.name,
          );
      if (!mounted) return;
      Navigator.pop(context);
      AppNotice.info(context, l10n.subscriptionRedirectingToPayment);
    } catch (e) {
      if (!mounted) return;
      final message = switch (e) {
        StateError(:final message) when message == 'missing_pay_url' =>
          l10n.subscriptionPaymentUrlMissing,
        StateError(:final message) when message == 'launch_failed' =>
          l10n.subscriptionPaymentLaunchFailed,
        StateError(:final message) when message == 'invalid_pay_url' =>
          l10n.subscriptionPaymentUrlMissing,
        AppFailure(:final message) => message,
        _ => l10n.subscriptionPurchaseFailed,
      };
      AppNotice.error(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final tt = Theme.of(context).textTheme;
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final busy = ref.watch(subscriptionPurchaseCtrlProvider).isLoading;
    final status = ref.watch(subscriptionStatusProvider).valueOrNull;
    final hasActiveAutoRenew = status?.hasActiveAutoRenewPlan ?? false;

    final interval = widget.initialInterval;
    final intervalLabel = interval == CatalogInterval.year
        ? l10n.subscriptionAutoRenewYearly
        : l10n.subscriptionAutoRenewMonthly;
    final tierLabel = widget.initialTier == SubscriptionTier.lite
        ? l10n.subscriptionTierLiteName
        : l10n.subscriptionTierProName;

    // Resolve the selected plan from the loaded plans list. When the provider
    // is still loading, errored, or returned an empty list, the bottom panel
    // stays hidden. When plans loaded but no row matches the chosen
    // tier/interval, [selectedPlan] is null and the CTA is shown disabled —
    // never a hardcoded fallback price.
    final selectedPlan = plansAsync.maybeWhen(
      data: (plans) => plans.isEmpty
          ? null
          : _resolvePlan(plans, interval, widget.initialTier),
      orElse: () => null,
    );
    final plansLoadedNonEmpty = plansAsync.maybeWhen(
      data: (plans) => plans.isNotEmpty,
      orElse: () => false,
    );

    final unitPrice = plansAsync.maybeWhen(
      data: (plans) => prepaidUnitPriceForTier(plans, widget.initialTier.name),
      orElse: () => null,
    );
    final prepaidTotal = plansAsync.maybeWhen(
      data: (plans) => _prepaidTotal(plans),
      orElse: () => null,
    );

    // The path defaults to auto-renew; if an active auto-renew already exists
    // the CTA is disabled and a warning explains why — the user can still
    // switch to the prepaid path to top up their period.

    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            t.space20,
            t.space16,
            t.space20,
            t.space24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.subscriptionPurchaseModalUnifiedTitle(
                          tierLabel,
                          intervalLabel,
                        ),
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: t.space4),
                Text(
                  l10n.subscriptionPurchaseModalUnifiedDescription,
                  style: tt.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: t.space16),
                if (hasActiveAutoRenew) ...[
                  _ActiveAutoRenewWarning(),
                  SizedBox(height: t.space16),
                ],
                plansAsync.when(
                  data: (plans) {
                    if (plans.isEmpty) {
                      return _UnavailablePlansView(
                        label: l10n.subscriptionAutoRenewPlansUnavailable,
                        onRetry: () =>
                            ref.invalidate(subscriptionPlansProvider),
                      );
                    }
                    return _PaymentPathSelector(
                      selected: _path,
                      interval: interval,
                      intervalLabel: intervalLabel,
                      plan: selectedPlan,
                      unitPrice: unitPrice,
                      plansLoading: false,
                      onChanged: busy
                          ? null
                          : (path) => setState(() => _path = path),
                    );
                  },
                  loading: () => const _PlansLoadingPlaceholder(),
                  error: (_, _) => _UnavailablePlansView(
                    label: l10n.subscriptionAutoRenewPlansUnavailable,
                    onRetry: () => ref.invalidate(subscriptionPlansProvider),
                  ),
                ),
                SizedBox(height: t.space16),
                if (plansLoadedNonEmpty)
                  if (_path == _PaymentPath.autoRenew)
                    _AutoRenewPanel(
                      busy: busy,
                      blocked: hasActiveAutoRenew,
                      plan: selectedPlan,
                      onSubscribe: busy || selectedPlan == null
                          ? null
                          : () => _startAutoRenew(selectedPlan),
                    )
                  else
                    _PrepaidPanel(
                      months: _months,
                      processor: _processor,
                      busy: busy,
                      unitPrice: unitPrice,
                      totalPrice: prepaidTotal,
                      onMonthsChanged: (m) => setState(() => _months = m),
                      onProcessorChanged: (p) => setState(() => _processor = p),
                      onContinue: busy || unitPrice == null
                          ? null
                          : _startPrepaidPurchase,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveAutoRenewWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.4), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(t.space12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.onTertiaryContainer),
            SizedBox(width: t.space12),
            Expanded(
              child: Text(
                l10n.subscriptionPurchaseModalAutoRenewActiveWarning,
                style: tt.bodyMedium?.copyWith(color: cs.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentPathSelector extends StatelessWidget {
  const _PaymentPathSelector({
    required this.selected,
    required this.interval,
    required this.intervalLabel,
    required this.plan,
    required this.unitPrice,
    required this.plansLoading,
    required this.onChanged,
  });

  final _PaymentPath selected;
  final CatalogInterval interval;
  final String intervalLabel;
  final SubscriptionPlan? plan;
  final double? unitPrice;
  final bool plansLoading;
  final ValueChanged<_PaymentPath>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        final prepaidUnitPrice = unitPrice;
        final autoRenewCard = _PaymentOptionCard(
          path: _PaymentPath.autoRenew,
          selected: selected == _PaymentPath.autoRenew,
          onTap: onChanged == null
              ? null
              : () => onChanged!(_PaymentPath.autoRenew),
          title: l10n.subscriptionPurchaseModalOptionAutoRenew,
          subtitle: l10n.subscriptionPurchaseModalOptionAutoRenewSubtitle,
          footnote: l10n.subscriptionPurchaseModalOptionAutoRenewFootnote,
          leadingIcon: Icons.autorenew_rounded,
          emphasis: true,
          price: _autoRenewPriceLabel(l10n, plan, interval),
          plansLoading: plansLoading,
          intervalLabel: intervalLabel,
        );
        final prepaidCard = _PaymentOptionCard(
          path: _PaymentPath.prepaid,
          selected: selected == _PaymentPath.prepaid,
          onTap: onChanged == null
              ? null
              : () => onChanged!(_PaymentPath.prepaid),
          title: l10n.subscriptionPurchaseModalOptionPrepaid,
          subtitle: l10n.subscriptionPurchaseModalOptionPrepaidSubtitle,
          footnote: l10n.subscriptionPurchaseModalOptionPrepaidFootnote,
          leadingIcon: Icons.event_available_rounded,
          price: prepaidUnitPrice != null
              ? l10n.subscriptionAutoRenewPriceMonth(
                  prepaidUnitPrice.toStringAsFixed(2),
                )
              : '—',
          plansLoading: false,
          intervalLabel: null,
        );

        if (wide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: autoRenewCard),
                const SizedBox(width: 12),
                Expanded(child: prepaidCard),
              ],
            ),
          );
        }
        return Column(
          children: [autoRenewCard, const SizedBox(height: 12), prepaidCard],
        );
      },
    );
  }

  String _autoRenewPriceLabel(
    AppLocalizations l10n,
    SubscriptionPlan? plan,
    CatalogInterval interval,
  ) {
    if (plan != null) {
      final formatted = NumberFormat('0.00').format(plan.amount);
      return l10n.subscriptionAutoRenewPriceMonth(formatted);
    }
    return '—';
  }
}

class _PaymentOptionCard extends StatelessWidget {
  const _PaymentOptionCard({
    required this.path,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.footnote,
    required this.leadingIcon,
    required this.price,
    required this.plansLoading,
    required this.intervalLabel,
    required this.onTap,
    this.emphasis = false,
  });

  final _PaymentPath path;
  final bool selected;
  final String title;
  final String subtitle;
  final String footnote;
  final IconData leadingIcon;
  final String price;
  final bool plansLoading;
  final String? intervalLabel;
  final bool emphasis;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final color = selected ? cs.primary : cs.outlineVariant;
    final bg = selected
        ? cs.primaryContainer.withValues(alpha: 0.45)
        : cs.surfaceContainerHighest.withValues(alpha: 0.45);

    final card = EnjoyCard(
      padding: EdgeInsets.all(t.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              SizedBox(width: t.space12),
              Icon(leadingIcon, size: 18, color: cs.onSurfaceVariant),
              SizedBox(width: t.space8),
              Expanded(
                child: Text(
                  title,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: t.space8),
          Padding(
            padding: EdgeInsets.only(left: t.space32),
            child: Text(
              subtitle,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          SizedBox(height: t.space12),
          Padding(
            padding: EdgeInsets.only(left: t.space32),
            child: plansLoading && emphasis
                ? Container(
                    width: 96,
                    height: 18,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(t.radiusSm),
                    ),
                  )
                : Text(
                    emphasis
                        ? '$price${intervalLabel != null ? ' · $intervalLabel' : ''}'
                        : price,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: emphasis ? cs.primary : null,
                    ),
                  ),
          ),
          SizedBox(height: t.space8),
          Padding(
            padding: EdgeInsets.only(left: t.space32),
            child: Text(
              footnote,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusLg),
          side: BorderSide(color: color, width: selected ? 1.6 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(2), child: card),
        ),
      ),
    );
  }
}

class _AutoRenewPanel extends StatelessWidget {
  const _AutoRenewPanel({
    required this.busy,
    required this.blocked,
    required this.plan,
    required this.onSubscribe,
  });

  final bool busy;
  final bool blocked;
  final SubscriptionPlan? plan;
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final disabled = busy || blocked || plan == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(t.radiusMd),
          ),
          child: Padding(
            padding: EdgeInsets.all(t.space12),
            child: Text(
              l10n.subscriptionAutoRenewProvider('Stripe'),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
        SizedBox(height: t.space12),
        EnjoyButton.primary(
          onPressed: disabled ? null : onSubscribe,
          child: busy
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: t.space12),
                    Text(l10n.subscriptionRedirectingToPayment),
                  ],
                )
              : Text(l10n.subscriptionPurchaseModalSubscribeAutoRenewCta),
        ),
      ],
    );
  }
}

class _PrepaidPanel extends StatelessWidget {
  const _PrepaidPanel({
    required this.months,
    required this.processor,
    required this.busy,
    required this.unitPrice,
    required this.totalPrice,
    required this.onMonthsChanged,
    required this.onProcessorChanged,
    required this.onContinue,
  });

  final int months;
  final PaymentProcessor processor;
  final bool busy;
  final double? unitPrice;
  final double? totalPrice;
  final ValueChanged<int> onMonthsChanged;
  final ValueChanged<PaymentProcessor> onProcessorChanged;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubscriptionDurationSelector(
          months: months,
          enabled: !busy,
          onMonthsChanged: onMonthsChanged,
        ),
        SizedBox(height: t.space16),
        Text(l10n.subscriptionPurchasePaymentMethod, style: tt.titleSmall),
        SizedBox(height: t.space8),
        PaymentProcessorOption(
          processor: PaymentProcessor.stripe,
          selected: processor == PaymentProcessor.stripe,
          enabled: !busy,
          onSelected: () => onProcessorChanged(PaymentProcessor.stripe),
        ),
        SizedBox(height: t.space8),
        PaymentProcessorOption(
          processor: PaymentProcessor.mixin,
          selected: processor == PaymentProcessor.mixin,
          enabled: !busy,
          onSelected: () => onProcessorChanged(PaymentProcessor.mixin),
        ),
        SizedBox(height: t.space12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(t.radiusMd),
          ),
          child: Padding(
            padding: EdgeInsets.all(t.space16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.subscriptionTotalPriceLabel),
                Text(
                  l10n.subscriptionTotalPrice(
                    totalPrice?.toStringAsFixed(2) ?? '—',
                  ),
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: t.space16),
        EnjoyButton.primary(
          onPressed: onContinue,
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.subscriptionContinueToPayment),
        ),
      ],
    );
  }
}

class _PlansLoadingPlaceholder extends StatelessWidget {
  const _PlansLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space24),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _UnavailablePlansView extends StatelessWidget {
  const _UnavailablePlansView({required this.label, required this.onRetry});

  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return EnjoyCard(
      padding: EdgeInsets.all(t.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: t.space12),
          Align(
            alignment: Alignment.centerRight,
            child: EnjoyButton.secondary(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ),
        ],
      ),
    );
  }
}
