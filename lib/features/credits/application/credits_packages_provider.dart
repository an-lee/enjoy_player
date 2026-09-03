/// Credits packages catalog + purchase checkout.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/utils/launch_pay_url.dart';
import 'package:enjoy_player/features/credits/application/credits_summary_provider.dart';
import 'package:enjoy_player/features/credits/data/credits_packages_repository.dart';
import 'package:enjoy_player/features/credits/domain/credits_package.dart';
import 'package:enjoy_player/features/subscription/application/tier_reconcile_provider.dart';

part 'credits_packages_provider.g.dart';

@Riverpod(keepAlive: false)
Future<List<CreditsPackage>> creditsPackages(Ref ref) {
  return ref.watch(creditsPackagesRepositoryProvider).listPackages();
}

@Riverpod(keepAlive: true)
class CreditsPackagePurchaseCtrl extends _$CreditsPackagePurchaseCtrl {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<CreditsPackagePurchaseSession?> purchaseExternal({
    required String packageId,
    required int expectedCredits,
  }) async {
    state = const AsyncLoading();
    try {
      // Prefer a cached summary (screen already loaded it) so a flaky refresh
      // cannot leave baseline null and poison post-checkout verification.
      var baseline = ref
          .read(creditsSummaryProvider)
          .asData
          ?.value
          .permanentAvailable;
      if (baseline == null) {
        for (var attempt = 0; attempt < 3 && baseline == null; attempt++) {
          try {
            if (attempt > 0) {
              ref.invalidate(creditsSummaryProvider);
              await Future<void>.delayed(Duration(milliseconds: 150 * attempt));
            }
            baseline = (await ref.read(
              creditsSummaryProvider.future,
            )).permanentAvailable;
          } catch (_) {
            // Retry — checkout may still proceed without a baseline, but
            // verification then relies on consecutive-sample growth only.
          }
        }
      }

      final repo = ref.read(creditsPackagesRepositoryProvider);
      final session = await repo.startPurchase(packageId: packageId);
      state = const AsyncData(null);

      await launchPayUrl(session.payUrl);
      ref
          .read(tierReconcileCtrlProvider.notifier)
          .markPackagePurchasePending(
            packageId: packageId,
            expectedCredits: expectedCredits,
            baselinePermanent: baseline,
          );
      return session;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
