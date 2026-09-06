/// Subscription management: membership, plans, credits, and balance → credits.
///
/// Composed of three sections below the status card:
///   - [TierCatalog] — unified Free / Pro tier cards with Monthly / Yearly
///     toggle. The Pro card CTA opens [showUnifiedPurchaseSheet] with the
///     selected interval.
///   - [BalanceToCredits] — discoverable card for users with legacy USD
///     balance to convert into permanent credits (replaces the retired
///     "Use balance" path that used to live inside the prepaid flow).
///   - [CreditsPackagesSection] — one-time permanent credits top-ups.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/layout/enjoy_page_kind.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_page.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/auth_required_callout.dart';
import 'package:enjoy_player/features/credits/application/credits_packages_provider.dart';
import 'package:enjoy_player/features/credits/application/credits_summary_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/auto_renew_plan_sheet.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/balance_to_credits.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/credits_packages_section.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/mobile_purchase_unavailable.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/subscription_status_card.dart';
import 'package:enjoy_player/features/subscription/presentation/widgets/tier_catalog.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  Future<void> _refresh() async {
    ref.invalidate(subscriptionStatusProvider);
    ref.invalidate(creditsPackagesProvider);
    ref.invalidate(creditsSummaryProvider);
    await ref.read(subscriptionStatusProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authCtrlProvider);

    return EnjoyPage(
      kind: EnjoyPageKind.hub,
      title: l10n.subscriptionTitle,
      showBack: true,
      body: (context, metrics) => auth.when(
        data: (state) {
          if (state is! AuthSignedIn) {
            return const Center(
              child: AuthRequiredCallout(
                surface: AuthRequiredSurface.subscription,
                compact: false,
              ),
            );
          }
          return _SubscriptionBody(onRefresh: _refresh, metrics: metrics);
        },
        loading: () => const SkeletonSettingsList(rowCount: 6),
        error: (e, _) => Center(child: Text(l10n.errorGenericLoadFailed)),
      ),
    );
  }
}

class _SubscriptionBody extends ConsumerWidget {
  const _SubscriptionBody({required this.onRefresh, required this.metrics});

  final Future<void> Function() onRefresh;
  final EnjoyPageMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final statusAsync = ref.watch(subscriptionStatusProvider);
    final pad = metrics.padding(top: t.space16, bottom: t.space32);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: statusAsync.when(
        data: (status) {
          return ListView(
            padding: pad,
            children: [
              SubscriptionStatusCard(status: status),
              SizedBox(height: t.space24),
              TierCatalog(
                status: status,
                onChoosePaid: (tier, interval) =>
                    _openUnifiedPurchase(context, tier, interval),
              ),
              SizedBox(height: t.space20),
              const BalanceToCredits(),
              SizedBox(height: t.space32),
              const CreditsPackagesSection(),
            ],
          );
        },
        loading: () => ListView(
          padding: pad,
          children: [
            Skeleton.line(width: double.infinity, height: 120),
            SizedBox(height: t.space16),
            Skeleton.line(width: double.infinity, height: 160),
            SizedBox(height: t.space16),
            Skeleton.line(width: double.infinity, height: 280),
          ],
        ),
        error: (e, _) => ListView(
          padding: pad,
          children: [
            Text(l10n.subscriptionErrorLoading),
            SizedBox(height: t.space8),
            Text(l10n.errorGenericLoadFailed),
            SizedBox(height: t.space16),
            EnjoyButton.primary(
              onPressed: () => ref.invalidate(subscriptionStatusProvider),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the unified purchase modal at the chosen catalog tier + interval.
///
/// Surfaces platform-specific affordances (mobile in-app unavailable notice)
/// before delegating to [showUnifiedPurchaseSheet], which itself defaults to
/// the auto-renew path and offers pay-once as a secondary option.
Future<void> _openUnifiedPurchase(
  BuildContext context,
  SubscriptionTier tier,
  CatalogInterval interval,
) async {
  if (await guardMobilePurchase(context)) return;
  if (!context.mounted) return;
  await showUnifiedPurchaseSheet(context, tier: tier, interval: interval);
}
