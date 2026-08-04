/// Reconciles the subscription tier with the server on app resume and cold
/// start, and owns the app-initiated purchase "pending" flag for eager polling.
library;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/credits/application/credits_summary_provider.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';

part 'tier_reconcile_provider.g.dart';

final Logger _log = logNamed('subscription.reconcile');

/// Minimum gap between non-eager reconciles to avoid hammering the API on
/// rapid background/foreground toggles (e.g. battery saver).
const _reconcileDebounce = Duration(seconds: 30);

/// Eager-poll cadence and budget after an app-initiated purchase.
const _eagerPollInterval = Duration(seconds: 3);
const _eagerPollTimeout = Duration(seconds: 30);

enum PendingPurchaseKind { subscription, creditsPackage }

/// Orchestrates tier reconciliation between the app and the Enjoy API.
///
/// Reconciliation refreshes *both* sources of truth consumed by
/// [currentTierProvider]: the cached profile ([authCtrlProvider], via
/// [AuthCtrl.refreshProfile]) and the live status
/// ([subscriptionStatusProvider]). This guarantees a tier change made on the
/// web (with or without an app-initiated checkout) surfaces in the app on the
/// next resume or cold start — see ADR-0041.
@Riverpod(keepAlive: true)
class TierReconcileCtrl extends _$TierReconcileCtrl {
  DateTime? _lastReconciledAt;
  bool _reconciling = false;
  PendingPurchaseKind? _pendingKind;
  int? _packageBaselinePermanent;
  int? _packageExpectedCredits;

  /// Last permanent balance observed while polling without a pre-checkout
  /// baseline. Used only for consecutive-sample growth detection — never
  /// promoted into [_packageBaselinePermanent] (that would lock in a
  /// post-grant balance and make verification impossible).
  int? _packageLastSamplePermanent;

  @override
  void build() {}

  /// Whether an app-initiated purchase is awaiting confirmation.
  bool get hasPendingPurchase => _pendingKind != null;

  bool get hasPendingSubscriptionPurchase =>
      _pendingKind == PendingPurchaseKind.subscription;

  bool get hasPendingPackagePurchase =>
      _pendingKind == PendingPurchaseKind.creditsPackage;

  /// Mark that the user just launched external Pro checkout from the app.
  void markPurchasePending() {
    _pendingKind = PendingPurchaseKind.subscription;
    _clearPackagePendingState();
  }

  /// Mark that the user just launched a credits-package checkout.
  ///
  /// [baselinePermanent] should be the wallet permanent balance *before*
  /// checkout so resume polling can detect the grant.
  void markPackagePurchasePending({
    required int expectedCredits,
    int? baselinePermanent,
  }) {
    _pendingKind = PendingPurchaseKind.creditsPackage;
    _packageExpectedCredits = expectedCredits;
    _packageBaselinePermanent = baselinePermanent;
    _packageLastSamplePermanent = null;
  }

