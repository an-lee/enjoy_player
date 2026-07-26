// Tests for `lib/features/credits/data/credits_packages_repository.dart` —
// exercises the `parseJsonListField` + `apiCall` happy path and the
// `CreditsFailure` / `NetworkFailure` mapping inside the `RestRepository`
// mixin using a fake `CreditsPackagesApi` so no real network is touched.
import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/data/api/services/credits_packages_api.dart';
import 'package:enjoy_player/features/credits/data/credits_packages_repository.dart';
import 'package:enjoy_player/features/credits/domain/credits_package.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _NullHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnsupportedError('unused');
  }
}

class _NullApiClient extends ApiClient {
  _NullApiClient()
    : super(
        httpClient: _NullHttpClient(),
        getBaseUrl: () async => 'https://test.invalid',
        getAccessToken: () async => null,
      );
}

class _FakeCreditsPackagesApi extends CreditsPackagesApi {
  _FakeCreditsPackagesApi({
    this.packagesResponse,
    this.purchaseResponse,
    Object? packagesError,
    Object? purchaseError,
  }) : _packagesError = packagesError,
       _purchaseError = purchaseError,
       super(_NullApiClient());

  final Object? _packagesError;
  final Object? _purchaseError;
  Map<String, dynamic>? packagesResponse;
  Map<String, dynamic>? purchaseResponse;
  int listPackagesCalls = 0;
  int startPurchaseCalls = 0;
  String? lastPackageId;

  @override
  Future<Map<String, dynamic>> listPackages() async {
    listPackagesCalls++;
    if (_packagesError != null) throw _packagesError!;
    return packagesResponse ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> startPackagePurchase({
    required String packageId,
  }) async {
    startPurchaseCalls++;
    lastPackageId = packageId;
    if (_purchaseError != null) throw _purchaseError!;
    return purchaseResponse ?? <String, dynamic>{};
  }
}

void main() {
  group('CreditsPackagesRepository.listPackages', () {
    test('parses the packages array using CreditsPackage.fromJson', () async {
      final api = _FakeCreditsPackagesApi(
        packagesResponse: {
          'packages': [
            {
              'id': 'pkg-1',
              'amount': '9.99',
              'currency': 'USD',
              'credits': 100000,
              'rate': {'usd': 9.99, 'credits': 100000},
            },
            {
              'id': 'pkg-2',
              'amount': '19.99',
              'currency': 'USD',
              'credits': 250000,
              'rate': {'usd': 19.99, 'credits': 250000},
            },
            'not-a-map', // entries that aren't JSON objects are skipped.
          ],
        },
      );
      final repo = CreditsPackagesRepository(api);

      final packages = await repo.listPackages();

      expect(api.listPackagesCalls, 1);
      expect(packages, hasLength(2));
      expect(packages[0].id, 'pkg-1');
      expect(packages[0].rate.usd, 9.99);
      expect(packages[1].credits, 250000);
    });

    test('returns an empty list when packages field is missing', () async {
      final api = _FakeCreditsPackagesApi(
        packagesResponse: const <String, dynamic>{},
      );
      final repo = CreditsPackagesRepository(api);

      expect(await repo.listPackages(), isEmpty);
    });

    test('returns an empty list when packages field is not a list', () async {
      final api = _FakeCreditsPackagesApi(
        packagesResponse: <String, dynamic>{'packages': 'oops'},
      );
      final repo = CreditsPackagesRepository(api);

      expect(await repo.listPackages(), isEmpty);
    });

    test('maps ApiException(402) to CreditsFailure', () async {
      final api = _FakeCreditsPackagesApi(
        packagesError: const ApiException(
          message: 'out of credits',
          statusCode: 402,
        ),
      );
      final repo = CreditsPackagesRepository(api);

      await expectLater(
        repo.listPackages(),
        throwsA(
          isA<CreditsFailure>().having(
            (e) => e.message,
            'message',
            'out of credits',
          ),
        ),
      );
    });

    test(
      'maps non-402 ApiException to NetworkFailure with statusCode',
      () async {
        final api = _FakeCreditsPackagesApi(
          packagesError: const ApiException(
            message: 'server broke',
            statusCode: 500,
          ),
        );
        final repo = CreditsPackagesRepository(api);

        await expectLater(
          repo.listPackages(),
          throwsA(
            isA<NetworkFailure>().having(
              (e) => e.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
      },
    );

    test('maps FormatException to NetworkFailure', () async {
      final api = _FakeCreditsPackagesApi(
        packagesError: const FormatException('bad json'),
      );
      final repo = CreditsPackagesRepository(api);

      await expectLater(repo.listPackages(), throwsA(isA<NetworkFailure>()));
    });
  });

  group('CreditsPackagesRepository.startPurchase', () {
    test('parses the purchase session payload', () async {
      final api = _FakeCreditsPackagesApi(
        purchaseResponse: {
          'id': 'psess-1',
          'status': 'pending',
          'paymentType': 'stripe',
          'amount': '9.99',
          'payUrl': 'https://pay.example.com/checkout',
          'package': {
            'id': 'pkg-1',
            'amount': '9.99',
            'currency': 'USD',
            'credits': 100000,
          },
        },
      );
      final repo = CreditsPackagesRepository(api);

      final session = await repo.startPurchase(packageId: 'pkg-1');

      expect(api.startPurchaseCalls, 1);
      expect(api.lastPackageId, 'pkg-1');
      expect(session.id, 'psess-1');
      expect(session.payUrl, 'https://pay.example.com/checkout');
      expect(session.package.id, 'pkg-1');
      expect(session.package.credits, 100000);
      // Default rate injected when package map omitted one.
      expect(session.package.rate.usd, 1);
      expect(session.package.rate.credits, 100000);
    });

    test('maps ApiException to CreditsFailure for purchase', () async {
      final api = _FakeCreditsPackagesApi(
        purchaseError: const ApiException(
          message: 'payment required',
          statusCode: 402,
        ),
      );
      final repo = CreditsPackagesRepository(api);

      await expectLater(
        repo.startPurchase(packageId: 'pkg-1'),
        throwsA(isA<CreditsFailure>()),
      );
    });

    test('maps ApiException to NetworkFailure for purchase', () async {
      final api = _FakeCreditsPackagesApi(
        purchaseError: const ApiException(
          message: 'service error',
          statusCode: 503,
        ),
      );
      final repo = CreditsPackagesRepository(api);

      await expectLater(
        repo.startPurchase(packageId: 'pkg-99'),
        throwsA(
          isA<NetworkFailure>().having((e) => e.statusCode, 'statusCode', 503),
        ),
      );
      expect(api.lastPackageId, 'pkg-99');
    });
  });
}
