/// Tier catalog: unified Free / Lite / Pro selection with a Monthly / Yearly toggle.
///
/// Replaces the previous free-vs-Pro comparison layout that lived in the
/// subscription screen. The Free card is read-only — it always reflects the
/// user's current tier when applicable. The Lite and Pro cards expose an
/// [onChoosePaid] callback that the host page wires up to the unified
/// purchase modal (auto-renew primary, prepaid secondary).
///
/// **Pricing is sourced from the catalog endpoint** (`GET /api/v1/subscriptions/plans`).
/// When a plan has not loaded yet, the price line renders a skeleton rather
/// than a hardcoded fallback — the Rails API is the single source of truth.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/subscription/application/subscription_plans_provider.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_plan.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_status.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Billing interval for the catalog's price toggle.
enum CatalogInterval { month, year }

CatalogInterval _intervalFromString(String s) =>
    s == 'year' ? CatalogInterval.year : CatalogInterval.month;

String _intervalToString(CatalogInterval interval) =>
    interval == CatalogInterval.year ? 'year' : 'month';

/// Approximate savings percentage when paying yearly vs monthly for a tier.
///
/// Returns the integer percentage (e.g. `17` for a 17% saving) or `null` when
/// the inputs are missing or non-positive.
int? _savingsPercentForTier(List<SubscriptionPlan> plans, String tier) {
  SubscriptionPlan? monthly;
  SubscriptionPlan? yearly;
  for (final plan in plans) {
    if (plan.tier != tier) continue;
    if (plan.isYearly) {
      yearly = plan;
    } else {
      monthly = plan;
    }
  }
  if (monthly == null || yearly == null) return null;
  if (monthly.amount <= 0) return null;
  final monthlyAnnual = monthly.amount * 12;
  if (monthlyAnnual <= 0) return null;
  final ratio = 1 - (yearly.amount / monthlyAnnual);
  if (ratio.isNaN || ratio.isInfinite) return null;
  final pct = (ratio * 100).round();
  return pct <= 0 ? null : pct;
}

class TierCatalog extends ConsumerStatefulWidget {
  const TierCatalog({
    required this.status,
    this.onChoosePaid,
    @Deprecated('Use onChoosePaid.') this.onChoosePro,
    super.key,
  });

  final SubscriptionStatus status;

  /// Fired when the user taps a paid tier's CTA (Lite or Pro). The host wires
  /// this to the unified purchase modal (auto-renew primary, prepaid secondary).
  final void Function(SubscriptionTier tier, CatalogInterval interval)?
      onChoosePaid;

  /// Backwards-compatible alias for Pro-only callers. Prefer [onChoosePaid].
  @Deprecated('Use onChoosePaid. Pass SubscriptionTier.pro explicitly.')
  final void Function(CatalogInterval interval)? onChoosePro;

  @override
  ConsumerState<TierCatalog> createState() => _TierCatalogState();
}

class _TierCatalogState extends ConsumerState<TierCatalog> {
  CatalogInterval _interval = CatalogInterval.month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final tt = Theme.of(context).textTheme;
    final plansAsync = ref.watch(subscriptionPlansProvider);

