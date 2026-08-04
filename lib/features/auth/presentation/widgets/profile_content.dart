/// Shared, chrome-free body for the signed-in Enjoy profile.
///
/// Used exclusively by the Profile tab ([ProfileScreen]). Preferences are
/// now on a separate screen reached via the Preferences entry tile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/layout/enjoy_page_kind.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/application/profile_practice_stats_provider.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/profile_account_card.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/profile_hero_card.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/profile_sign_out_button.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/profile_stats.dart';
import 'package:enjoy_player/features/credits/application/todays_credits_provider.dart';
import 'package:enjoy_player/features/library/application/learning_statistics_provider.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_row.dart';
import 'package:enjoy_player/features/subscription/application/current_tier_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_status.dart';
import 'package:enjoy_player/features/update/application/update_controller.dart';
import 'package:enjoy_player/features/update/presentation/update_notification_dot.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_providers.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// The profile view body: hero card, practice stats, account nav card,
/// unlabeled learning/config sections, and sign-out button.
///
/// Used exclusively by the Profile tab ([ProfileScreen]). The content is a
/// scrollable, pull-to-refreshable list sized to the shell body.
class ProfileContent extends ConsumerStatefulWidget {
  const ProfileContent({super.key});

  @override
  ConsumerState<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<ProfileContent> {
  bool _signingOut = false;

  Future<void> _refresh() async {
    ref.invalidate(profilePracticeStatsProvider);
    ref.invalidate(learningStatisticsProvider);
    ref.invalidate(todaysCreditsUsedProvider);
    ref.invalidate(vocabularyStatsProvider);
    await ref.read(authCtrlProvider.notifier).refreshProfile();
  }

  Future<void> _confirmAndSignOut() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showEnjoyAlertDialog<bool>(
      context: context,
      useRootNavigator: true,
      title: Text(l10n.profileSignOutConfirmTitle),
      content: Text(l10n.profileSignOutConfirmMessage),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            l10n.authSignOut,
            style: TextStyle(color: Theme.of(ctx).colorScheme.error),
          ),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await ref.read(authCtrlProvider.notifier).signOut();
      if (!mounted) return;
      context.go('/sign-in');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final auth = ref.watch(authCtrlProvider);

    return auth.when(
      data: (state) {
        if (state is! AuthSignedIn) {
          return Center(child: Text(l10n.authSignInTitle));
        }
        final p = state.profile;

        final tier = ref.watch(currentTierProvider);
        final status = ref.watch(subscriptionStatusProvider).valueOrNull;
        // Prefer the live subscription status so the daily limit reflects the
        // actual tier (free=1,000 / lite=12,000 / pro=60,000). Fall back to a
        // tier-based default when the status hasn't loaded yet.
        final dailyLimit = status?.dailyCreditsLimit ?? _fallbackDailyLimit(tier);

        final creditsUsedAsync = ref.watch(todaysCreditsUsedProvider);
        final creditsUsed = creditsUsedAsync.valueOrNull;
        final dueCount = ref.watch(vocabularyStatsProvider).due;

        final children = <Widget>[
          ProfileHeroCard(profile: p),
          SizedBox(height: t.space16),
          ProfilePracticeSection(
            stats: ref.watch(profilePracticeStatsProvider),
          ),
          SizedBox(height: t.space8),
          ProfileAccountCard(
            creditsUsedToday: creditsUsed,
            dailyLimit: dailyLimit,
            onCreditsTap: () => context.push('/credits'),
            onSubscriptionTap: () => context.push('/subscription'),
          ),
          SizedBox(height: t.space16),
          _ProfileNavSection(
            rows: [
              SettingsRow(
                leadingIcon: Icons.menu_book_outlined,
                title: l10n.vocabularyProfileEntry,
                subtitle: l10n.vocabularyProfileEntryHint,
                valueBadge: dueCount > 0
                    ? Semantics(
                        container: true,
                        label: '${l10n.vocabularyDue}: $dueCount',
                        child: SettingsValuePill(
                          label: '$dueCount',
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      )
                    : null,
                onTap: () => context.push('/vocabulary'),
                responsive: false,
              ),
            ],
          ),
          SizedBox(height: t.space8),
          _ProfileNavSection(
            rows: [
              SettingsRow(
                leadingIcon: Icons.manage_accounts_outlined,
                title: l10n.profileEditEntry,
                subtitle: l10n.profileEditEntryHint,
                onTap: () => context.push('/profile/edit'),
                responsive: false,
              ),
              SettingsRow(
                leadingIcon: Icons.tune_rounded,
                title: l10n.profileSectionPreferences,
                subtitle: l10n.profileSectionPreferencesHint,
                onTap: () => context.push('/profile/preferences'),
                responsive: false,
              ),
              SettingsRow(
                leadingIcon: Icons.settings_outlined,
                title: l10n.settingsTitle,
                subtitle: l10n.settingsSubtitle,
                valueBadge: ref.watch(updateAvailableBadgeProvider)
                    ? UpdateNotificationDot(
                        semanticsLabel: l10n.updateAvailableBadgeSemantics,
                      )
                    : null,
                onTap: () => context.push('/settings'),
                responsive: false,
              ),
            ],
          ),
          SizedBox(height: t.space32),
          ProfileSignOutButton(
            saving: _signingOut,
            onPressed: _confirmAndSignOut,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final metrics = EnjoyPageMetrics.of(
              context,
              kind: EnjoyPageKind.hub,
              paneWidth: constraints.maxWidth,
            );
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: metrics.padding(top: t.space16, bottom: t.space32),
                children: children,
              ),
            );
          },
        );
      },
      loading: () => const SkeletonProfile(),
      error: (e, _) => Center(child: Text(l10n.errorGenericLoadFailed)),
    );
  }
}

/// Zero-padding [EnjoyCard] of [SettingsRow]s separated by [SettingsRowDivider].
class _ProfileNavSection extends StatelessWidget {
  const _ProfileNavSection({required this.rows});

  final List<SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(const SettingsRowDivider());
      children.add(rows[i]);
    }
    return EnjoyCard(
      padding: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Tier-based fallback for the daily credit limit when the live subscription
/// status has not loaded yet. Matches the entitlements in
/// [SubscriptionStatus.dailyCreditsLimit].
int _fallbackDailyLimit(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.pro:
      return 60000;
    case SubscriptionTier.lite:
      return 12000;
    case SubscriptionTier.free:
      return 1000;
  }
}
