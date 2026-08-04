/// Sidebar account entry: sign-in or profile shortcut.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/presentation/loading_icon.dart';
import 'package:enjoy_player/core/utils/avatar_url.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/subscription/application/current_tier_provider.dart';
import 'package:enjoy_player/features/update/application/update_controller.dart';
import 'package:enjoy_player/features/update/presentation/update_notification_dot.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class SidebarAccountChip extends ConsumerWidget {
  const SidebarAccountChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = EnjoyThemeTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authCtrlProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(t.space8, 0, t.space8, t.space8),
      child: auth.when(
        data: (state) {
          if (authFlowInProgress(state)) {
            return ListTile(
              dense: true,
              leading: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
              title: Text(
                state is AuthAwaitingOtp
                    ? l10n.authOtpTitle
                    : l10n.authWebSignInWaiting,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              onTap: () => context.push(
                state is AuthAwaitingOtp ? '/sign-in/email' : '/sign-in',
              ),
            );
          }
          if (state is AuthSignedIn) {
            final p = state.profile;
            final avatarUrl = rasterAvatarUrl(p.avatarUrl);
            final tier = ref.watch(currentTierProvider);
            final isPaid = tier != SubscriptionTier.free;
            final isFree = !isPaid;
            final updateBadge = ref.watch(updateAvailableBadgeProvider);
            final tierBadgeLabel = switch (tier) {
              SubscriptionTier.pro => l10n.profileSubscriptionPro,
              SubscriptionTier.lite => l10n.subscriptionTierLiteName,
              SubscriptionTier.free => null,
            };
            return ListTile(
              dense: true,
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: cs.primary,
                          )
                        : null,
                  ),
                  if (updateBadge)
                    const Positioned(
                      right: -2,
                      top: -2,
                      child: UpdateNotificationDot(size: 9),
                    ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (tierBadgeLabel != null) ...[
                    SizedBox(width: t.space4),
                    _SidebarTierBadge(
                      label: tierBadgeLabel,
                      background: cs.primaryContainer,
                      foreground: cs.onPrimaryContainer,
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                l10n.settingsAccountOpenProfile,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: cs.primary),
              ),
              trailing: isFree
                  ? _SidebarUpgradeButton(
                      label: l10n.subscriptionUpgradeShort,
                      onPressed: () => context.push('/subscription'),
                    )
                  : null,
              onTap: () => context.go('/profile'),
            );
          }
          return ListTile(
            dense: true,
            leading: Icon(Icons.login_rounded, color: cs.primary, size: 22),
            title: Text(
              l10n.settingsAccountSignIn,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            onTap: () => context.push('/sign-in'),
          );
        },
        loading: () => const SizedBox(
          height: 40,
          child: Center(child: LoadingIcon(size: 20)),
        ),
        error: (Object e, StackTrace s) => const SizedBox.shrink(),
      ),
    );
  }
}

class _SidebarTierBadge extends StatelessWidget {
  const _SidebarTierBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SidebarUpgradeButton extends StatelessWidget {
  const _SidebarUpgradeButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.primary,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