    // Hide the catalog entirely when a non-terminal auto-renew blocks new
    // subscriptions — the status card already conveys the entitlement.
    if (widget.status.hasActiveAutoRenewPlan) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.subscriptionTierCatalogTitle,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: t.space4),
        Text(
          l10n.subscriptionTierCatalogDescription,
          style: tt.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: t.space20),
        plansAsync.when(
          data: (plans) => _buildContent(context, plans),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _PlansError(
            onRetry: () => ref.invalidate(subscriptionPlansProvider),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, List<SubscriptionPlan> plans) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Pick the better savings percent across Lite and Pro (helps the yearly
    // badge stay meaningful when either tier is missing from the catalog).
    final liteSavings = _savingsPercentForTier(plans, 'lite');
    final proSavings = _savingsPercentForTier(plans, 'pro');
    final savingsPercent = proSavings ?? liteSavings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IntervalToggle(
          value: _interval,
          onChanged: (v) => setState(() => _interval = v),
          yearlyLabel: l10n.subscriptionAutoRenewYearly,
          monthlyLabel: l10n.subscriptionAutoRenewMonthly,
          savingsLabel: savingsPercent == null
              ? null
              : l10n.subscriptionTierCatalogIntervalYearSavings(
                  '$savingsPercent',
                ),
        ),
        SizedBox(height: t.space20),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 840;
            final freeCard = _FreeTierCard(
              isCurrent: widget.status.subscriptionTier == SubscriptionTier.free,
            );
            final liteCard = _PaidTierCard(
              tier: SubscriptionTier.lite,
              plans: plans,
              interval: _interval,
              isCurrent: widget.status.subscriptionTier == SubscriptionTier.lite,
              isLowerThanCurrent:
                  widget.status.subscriptionTier == SubscriptionTier.pro,
              onChoose: () => _onChoosePaid(SubscriptionTier.lite),
            );
            final proCard = _PaidTierCard(
              tier: SubscriptionTier.pro,
              plans: plans,
              interval: _interval,
              isCurrent: widget.status.subscriptionTier == SubscriptionTier.pro,
              isLowerThanCurrent: false,
              onChoose: () => _onChoosePaid(SubscriptionTier.pro),
            );
            if (wide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: freeCard),
                    SizedBox(width: t.space12),
                    Expanded(child: liteCard),
                    SizedBox(width: t.space12),
                    Expanded(child: proCard),
                  ],
                ),
              );
            }
            return Column(
              children: [
                proCard,
                SizedBox(height: t.space16),
                liteCard,
                SizedBox(height: t.space16),
                freeCard,
              ],
            );
          },
        ),
        SizedBox(height: t.space12),
        Text(
          l10n.subscriptionAutoRenewProvider('Stripe'),
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  void _onChoosePaid(SubscriptionTier tier) {
    // New callback first.
    widget.onChoosePaid?.call(tier, _interval);
    // Legacy alias: only Pro had a callback historically.
    if (tier == SubscriptionTier.pro) {
      // ignore: deprecated_member_use_from_same_package
      widget.onChoosePro?.call(_interval);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<CatalogInterval>('interval', _interval),
    );
  }
}

class _IntervalToggle extends StatelessWidget {
  const _IntervalToggle({
    required this.value,
    required this.onChanged,
    required this.monthlyLabel,
    required this.yearlyLabel,
    this.savingsLabel,
  });

  final CatalogInterval value;
  final ValueChanged<CatalogInterval> onChanged;
  final String monthlyLabel;
  final String yearlyLabel;
  final String? savingsLabel;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final toggle = DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(t.radiusFull),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IntervalChip(
              label: monthlyLabel,
              selected: value == CatalogInterval.month,
              onTap: () => onChanged(CatalogInterval.month),
              tt: tt,
            ),
            _IntervalChip(
              label: yearlyLabel,
              selected: value == CatalogInterval.year,
              onTap: () => onChanged(CatalogInterval.year),
              tt: tt,
            ),
          ],
        ),
      ),
    );
    if (savingsLabel == null) {
      return Center(child: toggle);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final savings = _SavingsBadge(label: savingsLabel!, tt: tt);
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              toggle,
              SizedBox(height: t.space8),
              savings,
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            toggle,
            SizedBox(width: t.space8),
            Flexible(child: savings),
          ],
        );
      },
    );
  }
}

class _SavingsBadge extends StatelessWidget {
  const _SavingsBadge({required this.label, required this.tt});

  final String label;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space8,
        vertical: t.space4 / 2,
      ),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(t.radiusFull),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onTertiaryContainer,
        ),
      ),
    );
  }
}

