/// `/api/v1/transcripts` (ported from `@enjoy/api` transcript service).
library;

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/query_params.dart';
import 'package:enjoy_player/data/api/rest_api.dart';

class TranscriptApi extends RestApi {
  TranscriptApi(super.client);

  static const _path = '/api/v1/transcripts';

  Future<List<JsonMap>> transcripts({
    String? targetId,
    String? targetType,
    String? source,
    String? language,
  }) {
    return client.getJsonList(
      _path,
      queryParameters: buildQuery({
        'targetId': targetId,
        'targetType': targetType,
        'source': source,
        'language': language,
      }),
    );
  }

  Future<JsonMap> transcript(String id) => client.getJson('$_path/$id');

  Future<JsonMap> uploadTranscript(JsonMap transcript) =>
      client.postJson(_path, body: {'transcript': transcript});
}
