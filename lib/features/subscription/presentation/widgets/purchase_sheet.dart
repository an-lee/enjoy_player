/// Desktop purchase sheet: external checkout only.
///
/// **Deprecated:** prefer [showUnifiedPurchaseSheet] which is tier-aware and
/// driven by the catalog endpoint. This entry point remains available for
/// legacy callers and is hardcoded to Pro when the monthly plan is available.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/platform/subscription_purchase_capability.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/subscription/application/subscription_plans_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_purchase_provider.dart';
import 'package:enjoy_player/features/subscription/domain/payment_processor.dart';
import 'package:enjoy_player/features/subscription/domain/purchase_request.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_plan.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/payment_processor_option.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/subscription_duration_selector.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Future<void> showSubscriptionPurchaseSheet(BuildContext context) {
  if (!supportsExternalSubscriptionPurchase()) return Future.value();
  return showEnjoySheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _PurchaseSheetBody(),
  );
}

/// Opens the one-time prepaid months sheet (secondary to auto-renew).
Future<void> showPrepaidPurchaseSheet(BuildContext context) =>
    showSubscriptionPurchaseSheet(context);

class _PurchaseSheetBody extends ConsumerStatefulWidget {
  const _PurchaseSheetBody();

  @override
  ConsumerState<_PurchaseSheetBody> createState() => _PurchaseSheetBodyState();
}

class _PurchaseSheetBodyState extends ConsumerState<_PurchaseSheetBody> {
  int _months = 1;
  PaymentProcessor _processor = PaymentProcessor.stripe;

  double? _totalPrice(List<SubscriptionPlan> plans) {
    final unit = prepaidUnitPriceForTier(plans, SubscriptionTier.pro.name);
    return unit == null ? null : _months * unit;
  }

  Future<void> _purchaseExternal() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(subscriptionPurchaseCtrlProvider.notifier)
          .purchaseExternal(
            months: _months,
            processor: _processor,
            tier: SubscriptionTier.pro.name,
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final purchaseState = ref.watch(subscriptionPurchaseCtrlProvider);
    final busy = purchaseState.isLoading;
    final plans = ref.watch(subscriptionPlansProvider).valueOrNull ?? const [];
    final totalPrice = _totalPrice(plans);

    return Padding(
      padding: EdgeInsets.only(
        left: t.space20,
        right: t.space20,
        top: t.space12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + t.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          SizedBox(height: t.space16),
          Text(
            l10n.subscriptionPayOnceTitle,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: t.space4),
          Text(
            l10n.subscriptionPayOnceSubtitle,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: t.space8),
          Text(
            l10n.subscriptionPurchaseSelectDuration,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: t.space16),
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              SubscriptionDurationSelector(
                months: _months,
                enabled: !busy,
                onMonthsChanged: (v) => setState(() => _months = v),
              ),
              SizedBox(height: t.space16),
              Text(
                l10n.subscriptionPurchasePaymentMethod,
                style: tt.titleSmall,
              ),
              SizedBox(height: t.space8),
              PaymentProcessorOption(
                processor: PaymentProcessor.stripe,
                selected: _processor == PaymentProcessor.stripe,
                enabled: !busy,
                onSelected: () =>
                    setState(() => _processor = PaymentProcessor.stripe),
              ),
              SizedBox(height: t.space8),
              PaymentProcessorOption(
                processor: PaymentProcessor.mixin,
                selected: _processor == PaymentProcessor.mixin,
                enabled: !busy,
                onSelected: () =>
                    setState(() => _processor = PaymentProcessor.mixin),
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
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: t.space16),
              EnjoyButton.primary(
                onPressed: busy ? null : _purchaseExternal,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.subscriptionContinueToPayment),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