class _IntervalChip extends StatelessWidget {
  const _IntervalChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tt,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radiusFull),
        onTap: onTap,
        child: AnimatedContainer(
          duration: t.motionFast,
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: t.space20,
            vertical: t.space8,
          ),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(t.radiusFull),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? cs.onPrimary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _FreeTierCard extends StatelessWidget {
  const _FreeTierCard({required this.isCurrent});

  final bool isCurrent;

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
          if (isCurrent)
            Align(
              alignment: Alignment.centerLeft,
              child: _Pill(
                label: l10n.subscriptionCurrentPlan,
                color: cs.secondaryContainer,
                textColor: cs.onSecondaryContainer,
                tt: tt,
              ),
            ),
          if (isCurrent) SizedBox(height: t.space8),
          Text(
            l10n.subscriptionTierFreeName,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: t.space4),
          Text(
            l10n.subscriptionTierFreeDescription,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: t.space16),
          Text(
            l10n.subscriptionTierFreePrice,
            style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: t.space4),
          Text(
            l10n.subscriptionTierFreeDailyCredits,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: t.space16),
          for (final feature in _freeFeatures(l10n)) ...[
            _Bullet(text: feature, emphasize: false, tt: tt),
            SizedBox(height: t.space8),
          ],
          SizedBox(height: t.space16),
          EnjoyButton.secondary(
            onPressed: null,
            child: Text(
              isCurrent
                  ? l10n.subscriptionCurrentPlan
                  : l10n.subscriptionTierCatalogNotSelected,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _freeFeatures(AppLocalizations l10n) => [
    l10n.subscriptionFeatureFreeTranslation,
    l10n.subscriptionFeatureFreeSmartTranslation,
    l10n.subscriptionFeatureFreeDictionary,
    l10n.subscriptionFeatureFreeAsr,
    l10n.subscriptionFeatureFreeTts,
    l10n.subscriptionFeatureFreeAssessment,
  ];
}

class _PaidTierCard extends StatelessWidget {
  const _PaidTierCard({
    required this.tier,
    required this.plans,
    required this.interval,
    required this.isCurrent,
    required this.isLowerThanCurrent,
    required this.onChoose,
  });

  final SubscriptionTier tier;
  final List<SubscriptionPlan> plans;
  final CatalogInterval interval;
  final bool isCurrent;
  final bool isLowerThanCurrent;
  final VoidCallback onChoose;

  bool get _isLite => tier == SubscriptionTier.lite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final selectedPlan = _resolvePlan(plans, interval, tier);
    final fallbackPlan = _resolvePlan(plans, CatalogInterval.month, tier);
    final resolved = selectedPlan ?? fallbackPlan;
    final amount = resolved != null
        ? NumberFormat('0.00').format(resolved.amount)
        : null;
    final unitLabel = interval == CatalogInterval.year
        ? l10n.subscriptionTierCatalogPerYear
        : l10n.subscriptionTierCatalogPerMonth;

    final tierName = _isLite
        ? l10n.subscriptionTierLiteName
        : l10n.subscriptionTierProName;
    final tierDescription = _isLite
        ? l10n.subscriptionTierLiteDescription
        : l10n.subscriptionTierProDescription;
    final dailyCredits = _isLite
        ? l10n.subscriptionTierLiteDailyCredits
        : l10n.subscriptionTierProDailyCredits;
    final features = _isLite
        ? _liteFeatures(l10n)
        : _proFeatures(l10n);

    final ctaLabel = isCurrent
        ? (_isLite
            ? l10n.subscriptionTierCatalogExtendLite
            : l10n.subscriptionTierCatalogExtendPro)
        : (_isLite
            ? l10n.subscriptionTierCatalogChooseLite
            : l10n.subscriptionTierCatalogChoosePro);
    final ctaEnabled = !isLowerThanCurrent && resolved != null;
    final ctaLabelActual = isLowerThanCurrent
        ? l10n.subscriptionTierCatalogNotSelected
        : ctaLabel;

    final inner = EnjoyCard(
      padding: EdgeInsets.all(t.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lite card has no "Recommended" badge — Pro is the recommended tier.
          if (!_isLite) ...[
            Row(
              children: [
                _Pill(
                  label: l10n.subscriptionTierCatalogRecommended,
                  color: cs.primary,
                  textColor: cs.onPrimary,
                  tt: tt,
                  leading: Icons.auto_awesome_rounded,
                ),
                if (isCurrent) ...[
                  SizedBox(width: t.space8),
                  _Pill(
                    label: l10n.subscriptionCurrentPlan,
                    color: cs.secondaryContainer,
                    textColor: cs.onSecondaryContainer,
                    tt: tt,
                  ),
                ],
              ],
            ),
            SizedBox(height: t.space12),
          ] else if (isCurrent) ...[
            _Pill(
              label: l10n.subscriptionCurrentPlan,
              color: cs.secondaryContainer,
              textColor: cs.onSecondaryContainer,
              tt: tt,
            ),
            SizedBox(height: t.space12),
          ],
          Text(
            tierName,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: t.space4),
          Text(
            tierDescription,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: t.space16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: amount != null
                    ? Text(
                        '\$$amount',
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _isLite ? null : cs.primary,
                        ),
                      )
                    : SizedBox(
                        width: 72,
                        height: 28,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(t.radiusSm),
                          ),
                        ),
                      ),
              ),
              SizedBox(width: t.space4),
              Flexible(
                child: Text(
                  '/ $unitLabel',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: t.space4),
          Text(
            dailyCredits,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (amount != null) ...[
            SizedBox(height: t.space12),
            Text(
              l10n.subscriptionTierCatalogSelectedInterval(amount, unitLabel),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          SizedBox(height: t.space16),
          for (final feature in features) ...[
            _Bullet(text: feature, emphasize: !_isLite, tt: tt),
            SizedBox(height: t.space8),
          ],
          SizedBox(height: t.space16),
          EnjoyButton.primary(
            onPressed: ctaEnabled ? onChoose : null,
            child: Text(ctaLabelActual),
          ),
        ],
      ),
    );

    // Pro card gets the gradient treatment; Lite uses the standard card.
    if (!_isLite) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusLg + 2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.85),
              cs.tertiary.withValues(alpha: 0.75),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(padding: const EdgeInsets.all(1.5), child: inner),
      );
    }
    return inner;
  }

  List<String> _liteFeatures(AppLocalizations l10n) => [
    l10n.subscriptionFeatureLiteTranslation,
    l10n.subscriptionFeatureLiteSmartTranslation,
    l10n.subscriptionFeatureLiteDictionary,
    l10n.subscriptionFeatureLiteAsr,
    l10n.subscriptionFeatureLiteTts,
    l10n.subscriptionFeatureLiteAssessment,
  ];

  List<String> _proFeatures(AppLocalizations l10n) => [
    l10n.subscriptionFeatureProTranslation,
    l10n.subscriptionFeatureProSmartTranslation,
    l10n.subscriptionFeatureProDictionary,
    l10n.subscriptionFeatureProAsr,
    l10n.subscriptionFeatureProTts,
    l10n.subscriptionFeatureProAssessment,
  ];

  SubscriptionPlan? _resolvePlan(
    List<SubscriptionPlan> plans,
    CatalogInterval target,
    SubscriptionTier tier,
  ) {
    final tierName = tier == SubscriptionTier.lite ? 'lite' : 'pro';
    for (final plan in plans) {
      if (_intervalFromString(plan.interval) == target && plan.tier == tierName) {
        return plan;
      }
    }
    return null;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
    required this.tt,
    this.leading,
  });

  final String label;
  final Color color;
  final Color textColor;
  final TextTheme tt;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            Icon(leading, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.text,
    required this.emphasize,
    required this.tt,
  });

  final String text;
  final bool emphasize;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: emphasize ? cs.primary : cs.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: tt.bodyMedium)),
      ],
    );
  }
}

class _PlansError extends StatelessWidget {
  const _PlansError({required this.onRetry});

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
        children: [
          Text(
            l10n.subscriptionAutoRenewPlansUnavailable,
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

/// Public helper so callers (e.g. the unified purchase modal) can translate
/// the catalog's [CatalogInterval] into the wire-format string the backend
/// expects (`month` / `year`).
String catalogIntervalWire(CatalogInterval interval) =>
    _intervalToString(interval);

/// Translates a plan's `interval` string into a [CatalogInterval].
CatalogInterval catalogIntervalFromString(String? interval) =>
    _intervalFromString(interval ?? 'month');
