/// Riverpod wiring for Enjoy worker AI HTTP clients.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/api/api_client_provider.dart';
import 'package:enjoy_player/data/api/secure_token_store.dart';
import 'package:enjoy_player/data/api/services/ai/asr_api.dart';
import 'package:enjoy_player/data/api/services/ai/asr_media_upload_api.dart';
import 'package:enjoy_player/data/api/services/ai/azure_token_api.dart';
import 'package:enjoy_player/data/api/services/ai/azure_token_cache.dart';
import 'package:enjoy_player/data/api/services/ai/chat_api.dart';
import 'package:enjoy_player/data/api/services/ai/credits_api.dart';
import 'package:enjoy_player/data/api/services/ai/dictionary_api.dart';
import 'package:enjoy_player/data/api/services/ai/pronounce_api.dart';
import 'package:enjoy_player/data/api/services/ai/translation_api.dart';
import 'package:enjoy_player/data/api/services/ai/youtube_feed_api.dart';
import 'package:enjoy_player/data/api/services/ai/youtube_transcripts_api.dart';

part 'ai_api_providers.g.dart';

@Riverpod(keepAlive: true)
AsrApi asrApi(Ref ref) => AsrApi(ref.watch(aiApiClientProvider));

@Riverpod(keepAlive: true)
AsrMediaUploadApi asrMediaUploadApi(Ref ref) =>
    AsrMediaUploadApi(ref.watch(aiApiClientProvider));

@Riverpod(keepAlive: true)
ChatApi chatApi(Ref ref) => ChatApi(ref.watch(aiApiClientProvider));

@Riverpod(keepAlive: true)
TranslationApi translationApi(Ref ref) =>
    TranslationApi(ref.watch(aiApiClientProvider));

@Riverpod(keepAlive: true)
DictionaryApi dictionaryApi(Ref ref) =>
    DictionaryApi(ref.watch(aiApiClientProvider));

@Riverpod(keepAlive: true)
PronounceApi pronounceApi(Ref ref) =>
    PronounceApi(ref.watch(aiApiClientProvider));

@Riverpod(keepAlive: true)
CreditsApi creditsApi(Ref ref) => CreditsApi(ref.watch(aiApiClientProvider));

@Riverpod(keepAlive: true)
AzureTokenApi azureTokenApi(Ref ref) =>
    AzureTokenApi(ref.watch(aiApiClientProvider));

@Riverpod(keepAlive: true)
AzureTokenCache azureTokenCache(Ref ref) =>
    AzureTokenCache(api: ref.watch(azureTokenApiProvider));

@Riverpod(keepAlive: true)
YoutubeTranscriptsClient youtubeTranscriptsClient(Ref ref) =>
    YoutubeTranscriptsApi(ref.watch(aiApiClientProvider));

@Riverpod(keepAlive: true)
YoutubeFeedClient youtubeFeedClient(Ref ref) {
  final tokens = ref.watch(secureTokenStoreProvider);
  return YoutubeFeedClient(getToken: tokens.readAccessToken);
}
