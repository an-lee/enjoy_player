/// Riverpod wiring for the public-API REST clients in this directory.
///
/// All clients extend [RestApi] and take a single [ApiClient] argument,
/// so each provider is a one-line `=>` that delegates to the shared
/// `apiClientProvider`. The AI sub-folder has its own consolidated
/// `ai_api_providers.dart` so this file only lists the public API.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/api/api_client_provider.dart';
import 'package:enjoy_player/data/api/services/credits_packages_api.dart';
import 'package:enjoy_player/data/api/services/direct_uploads_api.dart';
import 'package:enjoy_player/data/api/services/stats_api.dart';
import 'package:enjoy_player/data/api/services/subscription_api.dart';
import 'package:enjoy_player/data/api/services/transcript_api.dart';
import 'package:enjoy_player/data/api/services/user_api.dart';

part 'api_providers.g.dart';

@Riverpod(keepAlive: true)
StatsApi statsApi(Ref ref) => StatsApi(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
UserApi userApi(Ref ref) => UserApi(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
TranscriptApi transcriptApi(Ref ref) =>
    TranscriptApi(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
SubscriptionApi subscriptionApi(Ref ref) =>
    SubscriptionApi(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
CreditsPackagesApi creditsPackagesApi(Ref ref) =>
    CreditsPackagesApi(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
DirectUploadsApi directUploadsApi(Ref ref) =>
    DirectUploadsApi(ref.watch(apiClientProvider));
