/// Hosts global subscription tier reconciliation: refreshes the tier on app
/// resume + cold start and celebrates free → Pro transitions.
///
/// Mounted inside the authenticated shell ([RootShell]) so it is alive for
/// every authenticated screen. Renders its [child] unchanged — this widget
/// only adds side effects. See ADR-0041.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/subscription/application/current_tier_provider.dart';
import 'package:enjoy_player/features/subscription/application/tier_reconcile_provider.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class TierReconcileHost extends ConsumerStatefulWidget {
  const TierReconcileHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TierReconcileHost> createState() => _TierReconcileHostState();
}

class _TierReconcileHostState extends ConsumerState<TierReconcileHost>
    with WidgetsBindingObserver {
  /// Last tier emitted by [currentTierProvider] while signed in, or `null`
  /// before a baseline is captured on sign-in. Used to detect genuine
  /// free → Pro transitions (and avoid re-celebrating while staying Pro).
  SubscriptionTier? _lastEmittedTier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFirstFrame());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResume());
    }
  }

  void _onFirstFrame() {
    if (!mounted) return;
    final auth = ref.read(authCtrlProvider).valueOrNull;
    if (auth is! AuthSignedIn) return;
    _lastEmittedTier ??= auth.profile.subscriptionTier ?? SubscriptionTier.free;
    unawaited(ref.read(tierReconcileCtrlProvider.notifier).reconcile());
    final liveTier = ref.read(currentTierProvider);
    if (liveTier != SubscriptionTier.free &&
        _lastEmittedTier == SubscriptionTier.free) {
      _lastEmittedTier = liveTier;
      _celebrate(liveTier);
    }
  }

  Future<void> _onResume() async {
    final notifier = ref.read(tierReconcileCtrlProvider.notifier);
    if (notifier.hasPendingPurchase) {
      await _eagerReconcile();
    } else {
      await notifier.reconcile();
    }
  }

  Future<void> _eagerReconcile() async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(tierReconcileCtrlProvider.notifier);
    final packagePending = notifier.hasPendingPackagePurchase;
    AppNotice.info(
      context,
      packagePending
          ? l10n.creditsPackageVerifying
          : l10n.subscriptionVerifyingUpgrade,
    );
    final confirmed = await notifier.reconcile(eager: true);
    if (!mounted) return;
    // `null` means reconcile was skipped (already running / already handled) —
    // do not surface a false verify-timeout notice.
    if (confirmed == null) return;
    if (packagePending) {
      if (confirmed) {
        AppNotice.success(context, l10n.creditsPackagePurchaseSuccess);
      } else {
        AppNotice.info(context, l10n.creditsPackageVerifyTimeout);
      }
      return;
    }
    if (!confirmed && ref.read(currentTierProvider) == SubscriptionTier.free) {
      AppNotice.info(context, l10n.subscriptionVerifyTimeout);
    }
  }

  void _celebrate(SubscriptionTier tier) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final message = switch (tier) {
      SubscriptionTier.lite => l10n.subscriptionUpgradedToLite,
      SubscriptionTier.pro => l10n.subscriptionUpgradedToPro,
      SubscriptionTier.free => l10n.subscriptionUpgradedToPro,
    };
    AppNotice.success(context, message);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authCtrlProvider, (prev, next) {
      final prevAuth = prev?.valueOrNull;
      final nextAuth = next.valueOrNull;
      if (nextAuth is AuthSignedIn && prevAuth is! AuthSignedIn) {
        _lastEmittedTier =
            nextAuth.profile.subscriptionTier ?? SubscriptionTier.free;
        unawaited(ref.read(tierReconcileCtrlProvider.notifier).reconcile());
      } else if (nextAuth is! AuthSignedIn) {
        _lastEmittedTier = null;
      }
    });

    ref.listen<SubscriptionTier>(currentTierProvider, (prev, next) {
      if (_lastEmittedTier == null) return;
      if (next != SubscriptionTier.free &&
          _lastEmittedTier == SubscriptionTier.free) {
        _celebrate(next);
      }
      _lastEmittedTier = next;
    });

    return widget.child;
  }
}
