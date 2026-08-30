/// Rails credits packages catalog + checkout.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/data/api/rest_repository.dart';
import 'package:enjoy_player/data/api/services/api_providers.dart';
import 'package:enjoy_player/data/api/services/credits_packages_api.dart';
import 'package:enjoy_player/features/credits/domain/credits_package.dart';

part 'credits_packages_repository.g.dart';

@Riverpod(keepAlive: true)
CreditsPackagesRepository creditsPackagesRepository(Ref ref) {
  return CreditsPackagesRepository(ref.watch(creditsPackagesApiProvider));
}

class CreditsPackagesRepository with RestRepository {
  CreditsPackagesRepository(this._api);

  final CreditsPackagesApi _api;

  Future<List<CreditsPackage>> listPackages() => apiCall(
    () async => parseJsonListField(
      await _api.listPackages(),
      'packages',
      CreditsPackage.fromJson,
    ),
  );

  Future<CreditsPackagePurchaseSession> startPurchase({
    required String packageId,
  }) => apiCall(
    () async => CreditsPackagePurchaseSession.fromJson(
      await _api.startPackagePurchase(packageId: packageId),
    ),
  );

  @override
  AppFailure mapApiException(ApiException e) {
    if (e.statusCode == 402) return CreditsFailure.fromApiException(e);
    return NetworkFailure(e.message, statusCode: e.statusCode);
  }
}