  /// Refresh the tier from the server.
  ///
  /// When [eager] (app-initiated purchase just returned), poll until confirmed
  /// or [_eagerPollTimeout] elapses, then clears the pending flag. Otherwise a
  /// single fan-out refresh, debounced by [_reconcileDebounce].
  ///
  /// Returns:
  /// - `true` — non-eager refresh completed, or eager poll confirmed
  /// - `false` — eager poll timed out without confirmation
  /// - `null` — skipped (signed out, debounced, or another reconcile handled it)
  Future<bool?> reconcile({bool eager = false}) async {
    final auth = ref.read(authCtrlProvider).valueOrNull;
    if (auth is! AuthSignedIn) return null;

    if (_reconciling) {
      if (!eager) {
        _log.fine('reconcile already in progress; skipping');
        return null;
      }
      // Eager resume must not report a false timeout while a non-eager
      // refresh (or a peer eager poll) holds the lock.
      final waitDeadline = DateTime.now().add(
        _eagerPollTimeout + const Duration(seconds: 5),
      );
      while (_reconciling && DateTime.now().isBefore(waitDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (_reconciling || _pendingKind == null) {
        _log.fine('eager reconcile skipped after wait (busy or already done)');
        return null;
      }
    }
    if (!eager) {
      final last = _lastReconciledAt;
      if (last != null &&
          DateTime.now().difference(last) < _reconcileDebounce) {
        _log.fine('reconcile debounced; skipping');
        return null;
      }
    }

    _reconciling = true;
    try {
      var confirmed = false;
      if (eager) {
        final kind = _pendingKind;
        if (kind == PendingPurchaseKind.creditsPackage) {
          confirmed = await _pollUntilPackageOrTimeout();
        } else {
          confirmed = await _pollUntilPaidOrTimeout();
        }
        _pendingKind = null;
        _clearPackagePendingState();
      } else {
        await _refreshOnce();
        confirmed = true;
      }
      _lastReconciledAt = DateTime.now();
      return confirmed;
    } finally {
      _reconciling = false;
    }
  }

  void _clearPackagePendingState() {
    _packageBaselinePermanent = null;
    _packageExpectedCredits = null;
    _packageLastSamplePermanent = null;
  }

  Future<void> _refreshOnce() async {
    ref.invalidate(subscriptionStatusProvider);
    ref.invalidate(creditsSummaryProvider);
    await Future.wait([
      _safeStatusFetch(),
      _safeProfileRefresh(),
      _safeCreditsSummaryFetch(),
    ]);
  }

  Future<void> _safeStatusFetch() async {
    try {
      await ref.read(subscriptionStatusProvider.future);
    } catch (e, st) {
      _log.warning('reconcile: status fetch failed', e, st);
    }
  }

  Future<void> _safeProfileRefresh() async {
    try {
      await ref.read(authCtrlProvider.notifier).refreshProfile();
    } catch (e, st) {
      _log.warning('reconcile: profile refresh failed', e, st);
    }
  }

  Future<void> _safeCreditsSummaryFetch() async {
    try {
      await ref.read(creditsSummaryProvider.future);
    } catch (e, st) {
      _log.warning('reconcile: credits summary fetch failed', e, st);
    }
  }

  Future<bool> _pollUntilPaidOrTimeout() async {
    final deadline = DateTime.now().add(_eagerPollTimeout);
    while (DateTime.now().isBefore(deadline)) {
      ref.invalidate(subscriptionStatusProvider);
      final confirmed = await _pollPaidOnce();
      if (confirmed) return true;
      await Future<void>.delayed(_eagerPollInterval);
    }
    _log.info(
      'eager reconcile timed out before paid tier confirmed; '
      'background reconcile will retry',
    );
    return false;
  }

  Future<bool> _pollPaidOnce() async {
    try {
      final status = await ref.read(subscriptionStatusProvider.future);
      if (status.isPaidTier) {
        await _safeProfileRefresh();
        return true;
      }
    } catch (e, st) {
      _log.warning('eager reconcile: status fetch failed', e, st);
    }
    return false;
  }

  Future<bool> _pollUntilPackageOrTimeout() async {
    final deadline = DateTime.now().add(_eagerPollTimeout);
    while (DateTime.now().isBefore(deadline)) {
      ref.invalidate(creditsSummaryProvider);
      final confirmed = await _pollPackageOnce();
      if (confirmed) return true;
      await Future<void>.delayed(_eagerPollInterval);
    }
    _log.info(
      'eager package reconcile timed out; background refresh will retry',
    );
    return false;
  }

  Future<bool> _pollPackageOnce() async {
    try {
      final summary = await ref.read(creditsSummaryProvider.future);
      final current = summary.permanentAvailable;
      final expected = _packageExpectedCredits ?? 0;
      final baseline = _packageBaselinePermanent;

      if (baseline != null) {
        final delta = current - baseline;
        return delta >= expected && delta > 0;
      }

      // No pre-checkout snapshot: confirm only when permanent balance grows
      // across successive polls. Do not adopt the first sample as baseline —
      // if the grant already landed, that would freeze a post-purchase value
      // and every later poll would see a zero delta.
      final previous = _packageLastSamplePermanent;
      _packageLastSamplePermanent = current;
      if (previous == null) return false;
      final delta = current - previous;
      return delta >= expected && delta > 0;
    } catch (e, st) {
      _log.warning('eager package reconcile: summary fetch failed', e, st);
    }
    return false;
  }
}
